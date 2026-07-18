import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_entity.dart';
import '../models/diary_entity.dart';
import '../data/objectbox_helper.dart';
import '../objectbox.g.dart';
import '../services/embedding_service.dart';
import '../services/llm_diary_service.dart'
    show buildEmbeddingText, ActivitySummary;

/// 유사 검색 결과 모델
class SimilarDiaryResult {
  final DiaryEntity diary;

  /// 유사도 (0.0 ~ 100.0 %)
  final double similarityPercent;

  const SimilarDiaryResult({
    required this.diary,
    required this.similarityPercent,
  });
}

/// 일기 CRUD 처리를 위한 Repository 인터페이스
abstract class DiaryRepository {
  /// 모든 일기 목록을 반환합니다.
  List<DiaryEntity> getDiaries();

  /// 지정한 ID에 해당하는 일기를 조회합니다.
  DiaryEntity? getDiary(int id);

  /// 일기를 저장(생성 또는 수정)합니다.
  /// 저장 시 `lastModified` 타임스탬프가 자동으로 현재 시간으로 갱신됩니다.
  int saveDiary(DiaryEntity diary);

  /// 일기와 그 활동 목록을 하나의 트랜잭션에서 저장합니다.
  /// 기존 활동 엔티티는 실제 삭제한 뒤 [activities]로 교체합니다.
  int saveDiaryWithActivities(
    DiaryEntity diary,
    List<ActivityEntity> activities,
  );

  /// 지정한 ID의 일기를 삭제합니다.
  bool deleteDiary(int id);

  /// 쿼리 텍스트와 의미적으로 유사한 일기를 HNSW 벡터 검색으로 조회합니다.
  /// [embeddingService]로 쿼리를 임베딩한 뒤 가장 가까운 [limit]개를 반환합니다.
  /// 반환값은 유사도(%) 내림차순으로 정렬됩니다.
  Future<List<SimilarDiaryResult>> searchSimilar(
    String query,
    EmbeddingService embeddingService, {
    int limit = 5,
  });
}

/// DiaryRepository의 ObjectBox 구현체
class DiaryRepositoryImpl implements DiaryRepository {
  final ObjectBoxHelper _obxHelper;

  DiaryRepositoryImpl(this._obxHelper);

  @override
  List<DiaryEntity> getDiaries() {
    final query = _obxHelper.diaryBox
        .query()
        .order(DiaryEntity_.date, flags: Order.descending)
        .build();
    final diaries = query.find();
    query.close();
    return diaries;
  }

  @override
  DiaryEntity? getDiary(int id) {
    return _obxHelper.diaryBox.get(id);
  }

  @override
  int saveDiary(DiaryEntity diary) {
    // 트리거: 생성 및 수정 시 자동으로 lastModified 갱신
    diary.lastModified = DateTime.now();
    return _obxHelper.diaryBox.put(diary);
  }

  @override
  int saveDiaryWithActivities(
    DiaryEntity diary,
    List<ActivityEntity> activities,
  ) {
    return _obxHelper.store.runInTransaction(TxMode.write, () {
      final now = DateTime.now();
      diary.lastModified = now;
      final diaryId = _obxHelper.diaryBox.put(diary);

      final oldQuery = _obxHelper.activityBox
          .query(ActivityEntity_.diary.equals(diaryId))
          .build();
      final oldIds = oldQuery.findIds();
      oldQuery.close();
      if (oldIds.isNotEmpty) {
        _obxHelper.activityBox.removeMany(oldIds);
      }

      for (final activity in activities) {
        activity.diary.target = diary;
        activity.lastModified = now;
      }
      if (activities.isNotEmpty) {
        _obxHelper.activityBox.putMany(activities);
      }
      return diaryId;
    });
  }

  @override
  bool deleteDiary(int id) {
    return _obxHelper.store.runInTransaction(TxMode.write, () {
      final activityQuery = _obxHelper.activityBox
          .query(ActivityEntity_.diary.equals(id))
          .build();
      final activityIds = activityQuery.findIds();
      activityQuery.close();
      if (activityIds.isNotEmpty) {
        _obxHelper.activityBox.removeMany(activityIds);
      }
      return _obxHelper.diaryBox.remove(id);
    });
  }

  @override
  Future<List<SimilarDiaryResult>> searchSimilar(
    String query,
    EmbeddingService embeddingService, {
    int limit = 5,
  }) async {
    if (query.trim().isEmpty || limit <= 0) return [];

    final queryVector = await embeddingService.getQueryEmbedding(query);
    final exactQuery = _obxHelper.diaryBox
        .query(
          DiaryEntity_.title.contains(query, caseSensitive: false) |
              DiaryEntity_.summary.contains(query, caseSensitive: false) |
              DiaryEntity_.content.contains(query, caseSensitive: false),
        )
        .build();
    exactQuery.limit = limit;

    final vectorQuery = queryVector == null || queryVector.isEmpty
        ? null
        : _obxHelper.diaryBox
              .query(
                DiaryEntity_.embedding.nearestNeighborsF32(queryVector, limit),
              )
              .build();

    try {
      final results = <int, SimilarDiaryResult>{};
      final exactMatches = await exactQuery.findAsync();
      for (final diary in exactMatches) {
        results[diary.id] = SimilarDiaryResult(
          diary: diary,
          similarityPercent: 100,
        );
      }

      final withScores = vectorQuery == null
          ? const <ObjectWithScore<DiaryEntity>>[]
          : await vectorQuery.findWithScoresAsync();
      for (final item in withScores) {
        final distance = item.score;
        final cosSim = 1.0 - (distance / 2.0);
        final mapped = (cosSim - 0.82) / (1.0 - 0.82) * 100.0;
        final candidate = SimilarDiaryResult(
          diary: item.object,
          similarityPercent: mapped.clamp(0.0, 100.0),
        );
        if (candidate.similarityPercent > 0 &&
            !results.containsKey(candidate.diary.id)) {
          results[candidate.diary.id] = candidate;
        }
      }

      final sorted = results.values.toList()
        ..sort((a, b) => b.similarityPercent.compareTo(a.similarityPercent));
      return sorted.take(limit).toList(growable: false);
    } finally {
      exactQuery.close();
      vectorQuery?.close();
    }
  }
}

/// Riverpod에서 제공할 DiaryRepository 프로바이더
final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final obxHelper = ref.watch(objectBoxProvider);
  return DiaryRepositoryImpl(obxHelper);
});

/// 일기 목록의 상태와 변경을 관리하는 Riverpod Notifier
class DiaryListNotifier extends Notifier<List<DiaryEntity>> {
  @override
  List<DiaryEntity> build() {
    final repo = ref.watch(diaryRepositoryProvider);
    return repo.getDiaries();
  }

  /// 새 일기를 추가합니다.
  /// [summary]와 비일상 [activities]를 합산하여 임베딩 텍스트를 구성합니다.
  Future<void> addDiary(
    String title,
    String summary,
    String content, {
    List<ActivitySummary> activitySummaries = const [],
  }) async {
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    final now = DateTime.now();

    final newDiary = DiaryEntity(
      date: now,
      title: title,
      summary: summary,
      content: content,
      lastModified: now,
    );

    // ActivityEntity 생성. 관계 연결은 repository 트랜잭션에서 수행합니다.
    final activityEntities = activitySummaries
        .map(
          (a) => ActivityEntity(
            type: a.type,
            time: now,
            details: a.detail,
            lastModified: now,
          ),
        )
        .toList();
    // 임베딩 텍스트 = summary + 비일상 이벤트
    final embeddingText = buildEmbeddingText(summary, activityEntities);
    newDiary.embedding = await embeddingService.getEmbedding(embeddingText);

    repo.saveDiaryWithActivities(newDiary, activityEntities);
    state = repo.getDiaries();
  }

  /// 현재 텍스트 쿼리와 유사한 일기를 검색합니다.
  Future<List<SimilarDiaryResult>> searchSimilar(
    String query, {
    int limit = 5,
  }) {
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    return repo.searchSimilar(query, embeddingService, limit: limit);
  }

  /// 기존 일기를 수정합니다.
  Future<void> updateDiary(
    DiaryEntity diary,
    String newTitle,
    String newSummary,
    String newContent, {
    List<ActivitySummary> activitySummaries = const [],
  }) async {
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    final now = DateTime.now();

    diary.title = newTitle;
    diary.summary = newSummary;
    diary.content = newContent;

    // 기존 activities 교체
    final activityEntities = activitySummaries
        .map(
          (a) => ActivityEntity(
            type: a.type,
            time: now,
            details: a.detail,
            lastModified: now,
          ),
        )
        .toList();
    // 임베딩 텍스트 = summary + 비일상 이벤트
    final embeddingText = buildEmbeddingText(newSummary, activityEntities);
    diary.embedding = await embeddingService.getEmbedding(embeddingText);

    repo.saveDiaryWithActivities(diary, activityEntities);
    state = repo.getDiaries();
  }

  void deleteDiary(int id) {
    final repo = ref.read(diaryRepositoryProvider);
    repo.deleteDiary(id);
    state = repo.getDiaries();
  }
}

final diaryListProvider =
    NotifierProvider<DiaryListNotifier, List<DiaryEntity>>(
      DiaryListNotifier.new,
    );
