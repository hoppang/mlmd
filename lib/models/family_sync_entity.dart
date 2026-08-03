import 'package:objectbox/objectbox.dart';

/// A local membership in a family space.
///
/// Authentication credentials and provider-specific identifiers deliberately do
/// not live here. They belong to the transport adapter and secure storage.
@Entity()
class FamilySpaceEntity {
  @Id()
  int id;

  @Unique()
  String familySpaceId;

  String displayName;
  String deviceProfileId;
  bool isActive;

  @Property(type: PropertyType.date)
  DateTime joinedAt;

  FamilySpaceEntity({
    this.id = 0,
    required this.familySpaceId,
    required this.displayName,
    required this.deviceProfileId,
    this.isActive = true,
    required this.joinedAt,
  });
}

/// A locally committed change waiting to be delivered to the family transport.
@Entity()
class SyncOutboxEntity {
  @Id()
  int id;

  @Unique()
  String changeId;

  @Index()
  String familySpaceId;

  String sourceDeviceProfileId;
  String sourceAuthorProfileId;
  String entityType;

  @Index()
  String entityId;

  int entityRevision;
  String operation;
  String payloadJson;
  String? resolutionMetadataJson;

  @Property(type: PropertyType.date)
  DateTime occurredAt;

  int attemptCount;

  @Property(type: PropertyType.date)
  DateTime? lastAttemptAt;

  String? lastErrorCode;

  SyncOutboxEntity({
    this.id = 0,
    required this.changeId,
    required this.familySpaceId,
    required this.sourceDeviceProfileId,
    required this.sourceAuthorProfileId,
    required this.entityType,
    required this.entityId,
    required this.entityRevision,
    required this.operation,
    required this.payloadJson,
    this.resolutionMetadataJson,
    required this.occurredAt,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.lastErrorCode,
  });
}

/// The deterministic winner among concurrent conflict-resolution changes.
@Entity()
class SyncResolutionStateEntity {
  @Id()
  int id;

  @Unique()
  String stateKey;

  @Index()
  String familySpaceId;

  String entityType;

  @Index()
  String entityId;

  String resolutionGroupId;
  String winningChangeId;
  int? winningServerSequence;
  int effectiveRevision;
  String operation;
  String payloadJson;
  String sourceDeviceProfileId;
  String sourceAuthorProfileId;

  @Property(type: PropertyType.date)
  DateTime occurredAt;

  SyncResolutionStateEntity({
    this.id = 0,
    required this.stateKey,
    required this.familySpaceId,
    required this.entityType,
    required this.entityId,
    required this.resolutionGroupId,
    required this.winningChangeId,
    this.winningServerSequence,
    required this.effectiveRevision,
    required this.operation,
    required this.payloadJson,
    required this.sourceDeviceProfileId,
    required this.sourceAuthorProfileId,
    required this.occurredAt,
  });
}

/// A per-device notice that two users resolved the same entity concurrently.
@Entity()
class SyncResolutionNoticeEntity {
  @Id()
  int id;

  @Unique()
  String noticeId;

  @Index()
  String familySpaceId;

  String entityType;

  @Index()
  String entityId;

  String firstChangeId;
  String secondChangeId;
  String winningChangeId;
  String firstPayloadJson;
  String secondPayloadJson;
  String firstSourceDeviceProfileId;
  String firstSourceAuthorProfileId;
  String secondSourceDeviceProfileId;
  String secondSourceAuthorProfileId;

  @Property(type: PropertyType.date)
  DateTime firstOccurredAt;

  @Property(type: PropertyType.date)
  DateTime secondOccurredAt;

  @Property(type: PropertyType.date)
  DateTime detectedAt;

  @Property(type: PropertyType.date)
  DateTime? acknowledgedAt;

  SyncResolutionNoticeEntity({
    this.id = 0,
    required this.noticeId,
    required this.familySpaceId,
    required this.entityType,
    required this.entityId,
    required this.firstChangeId,
    required this.secondChangeId,
    required this.winningChangeId,
    required this.firstPayloadJson,
    required this.secondPayloadJson,
    required this.firstSourceDeviceProfileId,
    required this.firstSourceAuthorProfileId,
    required this.secondSourceDeviceProfileId,
    required this.secondSourceAuthorProfileId,
    required this.firstOccurredAt,
    required this.secondOccurredAt,
    required this.detectedAt,
    this.acknowledgedAt,
  });
}

/// A monotonic per-author acknowledgement of one resolution notice winner.
@Entity()
class SyncResolutionAcknowledgementEntity {
  @Id()
  int id;

  @Unique()
  String acknowledgementId;

  @Index()
  String familySpaceId;

  @Index()
  String noticeId;

  String winningChangeId;

  @Index()
  String authorProfileId;

  String sourceDeviceProfileId;
  String sourceChangeId;

  @Property(type: PropertyType.date)
  DateTime acknowledgedAt;

  SyncResolutionAcknowledgementEntity({
    this.id = 0,
    required this.acknowledgementId,
    required this.familySpaceId,
    required this.noticeId,
    required this.winningChangeId,
    required this.authorProfileId,
    required this.sourceDeviceProfileId,
    required this.sourceChangeId,
    required this.acknowledgedAt,
  });
}

/// The latest server change cursor applied by this device.
@Entity()
class SyncCursorEntity {
  @Id()
  int id;

  @Unique()
  String cursorKey;

  @Index()
  String familySpaceId;

  String deviceProfileId;
  String? lastAppliedChangeId;

  @Property(type: PropertyType.date)
  DateTime? lastSuccessfulAt;

  String? lastErrorCode;

  SyncCursorEntity({
    this.id = 0,
    required this.cursorKey,
    required this.familySpaceId,
    required this.deviceProfileId,
    this.lastAppliedChangeId,
    this.lastSuccessfulAt,
    this.lastErrorCode,
  });
}

/// Preserves both versions when a same-entity edit cannot be merged safely.
@Entity()
class SyncConflictEntity {
  @Id()
  int id;

  @Unique()
  String conflictId;

  @Index()
  String familySpaceId;

  String entityType;

  @Index()
  String entityId;

  int localRevision;
  int incomingRevision;
  String localPayloadJson;
  String incomingPayloadJson;
  String? localChangeId;
  String incomingChangeId;
  String? incomingOperation;
  String? incomingSourceDeviceProfileId;
  String? incomingSourceAuthorProfileId;

  @Property(type: PropertyType.date)
  DateTime? incomingOccurredAt;

  @Property(type: PropertyType.date)
  DateTime detectedAt;

  @Property(type: PropertyType.date)
  DateTime? resolvedAt;

  String? resolution;
  String? resolutionChangeId;
  String? resolvedByAuthorProfileId;
  String? resolvedByDeviceProfileId;

  SyncConflictEntity({
    this.id = 0,
    required this.conflictId,
    required this.familySpaceId,
    required this.entityType,
    required this.entityId,
    required this.localRevision,
    required this.incomingRevision,
    required this.localPayloadJson,
    required this.incomingPayloadJson,
    this.localChangeId,
    required this.incomingChangeId,
    this.incomingOperation,
    this.incomingSourceDeviceProfileId,
    this.incomingSourceAuthorProfileId,
    this.incomingOccurredAt,
    required this.detectedAt,
    this.resolvedAt,
    this.resolution,
    this.resolutionChangeId,
    this.resolvedByAuthorProfileId,
    this.resolvedByDeviceProfileId,
  });
}
