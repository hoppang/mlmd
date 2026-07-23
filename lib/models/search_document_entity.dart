import 'package:objectbox/objectbox.dart';

@Entity()
class SearchDocumentEntity {
  static const sourceTypeMemo = 'memo';
  static const sourceTypeEvent = 'event';
  static const currentEmbeddingModelVersion = 'bge-384-v1';

  @Id()
  int id;

  @Index()
  String searchDocumentId;

  @Index()
  String sourceRecordId;

  String sourceType;

  /// 메모는 DiaryEntity.id, 이벤트는 ActivityEntity.id를 가리킨다.
  int sourceEntityId;

  /// 이벤트가 속한 DiaryEntity.id. 메모는 sourceEntityId와 같다.
  int sourceDiaryId;

  String searchableText;

  @HnswIndex(dimensions: 384)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  String embeddingModelVersion;
  String sourceContentHash;

  @Property(type: PropertyType.date)
  DateTime indexedAt;

  @Property(type: PropertyType.date)
  DateTime occurredAt;

  String? authorProfileId;

  /// HybridSearchQuery의 SearchEventKind index + 1이며 메모는 0이다.
  int eventKind;

  /// 현재 구조화 모델에서 안전하게 해석할 수 있는 체온(°C)만 저장한다.
  double? numericValue;

  SearchDocumentEntity({
    this.id = 0,
    required this.searchDocumentId,
    required this.sourceRecordId,
    required this.sourceType,
    required this.sourceEntityId,
    required this.sourceDiaryId,
    required this.searchableText,
    this.embedding,
    this.embeddingModelVersion = '',
    required this.sourceContentHash,
    required this.indexedAt,
    required this.occurredAt,
    this.authorProfileId,
    this.eventKind = 0,
    this.numericValue,
  });
}
