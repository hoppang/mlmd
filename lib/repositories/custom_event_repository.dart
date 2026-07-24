import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/objectbox_helper.dart';
import '../models/shared_custom_event_definition_entity.dart';
import '../objectbox.g.dart';
import 'profile_repository.dart';

abstract interface class CustomEventRepository {
  String get familySpaceId;

  List<SharedCustomEventDefinitionEntity> getDefinitions({
    bool includeArchived = false,
  });

  List<String> getPinnedTypeIds();

  SharedCustomEventDefinitionEntity create(String name);

  SharedCustomEventDefinitionEntity rename(
    String customEventTypeId,
    String name,
  );

  SharedCustomEventDefinitionEntity setArchived(
    String customEventTypeId, {
    required bool archived,
  });

  void setPinned(String customEventTypeId, {required bool pinned});

  /// Applies a definition received through a family transport.
  ///
  /// UUIDs, not names, determine identity. An older or identical revision
  /// cannot overwrite a newer local definition.
  SharedCustomEventDefinitionEntity applySharedDefinition(
    SharedCustomEventDefinitionEntity incoming,
  );
}

class CustomEventRepositoryImpl implements CustomEventRepository {
  CustomEventRepositoryImpl(
    ObjectBoxHelper objectBox,
    this._profiles, {
    String? familySpaceId,
  }) : _store = objectBox.store,
       _definitionBox = Box<SharedCustomEventDefinitionEntity>(objectBox.store),
       _pinBox = Box<CustomEventPinEntity>(objectBox.store),
       _familySpaceId =
           familySpaceId ?? 'local:${_profiles.currentDevice.deviceProfileId}';

  static const _uuid = Uuid();
  final Store _store;
  final ProfileRepository _profiles;
  final Box<SharedCustomEventDefinitionEntity> _definitionBox;
  final Box<CustomEventPinEntity> _pinBox;
  final String _familySpaceId;

  @override
  String get familySpaceId => _familySpaceId;

  @override
  List<SharedCustomEventDefinitionEntity> getDefinitions({
    bool includeArchived = false,
  }) {
    final result = _definitionBox
        .getAll()
        .where(
          (definition) =>
              definition.familySpaceId == familySpaceId &&
              (includeArchived || !definition.isArchived),
        )
        .toList();
    result.sort((left, right) {
      final archived = left.isArchived == right.isArchived
          ? 0
          : (left.isArchived ? 1 : -1);
      if (archived != 0) return archived;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return result;
  }

  @override
  List<String> getPinnedTypeIds() {
    final deviceId = _profiles.currentDevice.deviceProfileId;
    final activeIds = getDefinitions()
        .map((definition) => definition.customEventTypeId)
        .toSet();
    final pins =
        _pinBox
            .getAll()
            .where(
              (pin) =>
                  pin.deviceProfileId == deviceId &&
                  activeIds.contains(pin.customEventTypeId),
            )
            .toList()
          ..sort((left, right) => left.position.compareTo(right.position));
    return pins.map((pin) => pin.customEventTypeId).toList(growable: false);
  }

  @override
  SharedCustomEventDefinitionEntity create(String name) {
    final normalized = _normalizeName(name);
    final source = _profiles.requireCurrentSource();
    final now = DateTime.now();
    final definition = SharedCustomEventDefinitionEntity(
      customEventTypeId: _uuid.v4(),
      familySpaceId: familySpaceId,
      name: normalized,
      createdByAuthorProfileId: source.authorProfileId,
      createdByDeviceProfileId: source.deviceProfileId,
      lastModifiedByAuthorProfileId: source.authorProfileId,
      lastModifiedByDeviceProfileId: source.deviceProfileId,
      createdAt: now,
      updatedAt: now,
    );
    _definitionBox.put(definition);
    return definition;
  }

  @override
  SharedCustomEventDefinitionEntity rename(
    String customEventTypeId,
    String name,
  ) {
    final definition = _requireDefinition(customEventTypeId);
    final normalized = _normalizeName(name);
    if (definition.name == normalized) return definition;
    final source = _profiles.requireCurrentSource();
    definition
      ..name = normalized
      ..revision = definition.revision + 1
      ..lastModifiedByAuthorProfileId = source.authorProfileId
      ..lastModifiedByDeviceProfileId = source.deviceProfileId
      ..updatedAt = DateTime.now();
    _definitionBox.put(definition);
    return definition;
  }

  @override
  SharedCustomEventDefinitionEntity setArchived(
    String customEventTypeId, {
    required bool archived,
  }) {
    final definition = _requireDefinition(customEventTypeId);
    if (definition.isArchived == archived) return definition;
    final source = _profiles.requireCurrentSource();
    final now = DateTime.now();
    definition
      ..archivedAt = archived ? now : null
      ..revision = definition.revision + 1
      ..lastModifiedByAuthorProfileId = source.authorProfileId
      ..lastModifiedByDeviceProfileId = source.deviceProfileId
      ..updatedAt = now;
    _definitionBox.put(definition);
    if (archived) setPinned(customEventTypeId, pinned: false);
    return definition;
  }

  @override
  void setPinned(String customEventTypeId, {required bool pinned}) {
    final definition = _requireDefinition(customEventTypeId);
    if (definition.isArchived && pinned) {
      throw StateError('Archived custom events cannot be pinned.');
    }
    final deviceId = _profiles.currentDevice.deviceProfileId;
    final existing = _pinsForDevice(deviceId);
    CustomEventPinEntity? current;
    for (final pin in existing) {
      if (pin.customEventTypeId == customEventTypeId) {
        current = pin;
        break;
      }
    }
    if (pinned) {
      if (current != null) return;
      _pinBox.put(
        CustomEventPinEntity(
          customEventTypeId: customEventTypeId,
          deviceProfileId: deviceId,
          position: existing.length,
        ),
      );
      return;
    }
    if (current == null) return;
    _store.runInTransaction(TxMode.write, () {
      _pinBox.remove(current!.id);
      final remaining = _pinsForDevice(deviceId);
      for (var index = 0; index < remaining.length; index++) {
        if (remaining[index].position == index) continue;
        remaining[index].position = index;
        _pinBox.put(remaining[index]);
      }
    });
  }

  @override
  SharedCustomEventDefinitionEntity applySharedDefinition(
    SharedCustomEventDefinitionEntity incoming,
  ) {
    if (incoming.familySpaceId != familySpaceId) {
      throw StateError('The custom event belongs to another family space.');
    }
    final existing = _findDefinition(incoming.customEventTypeId);
    if (existing != null &&
        (existing.revision > incoming.revision ||
            (existing.revision == incoming.revision &&
                !incoming.updatedAt.isAfter(existing.updatedAt)))) {
      return existing;
    }
    final saved = SharedCustomEventDefinitionEntity(
      id: existing?.id ?? 0,
      customEventTypeId: incoming.customEventTypeId,
      familySpaceId: incoming.familySpaceId,
      name: _normalizeName(incoming.name),
      revision: incoming.revision < 1 ? 1 : incoming.revision,
      createdByAuthorProfileId: incoming.createdByAuthorProfileId,
      createdByDeviceProfileId: incoming.createdByDeviceProfileId,
      lastModifiedByAuthorProfileId: incoming.lastModifiedByAuthorProfileId,
      lastModifiedByDeviceProfileId: incoming.lastModifiedByDeviceProfileId,
      createdAt: incoming.createdAt,
      updatedAt: incoming.updatedAt,
      archivedAt: incoming.archivedAt,
    );
    _definitionBox.put(saved);
    if (saved.isArchived) {
      setPinned(saved.customEventTypeId, pinned: false);
    }
    return saved;
  }

  List<CustomEventPinEntity> _pinsForDevice(String deviceId) {
    final result = _pinBox
        .getAll()
        .where((pin) => pin.deviceProfileId == deviceId)
        .toList();
    result.sort((left, right) => left.position.compareTo(right.position));
    return result;
  }

  SharedCustomEventDefinitionEntity? _findDefinition(String typeId) {
    final query = _definitionBox
        .query(
          SharedCustomEventDefinitionEntity_.customEventTypeId.equals(typeId),
        )
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  SharedCustomEventDefinitionEntity _requireDefinition(String typeId) {
    final result = _findDefinition(typeId);
    if (result == null || result.familySpaceId != familySpaceId) {
      throw StateError('Custom event definition does not exist.');
    }
    return result;
  }

  String _normalizeName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty || normalized.length > 40) {
      throw ArgumentError.value(
        value,
        'name',
        'Custom event names must contain 1 to 40 characters.',
      );
    }
    return normalized;
  }
}

final customEventRepositoryProvider = Provider<CustomEventRepository>((ref) {
  return CustomEventRepositoryImpl(
    ref.watch(objectBoxProvider),
    ref.watch(profileRepositoryProvider),
  );
}, dependencies: [objectBoxProvider, profileRepositoryProvider]);
