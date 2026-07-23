import 'package:objectbox/objectbox.dart';

/// 원본 메모·이벤트에서 다시 만들 수 있는 로컬 파생 AI 정리입니다.
@Entity()
class AiSummaryEntity {
  static const periodDaily = 'daily';
  static const periodWeekly = 'weekly';
  static const currentAlgorithmVersion = 'summary-input-v1';

  @Id()
  int id;

  @Index()
  String summaryId;

  String periodType;

  @Property(type: PropertyType.date)
  DateTime periodStart;

  @Property(type: PropertyType.date)
  DateTime periodEndExclusive;

  String generatedText;
  String? editedText;

  @Property(type: PropertyType.date)
  DateTime generatedAt;

  @Property(type: PropertyType.date)
  DateTime cutoffAt;

  String sourceFingerprint;

  /// 근거 링크와 생성 당시 원문 스냅샷의 JSON 배열입니다.
  String evidenceJson;

  bool hidden;
  bool userEdited;
  bool automatic;
  String modelVersion;
  String algorithmVersion;

  AiSummaryEntity({
    this.id = 0,
    required this.summaryId,
    required this.periodType,
    required this.periodStart,
    required this.periodEndExclusive,
    required this.generatedText,
    this.editedText,
    required this.generatedAt,
    required this.cutoffAt,
    required this.sourceFingerprint,
    required this.evidenceJson,
    this.hidden = false,
    this.userEdited = false,
    this.automatic = false,
    required this.modelVersion,
    this.algorithmVersion = currentAlgorithmVersion,
  });

  String get displayText =>
      userEdited && editedText != null ? editedText! : generatedText;
}
