import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/activity_entity.dart';
import '../../../models/diary_entity.dart';
import '../../../repositories/diary_repository.dart';
import '../../../services/embedding_service.dart';
import '../../../services/llm_diary_service.dart' show ActivitySummary;
import '../../search/domain/hybrid_search_query.dart';

class DiaryListNotifier extends Notifier<List<DiaryEntity>> {
  bool get isSemanticSearchAvailable =>
      ref.read(embeddingServiceProvider).isAvailable;

  bool get hasPendingSearchEmbeddings =>
      ref.read(diaryRepositoryProvider).hasPendingSearchEmbeddings;

  @override
  List<DiaryEntity> build() {
    final repo = ref.watch(diaryRepositoryProvider);
    return repo.getDiaries();
  }

  Future<void> addDiary(
    String title,
    String summary,
    String content, {
    required DateTime occurredAt,
    List<ActivitySummary> activitySummaries = const [],
    String? consumedDraftId,
  }) async {
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    final now = DateTime.now();
    final newDiary = DiaryEntity(
      date: occurredAt,
      title: title,
      summary: summary,
      content: content,
      lastModified: now,
    );
    final activityEntities = activitySummaries
        .map(
          (activity) => ActivityEntity(
            type: activity.type,
            time: activity.occurredAt ?? occurredAt,
            timePrecision: activity.occurredAt == null
                ? ActivityEntity.timePrecisionUnknown
                : ActivityEntity.timePrecisionExact,
            details: activity.detail,
            lastModified: now,
          ),
        )
        .toList();
    repo.saveDiaryWithActivities(
      newDiary,
      activityEntities,
      consumedDraftId: consumedDraftId,
    );
    await repo.rebuildSearchIndex(
      embeddingService,
      recordIds: {newDiary.recordId!},
    );
    state = repo.getDiaries();
  }

  Future<void> addActivityRecord({
    required String type,
    required String details,
    required DateTime occurredAt,
  }) async {
    final repo = ref.read(diaryRepositoryProvider);
    repo.addActivityRecord(
      ActivityEntity(
        type: type,
        time: occurredAt,
        details: details,
        lastModified: DateTime.now(),
      ),
    );
    await repo.rebuildSearchIndex(ref.read(embeddingServiceProvider));
    state = repo.getDiaries();
  }

  Future<List<DiarySearchResult>> searchRecords(
    HybridSearchQuery query, {
    int limit = 50,
  }) {
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    return repo.searchRecords(query, embeddingService, limit: limit);
  }

  Future<void> updateDiary(
    DiaryEntity diary,
    String newTitle,
    String newSummary,
    String newContent, {
    required DateTime occurredAt,
    List<ActivitySummary> activitySummaries = const [],
    String? consumedDraftId,
  }) async {
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    final now = DateTime.now();
    final updatedDiary = DiaryEntity(
      id: diary.id,
      recordId: diary.recordId,
      date: occurredAt,
      title: newTitle,
      summary: newSummary,
      content: newContent,
      lastModified: diary.lastModified,
    );
    final activityEntities = activitySummaries
        .map(
          (activity) => ActivityEntity(
            type: activity.type,
            time: activity.occurredAt ?? occurredAt,
            timePrecision: activity.occurredAt == null
                ? ActivityEntity.timePrecisionUnknown
                : ActivityEntity.timePrecisionExact,
            details: activity.detail,
            lastModified: now,
          ),
        )
        .toList();
    repo.saveDiaryWithActivities(
      updatedDiary,
      activityEntities,
      consumedDraftId: consumedDraftId,
    );
    await repo.rebuildSearchIndex(
      embeddingService,
      recordIds: {updatedDiary.recordId!},
    );
    state = repo.getDiaries();
  }

  void deleteDiary(int id) {
    final repo = ref.read(diaryRepositoryProvider);
    repo.deleteDiary(id);
    state = repo.getDiaries();
  }

  void reload() {
    state = ref.read(diaryRepositoryProvider).getDiaries();
  }

  Future<int> regenerateEmbeddings(Iterable<String> recordIds) async {
    final ids = recordIds.toSet();
    if (ids.isEmpty) return 0;
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    final failed = await repo.rebuildSearchIndex(
      embeddingService,
      recordIds: ids,
    );
    state = repo.getDiaries();
    return failed;
  }
}

final diaryListProvider =
    NotifierProvider<DiaryListNotifier, List<DiaryEntity>>(
      DiaryListNotifier.new,
      dependencies: [diaryRepositoryProvider, embeddingServiceProvider],
    );
