import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/activity_entity.dart';
import '../../../models/diary_entity.dart';
import '../../../repositories/diary_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../../services/embedding_service.dart';
import '../../../services/llm_diary_service.dart' show ActivitySummary;
import '../../events/domain/event_catalog.dart';
import '../../events/domain/sleep_record.dart';
import '../../search/domain/hybrid_search_query.dart';

class SleepStartResult {
  const SleepStartResult({required this.activity, required this.created});

  final ActivityEntity activity;
  final bool created;
}

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
            recordId: activity.recordId,
            revision: activity.revision,
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
    String? structuredDataJson,
  }) async {
    final repo = ref.read(diaryRepositoryProvider);
    repo.addActivityRecord(
      ActivityEntity(
        type: type,
        time: occurredAt,
        details: details,
        structuredDataJson: structuredDataJson,
        lastModified: DateTime.now(),
      ),
    );
    await repo.rebuildSearchIndex(ref.read(embeddingServiceProvider));
    state = repo.getDiaries();
  }

  Future<void> addCustomEventRecord({
    required String customEventTypeId,
    required String nameSnapshot,
    required String memo,
    required DateTime occurredAt,
  }) async {
    final repo = ref.read(diaryRepositoryProvider);
    repo.addActivityRecord(
      ActivityEntity(
        type: nameSnapshot,
        time: occurredAt,
        details: memo,
        customEventTypeId: customEventTypeId,
        customEventNameSnapshot: nameSnapshot,
        lastModified: DateTime.now(),
      ),
    );
    await repo.rebuildSearchIndex(ref.read(embeddingServiceProvider));
    state = repo.getDiaries();
  }

  Future<SleepStartResult> startSleep({
    required String type,
    DateTime? startedAt,
  }) async {
    final existing = activeSleepActivities(state);
    if (existing.isNotEmpty) {
      return SleepStartResult(activity: existing.first, created: false);
    }
    final start = startedAt ?? DateTime.now();
    final activity = ActivityEntity(
      type: type,
      time: start,
      details: '',
      structuredDataJson: SleepRecord(
        status: SleepRecordStatus.active,
        kind: SleepRecordKind.unspecified,
        source: SleepRecordSource.suggested,
        startedAt: start,
      ).encode(),
      lastModified: start,
    );
    final repo = ref.read(diaryRepositoryProvider);
    repo.addActivityRecord(activity);
    await repo.rebuildSearchIndex(ref.read(embeddingServiceProvider));
    state = repo.getDiaries();
    final saved = _activityByRecordId(activity.recordId) ?? activity;
    return SleepStartResult(activity: saved, created: true);
  }

  Future<void> completeSleep(
    ActivityEntity activity, {
    DateTime? endedAt,
    required String details,
  }) async {
    final current = SleepRecord.decode(activity.structuredDataJson ?? '');
    if (current == null || current.status != SleepRecordStatus.active) return;
    final end = endedAt ?? DateTime.now();
    if (!end.isAfter(current.startedAt)) {
      throw ArgumentError.value(end, 'endedAt');
    }
    final source = ref.read(profileRepositoryProvider).requireCurrentSource();
    final completed = SleepRecord(
      status: SleepRecordStatus.completed,
      kind: suggestSleepKind(current.startedAt, end),
      source: SleepRecordSource.suggested,
      startedAt: current.startedAt,
      endedAt: end,
      markers: current.markers,
      endedByAuthorProfileId: source.authorProfileId,
      endedByDeviceProfileId: source.deviceProfileId,
      note: current.note,
    );
    await _updateSleepActivity(
      activity,
      record: completed,
      occurredAt: end,
      details: details,
    );
  }

  Future<void> reopenSleep(String recordId) async {
    final activity = _activityByRecordId(recordId);
    if (activity == null) return;
    final current = SleepRecord.decode(activity.structuredDataJson ?? '');
    if (current == null || current.status != SleepRecordStatus.completed) {
      return;
    }
    final active = SleepRecord(
      status: SleepRecordStatus.active,
      kind: SleepRecordKind.unspecified,
      source: SleepRecordSource.suggested,
      startedAt: current.startedAt,
      markers: current.markers,
      note: current.note,
    );
    await _updateSleepActivity(
      activity,
      record: active,
      occurredAt: current.startedAt,
      details: '',
    );
  }

  Future<void> editActiveSleepStart(String recordId, DateTime startedAt) async {
    final activity = _activityByRecordId(recordId);
    if (activity == null) return;
    final current = SleepRecord.decode(activity.structuredDataJson ?? '');
    if (current == null || current.status != SleepRecordStatus.active) return;
    final updated = SleepRecord(
      status: SleepRecordStatus.active,
      kind: SleepRecordKind.unspecified,
      source: SleepRecordSource.suggested,
      startedAt: startedAt,
      markers: current.markers,
      note: current.note,
    );
    await _updateSleepActivity(
      activity,
      record: updated,
      occurredAt: startedAt,
      details: '',
    );
  }

  Future<void> updateSleepMarkers(
    String recordId,
    List<SleepRecordMarker> markers, {
    required String details,
  }) async {
    final activity = _activityByRecordId(recordId);
    if (activity == null) return;
    final current = SleepRecord.decode(activity.structuredDataJson ?? '');
    if (current == null || current.status != SleepRecordStatus.completed) {
      return;
    }
    final updated = SleepRecord(
      status: current.status,
      kind: current.kind,
      source: current.source,
      startedAt: current.startedAt,
      endedAt: current.endedAt,
      markers: markers,
      endedByAuthorProfileId: current.endedByAuthorProfileId,
      endedByDeviceProfileId: current.endedByDeviceProfileId,
      note: current.note,
    );
    await _updateSleepActivity(
      activity,
      record: updated,
      occurredAt: current.endedAt!,
      details: details,
    );
  }

  Future<void> deleteActivityRecord(String recordId) async {
    final activity = _activityByRecordId(recordId);
    if (activity == null) return;
    final repo = ref.read(diaryRepositoryProvider);
    repo.deleteActivityRecord(activity.id);
    await repo.rebuildSearchIndex(ref.read(embeddingServiceProvider));
    state = repo.getDiaries();
  }

  Future<void> _updateSleepActivity(
    ActivityEntity activity, {
    required SleepRecord record,
    required DateTime occurredAt,
    required String details,
  }) async {
    final updated = _copyActivity(activity)
      ..time = occurredAt
      ..details = details
      ..structuredDataJson = record.encode();
    final repo = ref.read(diaryRepositoryProvider);
    repo.updateActivityRecord(updated);
    await repo.rebuildSearchIndex(ref.read(embeddingServiceProvider));
    state = repo.getDiaries();
  }

  ActivityEntity? _activityByRecordId(String? recordId) {
    if (recordId == null) return null;
    for (final diary in state) {
      for (final activity in diary.activities) {
        if (activity.recordId == recordId) return activity;
      }
    }
    return null;
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
            recordId: activity.recordId,
            revision: activity.revision,
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

List<ActivityEntity> activeSleepActivities(Iterable<DiaryEntity> diaries) {
  final sleepItem = eventCatalogItem(EventTypeId.sleep);
  final result = <ActivityEntity>[];
  for (final diary in diaries) {
    for (final activity in diary.activities) {
      if (!sleepItem.matches(activity.type)) continue;
      final record = SleepRecord.decode(activity.structuredDataJson ?? '');
      if (record?.status == SleepRecordStatus.active) result.add(activity);
    }
  }
  result.sort((a, b) => a.time.compareTo(b.time));
  return result;
}

SleepRecordKind suggestSleepKind(DateTime startedAt, DateTime endedAt) {
  final midpoint = startedAt.add(endedAt.difference(startedAt) ~/ 2);
  return midpoint.hour >= 18 || midpoint.hour < 6
      ? SleepRecordKind.night
      : SleepRecordKind.nap;
}

ActivityEntity _copyActivity(ActivityEntity activity) => ActivityEntity(
  id: activity.id,
  recordId: activity.recordId,
  revision: activity.revision,
  type: activity.type,
  time: activity.time,
  timePrecision: activity.timePrecision,
  details: activity.details,
  structuredDataJson: activity.structuredDataJson,
  customEventTypeId: activity.customEventTypeId,
  customEventNameSnapshot: activity.customEventNameSnapshot,
  lastModified: activity.lastModified,
  createdAt: activity.createdAt,
  createdByAuthorProfileId: activity.createdByAuthorProfileId,
  createdByDeviceProfileId: activity.createdByDeviceProfileId,
  lastModifiedByAuthorProfileId: activity.lastModifiedByAuthorProfileId,
  lastModifiedByDeviceProfileId: activity.lastModifiedByDeviceProfileId,
);

final diaryListProvider =
    NotifierProvider<DiaryListNotifier, List<DiaryEntity>>(
      DiaryListNotifier.new,
      dependencies: [diaryRepositoryProvider, embeddingServiceProvider],
    );
