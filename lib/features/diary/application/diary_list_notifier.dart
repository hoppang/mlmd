import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/activity_entity.dart';
import '../../../models/diary_entity.dart';
import '../../../repositories/diary_repository.dart';
import '../../../services/embedding_service.dart';
import '../../../services/llm_diary_service.dart'
    show ActivitySummary, buildEmbeddingText;

class DiaryListNotifier extends Notifier<List<DiaryEntity>> {
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
    final embeddingText = buildEmbeddingText(summary, activityEntities);
    newDiary.embedding = await embeddingService.getEmbedding(embeddingText);

    repo.saveDiaryWithActivities(
      newDiary,
      activityEntities,
      consumedDraftId: consumedDraftId,
    );
    state = repo.getDiaries();
  }

  Future<List<SimilarDiaryResult>> searchSimilar(
    String query, {
    int limit = 5,
  }) {
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    return repo.searchSimilar(query, embeddingService, limit: limit);
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
    final embeddingText = buildEmbeddingText(newSummary, activityEntities);
    updatedDiary.embedding = await embeddingService.getEmbedding(embeddingText);

    repo.saveDiaryWithActivities(
      updatedDiary,
      activityEntities,
      consumedDraftId: consumedDraftId,
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
    var failed = 0;
    for (final diary in repo.getDiaries()) {
      final recordId = diary.recordId;
      if (recordId == null || !ids.contains(recordId)) continue;
      try {
        final text = buildEmbeddingText(diary.summary, diary.activities);
        final embedding = await embeddingService.getEmbedding(text);
        repo.updateEmbeddingPreservingLastModified(recordId, embedding);
        if (embedding == null) failed++;
      } catch (_) {
        failed++;
      }
    }
    state = repo.getDiaries();
    return failed;
  }
}

final diaryListProvider =
    NotifierProvider<DiaryListNotifier, List<DiaryEntity>>(
      DiaryListNotifier.new,
    );
