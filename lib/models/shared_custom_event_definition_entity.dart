import 'package:objectbox/objectbox.dart';

/// A family-owned custom event type.
///
/// The ObjectBox ID is local only. [customEventTypeId] is the stable identity
/// used by records and by a future family sync transport.
@Entity()
class SharedCustomEventDefinitionEntity {
  @Id()
  int id;

  @Index()
  String customEventTypeId;

  @Index()
  String familySpaceId;

  String name;
  int revision;
  String createdByAuthorProfileId;
  String createdByDeviceProfileId;
  String lastModifiedByAuthorProfileId;
  String lastModifiedByDeviceProfileId;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  @Property(type: PropertyType.date)
  DateTime? archivedAt;

  SharedCustomEventDefinitionEntity({
    this.id = 0,
    required this.customEventTypeId,
    required this.familySpaceId,
    required this.name,
    this.revision = 1,
    required this.createdByAuthorProfileId,
    required this.createdByDeviceProfileId,
    required this.lastModifiedByAuthorProfileId,
    required this.lastModifiedByDeviceProfileId,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;
}

/// Device-local presentation state. It must never be included in family sync.
@Entity()
class CustomEventPinEntity {
  @Id()
  int id;

  @Index()
  String customEventTypeId;

  @Index()
  String deviceProfileId;

  int position;

  CustomEventPinEntity({
    this.id = 0,
    required this.customEventTypeId,
    required this.deviceProfileId,
    required this.position,
  });
}
