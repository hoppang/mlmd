import 'dart:convert';

enum SyncOperation {
  create,
  update,
  delete;

  static SyncOperation parse(String value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => throw FormatException('Unknown sync operation: $value'),
  );
}

class SyncChange {
  const SyncChange({
    required this.changeId,
    required this.familySpaceId,
    required this.sourceDeviceProfileId,
    required this.sourceAuthorProfileId,
    required this.entityType,
    required this.entityId,
    required this.entityRevision,
    required this.operation,
    required this.payload,
    required this.occurredAt,
    this.serverReceivedAt,
    this.serverSequence,
    this.resolutionMetadata,
  });

  final String changeId;
  final String familySpaceId;
  final String sourceDeviceProfileId;
  final String sourceAuthorProfileId;
  final String entityType;
  final String entityId;
  final int entityRevision;
  final SyncOperation operation;
  final Map<String, Object?> payload;
  final DateTime occurredAt;
  final DateTime? serverReceivedAt;
  final int? serverSequence;
  final SyncResolutionMetadata? resolutionMetadata;

  String get payloadJson => jsonEncode(payload);

  Map<String, Object?> toJson() => {
    'changeId': changeId,
    'familySpaceId': familySpaceId,
    'sourceDeviceProfileId': sourceDeviceProfileId,
    'sourceAuthorProfileId': sourceAuthorProfileId,
    'entityType': entityType,
    'entityId': entityId,
    'entityRevision': entityRevision,
    'operation': operation.name,
    'payload': payload,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    if (serverReceivedAt != null)
      'serverReceivedAt': serverReceivedAt!.toUtc().toIso8601String(),
    if (resolutionMetadata != null) 'resolution': resolutionMetadata!.toJson(),
  };

  factory SyncChange.fromJson(Map<String, Object?> json) {
    final payload = json['payload'];
    if (payload is! Map) {
      throw const FormatException('Sync payload must be an object.');
    }
    return SyncChange(
      changeId: json['changeId']! as String,
      familySpaceId: json['familySpaceId']! as String,
      sourceDeviceProfileId: json['sourceDeviceProfileId']! as String,
      sourceAuthorProfileId: json['sourceAuthorProfileId']! as String,
      entityType: json['entityType']! as String,
      entityId: json['entityId']! as String,
      entityRevision: json['entityRevision']! as int,
      operation: SyncOperation.parse(json['operation']! as String),
      payload: payload.cast<String, Object?>(),
      occurredAt: DateTime.parse(json['occurredAt']! as String),
      serverReceivedAt: json['serverReceivedAt'] == null
          ? null
          : DateTime.parse(json['serverReceivedAt']! as String),
      serverSequence: json['serverSequence'] as int?,
      resolutionMetadata: json['resolution'] == null
          ? null
          : SyncResolutionMetadata.fromJson(
              (json['resolution']! as Map).cast<String, Object?>(),
            ),
    );
  }
}

class SyncResolutionMetadata {
  const SyncResolutionMetadata({
    required this.sourceConflictId,
    required this.parentChangeIds,
    required this.selectedResolution,
  });

  static const version = 1;

  final String sourceConflictId;
  final List<String> parentChangeIds;
  final SyncConflictResolution selectedResolution;

  String get resolutionGroupId {
    if (parentChangeIds.isEmpty) {
      throw StateError('A sync resolution requires parent change IDs.');
    }
    final sorted = parentChangeIds.toSet().toList()..sort();
    return sorted.join('\u0000');
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'sourceConflictId': sourceConflictId,
    'parentChangeIds': parentChangeIds,
    'selectedResolution': selectedResolution.name,
  };

  factory SyncResolutionMetadata.fromJson(Map<String, Object?> json) {
    final parents = json['parentChangeIds'];
    if (json['version'] != version ||
        json['sourceConflictId'] is! String ||
        parents is! List ||
        parents.isEmpty ||
        parents.any((value) => value is! String || value.isEmpty)) {
      throw const FormatException('Invalid sync resolution metadata.');
    }
    final selected = json['selectedResolution'];
    return SyncResolutionMetadata(
      sourceConflictId: json['sourceConflictId']! as String,
      parentChangeIds: List<String>.unmodifiable(parents.cast<String>()),
      selectedResolution: SyncConflictResolution.values.firstWhere(
        (value) => value.name == selected,
        orElse: () =>
            throw const FormatException('Invalid sync resolution selection.'),
      ),
    );
  }
}

class SyncExchange {
  const SyncExchange({
    required this.acknowledgedChangeIds,
    required this.incomingChanges,
    this.nextCursor,
  });

  final Set<String> acknowledgedChangeIds;
  final List<SyncChange> incomingChanges;
  final String? nextCursor;
}

class FamilySyncSnapshot {
  const FamilySyncSnapshot({
    this.familySpaceId,
    this.familyDisplayName,
    this.pendingChangeCount = 0,
    this.unresolvedConflictCount = 0,
    this.lastSuccessfulAt,
    this.lastErrorCode,
  });

  final String? familySpaceId;
  final String? familyDisplayName;
  final int pendingChangeCount;
  final int unresolvedConflictCount;
  final DateTime? lastSuccessfulAt;
  final String? lastErrorCode;

  bool get isConnected => familySpaceId != null;
}

enum SyncConflictResolution { keepLocal, useIncoming }

class FamilySyncConflict {
  const FamilySyncConflict({
    required this.conflictId,
    required this.familySpaceId,
    required this.entityType,
    required this.entityId,
    required this.localRevision,
    required this.incomingRevision,
    required this.localPayload,
    required this.incomingPayload,
    required this.incomingChangeId,
    required this.incomingOperation,
    required this.detectedAt,
    this.incomingSourceDeviceProfileId,
    this.incomingSourceAuthorProfileId,
    this.incomingOccurredAt,
    this.resolution,
    this.resolvedAt,
    this.resolvedByAuthorProfileId,
    this.resolvedByDeviceProfileId,
  });

  final String conflictId;
  final String familySpaceId;
  final String entityType;
  final String entityId;
  final int localRevision;
  final int incomingRevision;
  final Map<String, Object?> localPayload;
  final Map<String, Object?> incomingPayload;
  final String incomingChangeId;
  final SyncOperation incomingOperation;
  final DateTime detectedAt;
  final String? incomingSourceDeviceProfileId;
  final String? incomingSourceAuthorProfileId;
  final DateTime? incomingOccurredAt;
  final SyncConflictResolution? resolution;
  final DateTime? resolvedAt;
  final String? resolvedByAuthorProfileId;
  final String? resolvedByDeviceProfileId;

  bool get isResolved => resolvedAt != null;
}

class ConflictResolutionResult {
  const ConflictResolutionResult({
    required this.conflict,
    required this.queuedChangeId,
  });

  final FamilySyncConflict conflict;
  final String queuedChangeId;
}

class FamilySyncResolutionNotice {
  const FamilySyncResolutionNotice({
    required this.noticeId,
    required this.familySpaceId,
    required this.entityType,
    required this.entityId,
    required this.firstChangeId,
    required this.secondChangeId,
    required this.winningChangeId,
    required this.firstPayload,
    required this.secondPayload,
    required this.firstSourceDeviceProfileId,
    required this.firstSourceAuthorProfileId,
    required this.secondSourceDeviceProfileId,
    required this.secondSourceAuthorProfileId,
    required this.firstOccurredAt,
    required this.secondOccurredAt,
    required this.detectedAt,
    this.acknowledgedAt,
  });

  final String noticeId;
  final String familySpaceId;
  final String entityType;
  final String entityId;
  final String firstChangeId;
  final String secondChangeId;
  final String winningChangeId;
  final Map<String, Object?> firstPayload;
  final Map<String, Object?> secondPayload;
  final String firstSourceDeviceProfileId;
  final String firstSourceAuthorProfileId;
  final String secondSourceDeviceProfileId;
  final String secondSourceAuthorProfileId;
  final DateTime firstOccurredAt;
  final DateTime secondOccurredAt;
  final DateTime detectedAt;
  final DateTime? acknowledgedAt;

  bool get isAcknowledged => acknowledgedAt != null;
}

enum RemoteApplyDisposition { applied, ignored, conflict }

class RemoteApplyResult {
  const RemoteApplyResult._({
    required this.disposition,
    this.localRevision,
    this.localPayload,
  });

  const RemoteApplyResult.applied()
    : this._(disposition: RemoteApplyDisposition.applied);

  const RemoteApplyResult.ignored()
    : this._(disposition: RemoteApplyDisposition.ignored);

  const RemoteApplyResult.conflict({
    required int localRevision,
    required Map<String, Object?> localPayload,
  }) : this._(
         disposition: RemoteApplyDisposition.conflict,
         localRevision: localRevision,
         localPayload: localPayload,
       );

  final RemoteApplyDisposition disposition;
  final int? localRevision;
  final Map<String, Object?>? localPayload;
}

class SyncRunResult {
  const SyncRunResult({
    required this.uploadedCount,
    required this.appliedCount,
    required this.conflictCount,
    this.resolutionCollisionCount = 0,
  });

  final int uploadedCount;
  final int appliedCount;
  final int conflictCount;
  final int resolutionCollisionCount;
}
