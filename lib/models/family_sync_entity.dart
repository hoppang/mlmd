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
    required this.occurredAt,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.lastErrorCode,
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
  String incomingChangeId;

  @Property(type: PropertyType.date)
  DateTime detectedAt;

  @Property(type: PropertyType.date)
  DateTime? resolvedAt;

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
    required this.incomingChangeId,
    required this.detectedAt,
    this.resolvedAt,
  });
}
