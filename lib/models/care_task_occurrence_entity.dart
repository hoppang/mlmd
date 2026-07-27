import 'package:objectbox/objectbox.dart';

@Entity()
class CareTaskOccurrenceEntity {
  @Id()
  int id;

  @Index()
  String occurrenceId;

  @Index()
  String taskId;

  @Property(type: PropertyType.date)
  DateTime scheduledAt;

  String status;

  @Property(type: PropertyType.date)
  DateTime? completedAt;

  String? completedByAuthorProfileId;
  String? completedOnDeviceProfileId;

  @Index()
  String? linkedRecordId;

  CareTaskOccurrenceEntity({
    this.id = 0,
    required this.occurrenceId,
    required this.taskId,
    required this.scheduledAt,
    this.status = 'scheduled',
    this.completedAt,
    this.completedByAuthorProfileId,
    this.completedOnDeviceProfileId,
    this.linkedRecordId,
  });
}
