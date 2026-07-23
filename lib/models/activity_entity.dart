import 'package:objectbox/objectbox.dart';
import 'diary_entity.dart';

@Entity()
class ActivityEntity {
  static const int timePrecisionUnknown = 0;
  static const int timePrecisionExact = 1;

  @Id()
  int id;

  String type; // 활동 타입 (수유, 수면, 투약 등)

  @Property(type: PropertyType.date)
  DateTime time; // 발생 시각. timePrecision이 unknown이면 기준 시각으로만 사용한다.

  /// 기존 데이터와 AI 집계처럼 정확한 발생 시각을 알 수 없는 경우 0,
  /// 사용자가 지정했거나 백업에서 명시된 시각은 1이다.
  int timePrecision;

  String details; // 상세정보(용량, 시간 등)

  @Property(type: PropertyType.date)
  DateTime lastModified;

  @Property(type: PropertyType.date)
  DateTime? createdAt;

  String? createdByAuthorProfileId;
  String? createdByDeviceProfileId;
  String? lastModifiedByAuthorProfileId;
  String? lastModifiedByDeviceProfileId;

  final diary = ToOne<DiaryEntity>();

  ActivityEntity({
    this.id = 0,
    required this.type,
    required this.time,
    this.timePrecision = timePrecisionExact,
    required this.details,
    required this.lastModified,
    this.createdAt,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.lastModifiedByAuthorProfileId,
    this.lastModifiedByDeviceProfileId,
  });

  bool get hasExactTime => timePrecision == timePrecisionExact;
}
