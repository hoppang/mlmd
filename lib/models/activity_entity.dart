import 'package:objectbox/objectbox.dart';
import 'diary_entity.dart';

@Entity()
class ActivityEntity {
  static const int timePrecisionUnknown = 0;
  static const int timePrecisionExact = 1;

  @Id()
  int id;

  /// ObjectBox 로컬 ID와 별개로 편집·기기 이동 뒤에도 같은 활동을 가리키는 UUID입니다.
  @Index()
  String? recordId;

  /// 중복 판정의 핵심값이 바뀔 때 증가합니다.
  int revision;

  String type; // 활동 타입 (수유, 수면, 투약 등)

  @Property(type: PropertyType.date)
  DateTime time; // 발생 시각. timePrecision이 unknown이면 기준 시각으로만 사용한다.

  /// 기존 데이터와 AI 집계처럼 정확한 발생 시각을 알 수 없는 경우 0,
  /// 사용자가 지정했거나 백업에서 명시된 시각은 1이다.
  int timePrecision;

  String details; // 상세정보(용량, 시간 등)

  /// 이벤트별 구조화 입력을 원문 정밀도 그대로 보존하는 버전 JSON입니다.
  ///
  /// 기존 기록과 구조화 폼이 없는 이벤트는 null입니다. 화면 표시와 검색용
  /// [details]를 대체하지 않으므로 이전 앱과도 읽을 수 있습니다.
  String? structuredDataJson;

  /// 커스텀 이벤트 기록일 때 공유 정의의 안정 UUID를 가리킨다.
  @Index()
  String? customEventTypeId;

  /// 정의의 이름이 나중에 변경·보관되어도 과거 기록을 보존하는 스냅샷이다.
  String? customEventNameSnapshot;

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
    this.recordId,
    this.revision = 1,
    required this.type,
    required this.time,
    this.timePrecision = timePrecisionExact,
    required this.details,
    this.structuredDataJson,
    this.customEventTypeId,
    this.customEventNameSnapshot,
    required this.lastModified,
    this.createdAt,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.lastModifiedByAuthorProfileId,
    this.lastModifiedByDeviceProfileId,
  });

  bool get hasExactTime => timePrecision == timePrecisionExact;
}
