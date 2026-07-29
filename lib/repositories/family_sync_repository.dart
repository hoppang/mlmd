import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/objectbox_helper.dart';
import '../features/sharing/application/family_sync_payloads.dart';
import '../features/sharing/application/family_sync_transport.dart';
import '../features/sharing/domain/family_sync_models.dart';
import '../models/family_sync_entity.dart';
import '../objectbox.g.dart' hide SyncChange;
import 'profile_repository.dart';

typedef RemoteChangeApplier =
    FutureOr<RemoteApplyResult> Function(SyncChange change);

abstract interface class FamilySyncRepository {
  String? get activeFamilySpaceId;

  FamilySyncSnapshot getSnapshot();

  void connect({required String familySpaceId, required String displayName});

  void disconnect();

  SyncChange? enqueue({
    required String entityType,
    required String entityId,
    required int entityRevision,
    required SyncOperation operation,
    required Map<String, Object?> payload,
    DateTime? occurredAt,
  });

  Future<SyncRunResult> synchronize(
    FamilySyncTransport transport, {
    required RemoteChangeApplier applyRemoteChange,
  });
}

class FamilySyncRepositoryImpl implements FamilySyncRepository {
  FamilySyncRepositoryImpl(this._objectBox, this._profiles)
    : _spaceBox = Box<FamilySpaceEntity>(_objectBox.store),
      _outbox = Box<SyncOutboxEntity>(_objectBox.store),
      _cursorBox = Box<SyncCursorEntity>(_objectBox.store),
      _conflictBox = Box<SyncConflictEntity>(_objectBox.store) {
    if (_profiles case final ProfileRepositoryImpl profiles) {
      _profileMutationSubscription = profiles.mutations.listen(
        _queueProfileMutation,
      );
    }
  }

  static const _uuid = Uuid();
  final ObjectBoxHelper _objectBox;
  final ProfileRepository _profiles;
  final Box<FamilySpaceEntity> _spaceBox;
  final Box<SyncOutboxEntity> _outbox;
  final Box<SyncCursorEntity> _cursorBox;
  final Box<SyncConflictEntity> _conflictBox;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  StreamSubscription<AuthorProfileMutation>? _profileMutationSubscription;

  Stream<void> get changes => _changes.stream;

  FamilySpaceEntity? get _activeSpace {
    final spaces = _spaceBox.getAll().where((item) => item.isActive).toList()
      ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    return spaces.isEmpty ? null : spaces.first;
  }

  @override
  String? get activeFamilySpaceId => _activeSpace?.familySpaceId;

  @override
  FamilySyncSnapshot getSnapshot() {
    final space = _activeSpace;
    if (space == null) return const FamilySyncSnapshot();
    final pending = _pending(space.familySpaceId);
    final conflicts = _conflictBox
        .getAll()
        .where(
          (item) =>
              item.familySpaceId == space.familySpaceId &&
              item.resolvedAt == null,
        )
        .length;
    final cursor = _cursor(space.familySpaceId);
    return FamilySyncSnapshot(
      familySpaceId: space.familySpaceId,
      familyDisplayName: space.displayName,
      pendingChangeCount: pending.length,
      unresolvedConflictCount: conflicts,
      lastSuccessfulAt: cursor?.lastSuccessfulAt,
      lastErrorCode:
          cursor?.lastErrorCode ??
          pending
              .map((item) => item.lastErrorCode)
              .whereType<String>()
              .firstOrNull,
    );
  }

  @override
  void connect({required String familySpaceId, required String displayName}) {
    final normalizedId = familySpaceId.trim();
    final normalizedName = displayName.trim();
    if (normalizedId.isEmpty || normalizedName.isEmpty) {
      throw ArgumentError('Family space ID and display name are required.');
    }
    final device = _profiles.currentDevice;
    _objectBox.store.runInTransaction(TxMode.write, () {
      for (final space in _spaceBox.getAll()) {
        final shouldBeActive = space.familySpaceId == normalizedId;
        if (space.isActive != shouldBeActive) {
          space.isActive = shouldBeActive;
          _spaceBox.put(space);
        }
      }
      final existing = _spaceById(normalizedId);
      if (existing == null) {
        _spaceBox.put(
          FamilySpaceEntity(
            familySpaceId: normalizedId,
            displayName: normalizedName,
            deviceProfileId: device.deviceProfileId,
            joinedAt: DateTime.now(),
          ),
        );
      } else {
        existing
          ..displayName = normalizedName
          ..deviceProfileId = device.deviceProfileId
          ..isActive = true;
        _spaceBox.put(existing);
      }
      _ensureCursor(normalizedId);
    });
    _profiles.markSharedHistory();
    final author = _profiles.currentAuthor;
    if (author != null) {
      enqueue(
        entityType: 'authorProfile',
        entityId: author.authorProfileId,
        entityRevision: 1,
        operation: SyncOperation.create,
        payload: {
          'authorProfileId': author.authorProfileId,
          'nickname': author.nickname,
          'colorValue': author.colorValue,
          'createdAt': author.createdAt.toUtc().toIso8601String(),
        },
      );
    }
    _notifyChanged();
  }

  @override
  void disconnect() {
    final active = _activeSpace;
    if (active == null) return;
    active.isActive = false;
    _spaceBox.put(active);
    _notifyChanged();
  }

  @override
  SyncChange? enqueue({
    required String entityType,
    required String entityId,
    required int entityRevision,
    required SyncOperation operation,
    required Map<String, Object?> payload,
    DateTime? occurredAt,
  }) {
    final familySpaceId = activeFamilySpaceId;
    if (familySpaceId == null) return null;
    if (entityType.trim().isEmpty ||
        entityId.trim().isEmpty ||
        entityRevision < 1) {
      throw ArgumentError('A valid entity identity and revision are required.');
    }
    final source = _profiles.requireCurrentSource();
    final change = SyncChange(
      changeId: _uuid.v4(),
      familySpaceId: familySpaceId,
      sourceDeviceProfileId: source.deviceProfileId,
      sourceAuthorProfileId: source.authorProfileId,
      entityType: entityType,
      entityId: entityId,
      entityRevision: entityRevision,
      operation: operation,
      payload: Map.unmodifiable(payload),
      occurredAt: occurredAt ?? DateTime.now(),
    );
    _outbox.put(_toOutbox(change));
    _notifyChanged();
    return change;
  }

  @override
  Future<SyncRunResult> synchronize(
    FamilySyncTransport transport, {
    required RemoteChangeApplier applyRemoteChange,
  }) async {
    final space = _activeSpace;
    if (space == null) {
      throw StateError('A family space must be connected before syncing.');
    }
    final cursor = _ensureCursor(space.familySpaceId);
    final pending = _pending(space.familySpaceId);
    late final SyncExchange exchange;
    try {
      exchange = await transport.exchange(
        familySpaceId: space.familySpaceId,
        deviceProfileId: _profiles.currentDevice.deviceProfileId,
        afterCursor: cursor.lastAppliedChangeId,
        outgoingChanges: pending.map(_fromOutbox).toList(growable: false),
      );
    } on FamilySyncUnavailable catch (error) {
      _recordFailure(cursor, pending, error.code);
      rethrow;
    } catch (_) {
      _recordFailure(cursor, pending, 'transport_error');
      rethrow;
    }

    final acknowledged = pending
        .where((item) => exchange.acknowledgedChangeIds.contains(item.changeId))
        .toList();
    if (acknowledged.isNotEmpty) {
      _outbox.removeMany(acknowledged.map((item) => item.id).toList());
    }

    var appliedCount = 0;
    var conflictCount = 0;
    for (final incoming in exchange.incomingChanges) {
      if (incoming.familySpaceId != space.familySpaceId) continue;
      final localPending = _pendingForEntity(
        space.familySpaceId,
        incoming.entityType,
        incoming.entityId,
      );
      if (localPending != null &&
          (localPending.entityRevision != incoming.entityRevision ||
              localPending.payloadJson != incoming.payloadJson)) {
        _saveConflict(
          incoming,
          localRevision: localPending.entityRevision,
          localPayloadJson: localPending.payloadJson,
        );
        conflictCount++;
        continue;
      }
      final result = await applyRemoteChange(incoming);
      switch (result.disposition) {
        case RemoteApplyDisposition.applied:
          appliedCount++;
        case RemoteApplyDisposition.ignored:
          break;
        case RemoteApplyDisposition.conflict:
          _saveConflict(
            incoming,
            localRevision: result.localRevision!,
            localPayloadJson: jsonEncode(result.localPayload),
          );
          conflictCount++;
      }
    }

    cursor
      ..lastAppliedChangeId = exchange.nextCursor ?? cursor.lastAppliedChangeId
      ..lastSuccessfulAt = DateTime.now()
      ..lastErrorCode = null;
    _cursorBox.put(cursor);
    _notifyChanged();
    return SyncRunResult(
      uploadedCount: acknowledged.length,
      appliedCount: appliedCount,
      conflictCount: conflictCount,
    );
  }

  void _recordFailure(
    SyncCursorEntity cursor,
    List<SyncOutboxEntity> pending,
    String code,
  ) {
    final now = DateTime.now();
    for (final item in pending) {
      item
        ..attemptCount = item.attemptCount + 1
        ..lastAttemptAt = now
        ..lastErrorCode = code;
    }
    if (pending.isNotEmpty) _outbox.putMany(pending);
    cursor.lastErrorCode = code;
    _cursorBox.put(cursor);
    _notifyChanged();
  }

  void _saveConflict(
    SyncChange incoming, {
    required int localRevision,
    required String localPayloadJson,
  }) {
    final existing = _conflictById(incoming.changeId);
    if (existing != null) return;
    _conflictBox.put(
      SyncConflictEntity(
        conflictId: incoming.changeId,
        familySpaceId: incoming.familySpaceId,
        entityType: incoming.entityType,
        entityId: incoming.entityId,
        localRevision: localRevision,
        incomingRevision: incoming.entityRevision,
        localPayloadJson: localPayloadJson,
        incomingPayloadJson: incoming.payloadJson,
        incomingChangeId: incoming.changeId,
        detectedAt: DateTime.now(),
      ),
    );
    _notifyChanged();
  }

  FamilySpaceEntity? _spaceById(String familySpaceId) {
    final query = _spaceBox
        .query(FamilySpaceEntity_.familySpaceId.equals(familySpaceId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  SyncCursorEntity? _cursor(String familySpaceId) {
    final key = _cursorKey(familySpaceId);
    final query = _cursorBox
        .query(SyncCursorEntity_.cursorKey.equals(key))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  SyncCursorEntity _ensureCursor(String familySpaceId) {
    final existing = _cursor(familySpaceId);
    if (existing != null) return existing;
    final cursor = SyncCursorEntity(
      cursorKey: _cursorKey(familySpaceId),
      familySpaceId: familySpaceId,
      deviceProfileId: _profiles.currentDevice.deviceProfileId,
    );
    _cursorBox.put(cursor);
    return cursor;
  }

  String _cursorKey(String familySpaceId) =>
      '$familySpaceId:${_profiles.currentDevice.deviceProfileId}';

  List<SyncOutboxEntity> _pending(String familySpaceId) {
    final result =
        _outbox
            .getAll()
            .where((item) => item.familySpaceId == familySpaceId)
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return result;
  }

  SyncOutboxEntity? _pendingForEntity(
    String familySpaceId,
    String entityType,
    String entityId,
  ) {
    for (final item in _pending(familySpaceId).reversed) {
      if (item.entityType == entityType && item.entityId == entityId) {
        return item;
      }
    }
    return null;
  }

  SyncConflictEntity? _conflictById(String conflictId) {
    final query = _conflictBox
        .query(SyncConflictEntity_.conflictId.equals(conflictId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  SyncOutboxEntity _toOutbox(SyncChange change) => SyncOutboxEntity(
    changeId: change.changeId,
    familySpaceId: change.familySpaceId,
    sourceDeviceProfileId: change.sourceDeviceProfileId,
    sourceAuthorProfileId: change.sourceAuthorProfileId,
    entityType: change.entityType,
    entityId: change.entityId,
    entityRevision: change.entityRevision,
    operation: change.operation.name,
    payloadJson: change.payloadJson,
    occurredAt: change.occurredAt,
  );

  SyncChange _fromOutbox(SyncOutboxEntity entity) => SyncChange(
    changeId: entity.changeId,
    familySpaceId: entity.familySpaceId,
    sourceDeviceProfileId: entity.sourceDeviceProfileId,
    sourceAuthorProfileId: entity.sourceAuthorProfileId,
    entityType: entity.entityType,
    entityId: entity.entityId,
    entityRevision: entity.entityRevision,
    operation: SyncOperation.parse(entity.operation),
    payload: (jsonDecode(entity.payloadJson) as Map).cast<String, Object?>(),
    occurredAt: entity.occurredAt,
  );

  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _queueProfileMutation(AuthorProfileMutation mutation) {
    final now = DateTime.now();
    enqueue(
      entityType: FamilySyncPayloads.authorProfile,
      entityId: mutation.profile.authorProfileId,
      entityRevision: FamilySyncPayloads.revisionAt(now),
      operation: mutation.isCreate
          ? SyncOperation.create
          : SyncOperation.update,
      payload: {
        ...FamilySyncPayloads.forAuthor(mutation.profile),
        'updatedAt': now.toUtc().toIso8601String(),
      },
      occurredAt: now,
    );
  }

  void dispose() {
    unawaited(_profileMutationSubscription?.cancel());
    _changes.close();
  }
}

final familySyncRepositoryProvider = Provider<FamilySyncRepository>((ref) {
  final repository = FamilySyncRepositoryImpl(
    ref.watch(objectBoxProvider),
    ref.watch(profileRepositoryProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
}, dependencies: [objectBoxProvider, profileRepositoryProvider]);

class FamilySyncStatusNotifier extends Notifier<FamilySyncSnapshot> {
  @override
  FamilySyncSnapshot build() {
    final repository = ref.watch(familySyncRepositoryProvider);
    if (repository is FamilySyncRepositoryImpl) {
      final subscription = repository.changes.listen((_) {
        state = repository.getSnapshot();
      });
      ref.onDispose(subscription.cancel);
    }
    return repository.getSnapshot();
  }

  void reload() {
    state = ref.read(familySyncRepositoryProvider).getSnapshot();
  }
}

final familySyncStatusProvider =
    NotifierProvider<FamilySyncStatusNotifier, FamilySyncSnapshot>(
      FamilySyncStatusNotifier.new,
      dependencies: [familySyncRepositoryProvider],
    );
