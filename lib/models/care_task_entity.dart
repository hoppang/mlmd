import 'package:objectbox/objectbox.dart';

@Entity()
class CareTaskEntity {
  @Id()
  int id;

  @Index()
  String taskId;

  String childId;
  String title;
  String? recurrenceRule;
  String? assignedToAuthorProfileId;
  String notificationMode;
  String? linkedCategory;
  String? linkedEventTemplateJson;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime? archivedAt;

  String createdByAuthorProfileId;
  String createdByDeviceProfileId;

  CareTaskEntity({
    this.id = 0,
    required this.taskId,
    this.childId = '',
    required this.title,
    this.recurrenceRule,
    this.assignedToAuthorProfileId,
    this.notificationMode = 'inAppOnly',
    this.linkedCategory,
    this.linkedEventTemplateJson,
    required this.createdAt,
    this.archivedAt,
    required this.createdByAuthorProfileId,
    required this.createdByDeviceProfileId,
  });
}
