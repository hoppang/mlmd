import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_entity.dart';
import '../models/diary_entity.dart';
import '../data/objectbox_helper.dart';
import '../objectbox.g.dart';
import '../services/embedding_service.dart';
import '../transfer/canonical_transfer_document.dart';
import 'package:uuid/uuid.dart';

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
    List<ActivityEntity> activities, {
    String? consumedDraftId,
  });

  /// 현재 저장소를 버전 독립적인 내보내기 모델로 스냅샷합니다.
  CanonicalExportDocument createExportDocument({required String appVersion});

  /// DB를 변경하지 않고 충돌 정책별 반영 건수를 계산합니다.
  ImportPreview previewImport(
    CanonicalImportDocument document,
    ImportConflictPolicy policy,
  );

  /// 검증을 마친 문서를 하나의 쓰기 트랜잭션에서 반영합니다.
  ImportResult importDocument(
    CanonicalImportDocument document,
    ImportConflictPolicy policy,
  );

  /// 가져온 레코드의 임베딩만 갱신하며 원래 수정 시각은 보존합니다.
  void updateEmbeddingPreservingLastModified(
    String recordId,
    List<double>? embedding,
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
  static const _uuid = Uuid();
  static final _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  DiaryRepositoryImpl(this._obxHelper) {
    _backfillRecordIds();
  }

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

  /// 저장소 생성 시 기존 레코드의 비어 있거나 중복된 전송 식별자를 한 번 보정합니다.
  void _backfillRecordIds() {
    _obxHelper.store.runInTransaction(TxMode.write, () {
      final diaries = _obxHelper.diaryBox.getAll();
      final used = <String>{};
      final changed = <DiaryEntity>[];
      for (final diary in diaries) {
        var value = diary.recordId?.trim().toLowerCase();
        if (value == null || value.isEmpty || !used.add(value)) {
          do {
            value = _uuid.v4();
          } while (!used.add(value));
          diary.recordId = value;
          changed.add(diary);
        } else if (diary.recordId != value) {
          diary.recordId = value;
          changed.add(diary);
        }
      }
      if (changed.isNotEmpty) _obxHelper.diaryBox.putMany(changed);
    });
  }

  @override
  int saveDiary(DiaryEntity diary) {
    _prepareRecordId(diary);
    // 트리거: 생성 및 수정 시 자동으로 lastModified 갱신
    diary.lastModified = DateTime.now();
    return _obxHelper.diaryBox.put(diary);
  }

  @override
  int saveDiaryWithActivities(
    DiaryEntity diary,
    List<ActivityEntity> activities, {
    String? consumedDraftId,
  }) {
    _prepareRecordId(diary);
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
      if (consumedDraftId != null) {
        final draftQuery = _obxHelper.draftBox
            .query(RecordDraftEntity_.draftId.equals(consumedDraftId))
            .build();
        final draftId = draftQuery.findFirst()?.id;
        draftQuery.close();
        if (draftId != null) _obxHelper.draftBox.remove(draftId);
      }
      return diaryId;
    });
  }

  void _prepareRecordId(DiaryEntity diary) {
    var value = diary.recordId?.trim().toLowerCase();
    final collides =
        value != null &&
        _obxHelper.diaryBox.getAll().any(
          (item) => item.id != diary.id && item.recordId == value,
        );
    if (value == null || !_uuidV4Pattern.hasMatch(value) || collides) {
      final used = _obxHelper.diaryBox
          .getAll()
          .map((item) => item.recordId)
          .whereType<String>()
          .toSet();
      do {
        value = _uuid.v4();
      } while (used.contains(value));
    }
    diary.recordId = value;
  }

  @override
  CanonicalExportDocument createExportDocument({required String appVersion}) {
    final diaries = getDiaries()
        .map((diary) {
          final activities = diary.activities
              .map(
                (activity) => CanonicalActivity(
                  type: activity.type,
                  time: activity.time,
                  details: activity.details,
                  lastModified: activity.lastModified,
                ),
              )
              .toList(growable: false);
          return CanonicalDiary(
            recordId: diary.recordId!,
            date: diary.date,
            title: diary.title,
            summary: diary.summary,
            content: diary.content,
            lastModified: diary.lastModified,
            activities: activities,
          );
        })
        .toList(growable: false);
    return CanonicalExportDocument(
      exportedAt: DateTime.now().toUtc(),
      appVersion: appVersion,
      diaries: diaries,
    );
  }

  @override
  ImportPreview previewImport(
    CanonicalImportDocument document,
    ImportConflictPolicy policy,
  ) {
    final existing = _recordsByTransferId();
    var newCount = 0;
    var duplicateCount = 0;
    var newerCount = 0;
    var skippedCount = 0;
    var activityCount = 0;
    for (final incoming in document.diaries) {
      activityCount += incoming.activities.length;
      final local = existing[incoming.recordId];
      if (local == null) {
        newCount++;
      } else {
        duplicateCount++;
        if (policy == ImportConflictPolicy.overwriteIfNewer &&
            incoming.lastModified.isAfter(local.lastModified)) {
          newerCount++;
        } else {
          skippedCount++;
        }
      }
    }
    return ImportPreview(
      total: document.diaries.length,
      newCount: newCount,
      duplicateCount: duplicateCount,
      newerCount: newerCount,
      skippedCount: skippedCount,
      activityCount: activityCount,
    );
  }

  @override
  ImportResult importDocument(
    CanonicalImportDocument document,
    ImportConflictPolicy policy,
  ) {
    return _obxHelper.store.runInTransaction(TxMode.write, () {
      final existing = _recordsByTransferId();
      var inserted = 0;
      var updated = 0;
      var skipped = 0;
      final affected = <String>[];

      for (final incoming in document.diaries) {
        final local = existing[incoming.recordId];
        final shouldUpdate =
            local != null &&
            policy == ImportConflictPolicy.overwriteIfNewer &&
            incoming.lastModified.isAfter(local.lastModified);
        if (local != null && !shouldUpdate) {
          skipped++;
          continue;
        }

        final diary = DiaryEntity(
          id: local?.id ?? 0,
          recordId: incoming.recordId,
          date: incoming.date,
          title: incoming.title,
          summary: incoming.summary,
          content: incoming.content,
          lastModified: incoming.lastModified,
          embedding: null,
        );
        final diaryId = _obxHelper.diaryBox.put(diary);

        if (local != null) {
          final oldQuery = _obxHelper.activityBox
              .query(ActivityEntity_.diary.equals(diaryId))
              .build();
          final oldIds = oldQuery.findIds();
          oldQuery.close();
          if (oldIds.isNotEmpty) _obxHelper.activityBox.removeMany(oldIds);
          updated++;
        } else {
          inserted++;
        }

        final activities = incoming.activities
            .map((item) {
              final entity = ActivityEntity(
                type: item.type,
                time: item.time,
                details: item.details,
                lastModified: item.lastModified,
              );
              entity.diary.targetId = diaryId;
              return entity;
            })
            .toList(growable: false);
        if (activities.isNotEmpty) _obxHelper.activityBox.putMany(activities);
        existing[incoming.recordId] = diary;
        affected.add(incoming.recordId);
      }
      return ImportResult(
        inserted: inserted,
        updated: updated,
        skipped: skipped,
        embeddingPending: affected.length,
        affectedRecordIds: List.unmodifiable(affected),
      );
    });
  }

  Map<String, DiaryEntity> _recordsByTransferId() => {
    for (final diary in _obxHelper.diaryBox.getAll())
      if (diary.recordId case final String recordId) recordId: diary,
  };

  @override
  void updateEmbeddingPreservingLastModified(
    String recordId,
    List<double>? embedding,
  ) {
    final diary = _recordsByTransferId()[recordId];
    if (diary == null) return;
    final originalLastModified = diary.lastModified;
    diary.embedding = embedding;
    diary.lastModified = originalLastModified;
    _obxHelper.diaryBox.put(diary);
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
