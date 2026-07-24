import 'package:objectbox/objectbox.dart';

@Entity()
class RecordDraftEntity {
  @Id()
  int id;

  @Index()
  String draftId;

  String draftKind;
  String recordType;

  @Index()
  String? targetRecordId;

  int payloadSchemaVersion;
  String fieldPayloadJson;

  @Property(type: PropertyType.date)
  DateTime? baseLastModified;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime lastSavedAt;

  RecordDraftEntity({
    this.id = 0,
    required this.draftId,
    required this.draftKind,
    required this.recordType,
    this.targetRecordId,
    this.payloadSchemaVersion = 1,
    required this.fieldPayloadJson,
    this.baseLastModified,
    required this.createdAt,
    required this.lastSavedAt,
  });
}
