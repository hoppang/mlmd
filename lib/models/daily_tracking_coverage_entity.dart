import 'package:objectbox/objectbox.dart';

@Entity()
class DailyTrackingCoverageEntity {
  @Id()
  int id;

  @Index()
  String childId;

  /// yyyy-MM-dd 형식의 기기 현지 날짜.
  @Index()
  String localDate;

  @Index()
  String eventCategory;

  /// TrackingCoverage.name.
  String coverage;

  /// TrackingRelativeState.name.
  String relativeState;

  String? memo;

  @Property(type: PropertyType.date)
  DateTime lastModified;

  DailyTrackingCoverageEntity({
    this.id = 0,
    required this.childId,
    required this.localDate,
    required this.eventCategory,
    required this.coverage,
    required this.relativeState,
    this.memo,
    required this.lastModified,
  });
}
