import 'package:objectbox/objectbox.dart';
import 'activity_entity.dart';

@Entity()
class DiaryEntity {
  @Id()
  int id;

  /// ObjectBox의 로컬 ID와 별개로, 백업 파일과 설치 간에 유지되는 식별자입니다.
  ///
  /// 기존 데이터베이스와의 안전한 마이그레이션을 위해 nullable로 시작하며
  /// [DiaryRepository]가 최초 접근 시 비어 있는 값을 UUID v4로 채웁니다.
  @Index()
  String? recordId;

  @Property(type: PropertyType.date)
  DateTime date;

  String title;

  /// LLM이 추출한 하루 요약 (1~3문장).
  /// 목록 카드 및 상세 화면에 표시됩니다.
  String summary;

  /// 원문 보관용: 간단 입력 모드에서 사용자가 입력한 자유 텍스트.
  String content;

  @Property(type: PropertyType.date)
  DateTime lastModified;

  @HnswIndex(dimensions: 384)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  /// ActivityEntity.diary를 관계의 단일 원본으로 사용하는 역방향 관계입니다.
  @Backlink('diary')
  final activities = ToMany<ActivityEntity>();

  DiaryEntity({
    this.id = 0,
    this.recordId,
    required this.date,
    required this.title,
    this.summary = '',
    required this.content,
    required this.lastModified,
    this.embedding,
  });
}
