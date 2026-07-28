import 'package:objectbox/objectbox.dart';

@Entity()
class TrackingPreferenceEntity {
  @Id()
  int id;

  @Index()
  String childId;

  @Index()
  String eventCategory;

  /// TrackingMode.name. 변경 이력을 행 단위로 보존한다.
  String mode;

  @Property(type: PropertyType.date)
  DateTime changedAt;

  TrackingPreferenceEntity({
    this.id = 0,
    required this.childId,
    required this.eventCategory,
    required this.mode,
    required this.changedAt,
  });
}
