import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_entity.dart';
import '../models/diary_entity.dart';
import '../models/author_profile_entity.dart';
import '../models/device_profile_entity.dart';
import '../models/search_document_entity.dart';
import '../data/objectbox_helper.dart';
import '../objectbox.g.dart';
import '../services/embedding_service.dart';
import '../features/search/domain/hybrid_search_query.dart';
import '../transfer/canonical_transfer_document.dart';
import 'package:uuid/uuid.dart';
import 'profile_repository.dart';

enum DiarySearchSource { memo, activity }

enum DiarySearchMatchReason {
  exactText,
  activityType,
  relatedExpression,
  structuredTemperature,
  structuredAuthor,
  structuredEvent,
  dateRange,
}

/// 검색 화면에 표시할 메모 또는 개별 이벤트 결과입니다.
class DiarySearchResult {
  final DiaryEntity diary;
  final ActivityEntity? activity;
  final DiarySearchMatchReason reason;

  /// 사용자에게 노출하지 않는 내부 정렬 점수입니다.
  final double relevanceScore;
  final double? matchedNumericValue;

  const DiarySearchResult({
    required this.diary,
    this.activity,
    required this.reason,
    required this.relevanceScore,
    this.matchedNumericValue,
  });

  DiarySearchSource get source =>
      activity == null ? DiarySearchSource.memo : DiarySearchSource.activity;

  DateTime get occurredAt => activity?.time ?? diary.date;

  String get resultKey =>
      activity == null ? 'memo:${diary.id}' : 'activity:${activity!.id}';
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

  /// 발생한 이벤트를 같은 날짜의 기록에 추가합니다. 해당 날짜의 기록이
  /// 없으면 타임라인용 빈 기록을 함께 만들어 이벤트가 고아가 되지 않게 합니다.
  int addActivityRecord(ActivityEntity activity);

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

  /// 키워드가 일치하는 메모·이벤트와 선택형 의미 검색 결과를 반환합니다.
  /// 임베딩을 사용할 수 없어도 키워드 검색은 정상 동작합니다.
  Future<List<DiarySearchResult>> searchRecords(
    HybridSearchQuery query,
    EmbeddingEngine embeddingService, {
    int limit = 50,
  });

  /// 원본 메모·이벤트로부터 파생 검색 문서를 동기화하고 가능한 문서를 임베딩합니다.
  Future<int> rebuildSearchIndex(
    EmbeddingEngine embeddingService, {
    Set<String>? recordIds,
  });

  bool get hasPendingSearchEmbeddings;
}

/// DiaryRepository의 ObjectBox 구현체
class DiaryRepositoryImpl implements DiaryRepository {
  final ObjectBoxHelper _obxHelper;
  final ProfileRepository _profileRepository;
  static const _uuid = Uuid();
  static final _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  DiaryRepositoryImpl(this._obxHelper, this._profileRepository) {
    _backfillRecordIds();
    _backfillActivityIds();
    _backfillRecordSources();
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

  void _backfillActivityIds() {
    _obxHelper.store.runInTransaction(TxMode.write, () {
      final activities = _obxHelper.activityBox.getAll();
      final used = <String>{};
      final changed = <ActivityEntity>[];
      for (final activity in activities) {
        var value = activity.recordId?.trim().toLowerCase();
        var didChange = false;
        if (value == null ||
            !_uuidV4Pattern.hasMatch(value) ||
            !used.add(value)) {
          do {
            value = _uuid.v4();
          } while (!used.add(value));
          activity.recordId = value;
          didChange = true;
        } else if (activity.recordId != value) {
          activity.recordId = value;
          didChange = true;
        }
        if (activity.revision < 1) {
          activity.revision = 1;
          didChange = true;
        }
        if (didChange) changed.add(activity);
      }
      if (changed.isNotEmpty) _obxHelper.activityBox.putMany(changed);
    });
  }

  /// UX-012 이전의 로컬 데이터와 v1 백업에는 출처가 없다. 최초 마이그레이션
  /// 시점의 현재 작성자·현재 설치를 출처로 채우고 원래 수정 시각은 보존한다.
  void _backfillRecordSources() {
    final source = _profileRepository.requireCurrentSource();
    _obxHelper.store.runInTransaction(TxMode.write, () {
      final diaries = _obxHelper.diaryBox.getAll();
      final changedDiaries = <DiaryEntity>[];
      for (final diary in diaries) {
        var changed = false;
        if (diary.createdAt == null) {
          diary.createdAt = diary.lastModified;
          changed = true;
        }
        if (diary.createdByAuthorProfileId == null) {
          diary.createdByAuthorProfileId = source.authorProfileId;
          changed = true;
        }
        if (diary.createdByDeviceProfileId == null) {
          diary.createdByDeviceProfileId = source.deviceProfileId;
          changed = true;
        }
        if (diary.lastModifiedByAuthorProfileId == null) {
          diary.lastModifiedByAuthorProfileId = source.authorProfileId;
          changed = true;
        }
        if (diary.lastModifiedByDeviceProfileId == null) {
          diary.lastModifiedByDeviceProfileId = source.deviceProfileId;
          changed = true;
        }
        if (changed) changedDiaries.add(diary);
      }
      if (changedDiaries.isNotEmpty) {
        _obxHelper.diaryBox.putMany(changedDiaries);
      }

      final activities = _obxHelper.activityBox.getAll();
      final changedActivities = <ActivityEntity>[];
      for (final activity in activities) {
        var changed = false;
        if (activity.createdAt == null) {
          activity.createdAt = activity.lastModified;
          changed = true;
        }
        if (activity.createdByAuthorProfileId == null) {
          activity.createdByAuthorProfileId = source.authorProfileId;
          changed = true;
        }
        if (activity.createdByDeviceProfileId == null) {
          activity.createdByDeviceProfileId = source.deviceProfileId;
          changed = true;
        }
        if (activity.lastModifiedByAuthorProfileId == null) {
          activity.lastModifiedByAuthorProfileId = source.authorProfileId;
          changed = true;
        }
        if (activity.lastModifiedByDeviceProfileId == null) {
          activity.lastModifiedByDeviceProfileId = source.deviceProfileId;
          changed = true;
        }
        if (changed) changedActivities.add(activity);
      }
      if (changedActivities.isNotEmpty) {
        _obxHelper.activityBox.putMany(changedActivities);
      }
    });
  }

  @override
  int saveDiary(DiaryEntity diary) {
    _prepareRecordId(diary);
    final now = DateTime.now();
    _prepareDiarySource(diary, now);
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
      _prepareDiarySource(diary, now);
      final diaryId = _obxHelper.diaryBox.put(diary);

      final oldQuery = _obxHelper.activityBox
          .query(ActivityEntity_.diary.equals(diaryId))
          .build();
      final oldActivities = oldQuery.find();
      final unmatchedOldActivities = [...oldActivities];
      final oldIds = oldQuery.findIds();
      oldQuery.close();
      if (oldIds.isNotEmpty) {
        _obxHelper.activityBox.removeMany(oldIds);
      }

      final usedActivityRecordIds = _obxHelper.activityBox
          .getAll()
          .map((activity) => activity.recordId)
          .whereType<String>()
          .toSet();
      for (final activity in activities) {
        final previous = _takePreviousActivity(
          activity,
          unmatchedOldActivities,
        );
        activity
          ..customEventTypeId =
              activity.customEventTypeId ?? previous?.customEventTypeId
          ..customEventNameSnapshot =
              activity.customEventNameSnapshot ??
              previous?.customEventNameSnapshot;
        _prepareActivityIdentity(
          activity,
          previous: previous,
          used: usedActivityRecordIds,
        );
        _prepareActivitySource(activity, now, previous: previous);
        activity.diary.target = diary;
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

  @override
  int addActivityRecord(ActivityEntity activity) {
    final sameDayDiaries =
        _obxHelper.diaryBox
            .getAll()
            .where(
              (diary) =>
                  diary.date.year == activity.time.year &&
                  diary.date.month == activity.time.month &&
                  diary.date.day == activity.time.day,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final diary = sameDayDiaries.isEmpty
        ? DiaryEntity(
            date: activity.time,
            title: '',
            content: '',
            lastModified: activity.lastModified,
          )
        : sameDayDiaries.first;
    _prepareRecordId(diary);

    return _obxHelper.store.runInTransaction(TxMode.write, () {
      final now = DateTime.now();
      _prepareDiarySource(diary, now);
      _obxHelper.diaryBox.put(diary);
      activity.diary.target = diary;
      _prepareActivityIdentity(
        activity,
        used: _obxHelper.activityBox
            .getAll()
            .map((item) => item.recordId)
            .whereType<String>()
            .toSet(),
      );
      _prepareActivitySource(activity, now);
      return _obxHelper.activityBox.put(activity);
    });
  }

  void _prepareDiarySource(DiaryEntity diary, DateTime now) {
    final source = _profileRepository.requireCurrentSource();
    final previous = diary.id == 0 ? null : _obxHelper.diaryBox.get(diary.id);
    diary
      ..createdAt = diary.createdAt ?? previous?.createdAt ?? now
      ..createdByAuthorProfileId =
          diary.createdByAuthorProfileId ??
          previous?.createdByAuthorProfileId ??
          source.authorProfileId
      ..createdByDeviceProfileId =
          diary.createdByDeviceProfileId ??
          previous?.createdByDeviceProfileId ??
          source.deviceProfileId
      ..lastModifiedByAuthorProfileId = source.authorProfileId
      ..lastModifiedByDeviceProfileId = source.deviceProfileId
      ..lastModified = now;
  }

  void _prepareActivitySource(
    ActivityEntity activity,
    DateTime now, {
    ActivityEntity? previous,
  }) {
    final source = _profileRepository.requireCurrentSource();
    activity
      ..createdAt = activity.createdAt ?? previous?.createdAt ?? now
      ..createdByAuthorProfileId =
          activity.createdByAuthorProfileId ??
          previous?.createdByAuthorProfileId ??
          source.authorProfileId
      ..createdByDeviceProfileId =
          activity.createdByDeviceProfileId ??
          previous?.createdByDeviceProfileId ??
          source.deviceProfileId
      ..lastModifiedByAuthorProfileId = source.authorProfileId
      ..lastModifiedByDeviceProfileId = source.deviceProfileId
      ..lastModified = now;
  }

  ActivityEntity? _takePreviousActivity(
    ActivityEntity incoming,
    List<ActivityEntity> candidates,
  ) {
    var matchIndex = incoming.recordId == null
        ? -1
        : candidates.indexWhere(
            (candidate) => candidate.recordId == incoming.recordId,
          );
    matchIndex = matchIndex >= 0
        ? matchIndex
        : candidates.indexWhere(
            (candidate) =>
                candidate.type == incoming.type &&
                candidate.time.isAtSameMomentAs(incoming.time) &&
                candidate.timePrecision == incoming.timePrecision &&
                candidate.details == incoming.details,
          );
    if (matchIndex < 0) {
      final sameTime = <int>[];
      for (var index = 0; index < candidates.length; index++) {
        final candidate = candidates[index];
        if (candidate.time.isAtSameMomentAs(incoming.time) &&
            candidate.timePrecision == incoming.timePrecision) {
          sameTime.add(index);
        }
      }
      if (sameTime.length == 1) matchIndex = sameTime.single;
    }
    return matchIndex < 0 ? null : candidates.removeAt(matchIndex);
  }

  void _prepareActivityIdentity(
    ActivityEntity activity, {
    ActivityEntity? previous,
    required Set<String> used,
  }) {
    var value = activity.recordId?.trim().toLowerCase();
    if (value == null ||
        !_uuidV4Pattern.hasMatch(value) ||
        used.contains(value)) {
      value = previous?.recordId;
    }
    if (value == null ||
        !_uuidV4Pattern.hasMatch(value) ||
        used.contains(value)) {
      do {
        value = _uuid.v4();
      } while (used.contains(value));
    }
    used.add(value);
    activity.recordId = value;

    if (previous == null) {
      if (activity.revision < 1) activity.revision = 1;
      return;
    }
    activity.revision = _sameActivityCore(activity, previous)
        ? previous.revision
        : previous.revision + 1;
  }

  bool _sameActivityCore(ActivityEntity left, ActivityEntity right) =>
      left.type == right.type &&
      left.time.isAtSameMomentAs(right.time) &&
      left.timePrecision == right.timePrecision &&
      left.details == right.details &&
      left.customEventTypeId == right.customEventTypeId &&
      left.customEventNameSnapshot == right.customEventNameSnapshot;

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
                  timePrecision: activity.timePrecision,
                  details: activity.details,
                  createdAt: activity.createdAt,
                  createdByAuthorProfileId: activity.createdByAuthorProfileId,
                  createdByDeviceProfileId: activity.createdByDeviceProfileId,
                  lastModifiedByAuthorProfileId:
                      activity.lastModifiedByAuthorProfileId,
                  lastModifiedByDeviceProfileId:
                      activity.lastModifiedByDeviceProfileId,
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
            createdAt: diary.createdAt,
            createdByAuthorProfileId: diary.createdByAuthorProfileId,
            createdByDeviceProfileId: diary.createdByDeviceProfileId,
            lastModifiedByAuthorProfileId: diary.lastModifiedByAuthorProfileId,
            lastModifiedByDeviceProfileId: diary.lastModifiedByDeviceProfileId,
            lastModified: diary.lastModified,
            activities: activities,
          );
        })
        .toList(growable: false);
    return CanonicalExportDocument(
      exportedAt: DateTime.now().toUtc(),
      appVersion: appVersion,
      authorProfiles: _obxHelper.authorProfileBox
          .getAll()
          .map(
            (profile) => CanonicalAuthorProfile(
              authorProfileId: profile.authorProfileId,
              nickname: profile.nickname,
              colorValue: profile.colorValue,
              createdAt: profile.createdAt,
            ),
          )
          .toList(growable: false),
      deviceProfiles: _obxHelper.deviceProfileBox
          .getAll()
          .map(
            (profile) => CanonicalDeviceProfile(
              deviceProfileId: profile.deviceProfileId,
              createdAt: profile.createdAt,
            ),
          )
          .toList(growable: false),
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
    var identicalCount = 0;
    var conflictCount = 0;
    for (final incoming in document.diaries) {
      activityCount += incoming.activities.length;
      final local = existing[incoming.recordId];
      if (local == null) {
        newCount++;
      } else {
        duplicateCount++;
        if (_hasSameContent(local, incoming)) {
          identicalCount++;
        } else {
          conflictCount++;
        }
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
      identicalCount: identicalCount,
      conflictCount: conflictCount,
    );
  }

  bool _hasSameContent(DiaryEntity local, CanonicalDiary incoming) {
    if (!_sameWallClock(local.date, incoming.date) ||
        local.title != incoming.title ||
        local.summary != incoming.summary ||
        local.content != incoming.content) {
      return false;
    }
    final localActivities = local.activities.map(_activitySignature).toList()
      ..sort();
    final incomingActivities =
        incoming.activities.map(_canonicalActivitySignature).toList()..sort();
    if (localActivities.length != incomingActivities.length) return false;
    for (var index = 0; index < localActivities.length; index++) {
      if (localActivities[index] != incomingActivities[index]) return false;
    }
    return true;
  }

  bool _sameWallClock(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day &&
      first.hour == second.hour &&
      first.minute == second.minute &&
      first.second == second.second &&
      first.millisecond == second.millisecond;

  String _activitySignature(ActivityEntity activity) => [
    activity.type,
    _wallClockSignature(activity.time),
    activity.timePrecision.toString(),
    activity.details,
  ].join('\u0000');

  String _canonicalActivitySignature(CanonicalActivity activity) => [
    activity.type,
    _wallClockSignature(activity.time),
    activity.timePrecision.toString(),
    activity.details,
  ].join('\u0000');

  String _wallClockSignature(DateTime value) => [
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
  ].join(':');

  @override
  ImportResult importDocument(
    CanonicalImportDocument document,
    ImportConflictPolicy policy,
  ) {
    return _obxHelper.store.runInTransaction(TxMode.write, () {
      _mergeImportedProfiles(document);
      final migrationSource = _profileRepository.requireCurrentSource();
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
          createdAt: incoming.createdAt ?? incoming.lastModified,
          createdByAuthorProfileId:
              incoming.createdByAuthorProfileId ??
              migrationSource.authorProfileId,
          createdByDeviceProfileId:
              incoming.createdByDeviceProfileId ??
              migrationSource.deviceProfileId,
          lastModifiedByAuthorProfileId:
              incoming.lastModifiedByAuthorProfileId ??
              migrationSource.authorProfileId,
          lastModifiedByDeviceProfileId:
              incoming.lastModifiedByDeviceProfileId ??
              migrationSource.deviceProfileId,
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
                recordId: _uuid.v4(),
                revision: 1,
                type: item.type,
                time: item.time,
                timePrecision: item.timePrecision,
                details: item.details,
                createdAt: item.createdAt ?? item.lastModified,
                createdByAuthorProfileId:
                    item.createdByAuthorProfileId ??
                    migrationSource.authorProfileId,
                createdByDeviceProfileId:
                    item.createdByDeviceProfileId ??
                    migrationSource.deviceProfileId,
                lastModifiedByAuthorProfileId:
                    item.lastModifiedByAuthorProfileId ??
                    migrationSource.authorProfileId,
                lastModifiedByDeviceProfileId:
                    item.lastModifiedByDeviceProfileId ??
                    migrationSource.deviceProfileId,
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

  void _mergeImportedProfiles(CanonicalImportDocument document) {
    final authorIds = _obxHelper.authorProfileBox
        .getAll()
        .map((item) => item.authorProfileId)
        .toSet();
    final deviceIds = _obxHelper.deviceProfileBox
        .getAll()
        .map((item) => item.deviceProfileId)
        .toSet();
    for (final profile in document.authorProfiles) {
      if (!authorIds.add(profile.authorProfileId)) continue;
      _obxHelper.authorProfileBox.put(
        AuthorProfileEntity(
          authorProfileId: profile.authorProfileId,
          nickname: profile.nickname,
          colorValue: profile.colorValue,
          createdAt: profile.createdAt,
        ),
      );
    }
    for (final profile in document.deviceProfiles) {
      if (!deviceIds.add(profile.deviceProfileId)) continue;
      _obxHelper.deviceProfileBox.put(
        DeviceProfileEntity(
          deviceProfileId: profile.deviceProfileId,
          createdAt: profile.createdAt,
        ),
      );
    }
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
      final searchQuery = _obxHelper.searchDocumentBox
          .query(SearchDocumentEntity_.sourceDiaryId.equals(id))
          .build();
      final searchIds = searchQuery.findIds();
      searchQuery.close();
      if (searchIds.isNotEmpty) {
        _obxHelper.searchDocumentBox.removeMany(searchIds);
      }
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
  Future<List<DiarySearchResult>> searchRecords(
    HybridSearchQuery query,
    EmbeddingEngine embeddingService, {
    int limit = 50,
  }) async {
    if (!query.hasCriteria || limit <= 0) return [];
    _synchronizeSearchDocuments();

    final normalizedText = query.text.trim().toLowerCase();
    final results = <String, DiarySearchResult>{};
    for (final document in _obxHelper.searchDocumentBox.getAll()) {
      if (!_matchesStructuredCriteria(document, query)) continue;
      if (normalizedText.isNotEmpty &&
          !document.searchableText.toLowerCase().contains(normalizedText)) {
        continue;
      }
      final result = _resultForDocument(
        document,
        reason: _matchReason(document, query, normalizedText),
        relevanceScore: normalizedText.isEmpty ? 120 : 100,
      );
      if (result != null) results[result.resultKey] = result;
    }

    if (normalizedText.isNotEmpty) {
      final queryVector = await embeddingService.getQueryEmbedding(
        normalizedText,
      );
      if (queryVector != null && queryVector.isNotEmpty) {
        final vectorQuery = _obxHelper.searchDocumentBox
            .query(
              SearchDocumentEntity_.embedding.nearestNeighborsF32(
                queryVector,
                limit * 4,
              ),
            )
            .build();
        try {
          final vectorMatches = await vectorQuery.findWithScoresAsync();
          for (final item in vectorMatches) {
            final document = item.object;
            if (!_matchesStructuredCriteria(document, query)) continue;
            final similarity = 1.0 - (item.score / 2.0);
            final score = ((similarity - 0.82) / 0.18 * 99).clamp(0.0, 99.0);
            if (score <= 0) continue;
            final result = _resultForDocument(
              document,
              reason: DiarySearchMatchReason.relatedExpression,
              relevanceScore: score,
            );
            if (result != null && !results.containsKey(result.resultKey)) {
              results[result.resultKey] = result;
            }
          }
        } finally {
          vectorQuery.close();
        }
      }
    }

    final sorted = results.values.toList()
      ..sort((a, b) {
        final relevance = b.relevanceScore.compareTo(a.relevanceScore);
        if (relevance != 0) return relevance;
        return b.occurredAt.compareTo(a.occurredAt);
      });
    return sorted.take(limit).toList(growable: false);
  }

  @override
  Future<int> rebuildSearchIndex(
    EmbeddingEngine embeddingService, {
    Set<String>? recordIds,
  }) async {
    _synchronizeSearchDocuments();
    if (!embeddingService.isAvailable) {
      return _obxHelper.searchDocumentBox
          .getAll()
          .where(
            (document) =>
                (recordIds == null ||
                    recordIds.contains(document.sourceRecordId)) &&
                document.embedding == null,
          )
          .length;
    }

    var failed = 0;
    for (final document in _obxHelper.searchDocumentBox.getAll()) {
      if (recordIds != null && !recordIds.contains(document.sourceRecordId)) {
        continue;
      }
      if (document.embedding != null &&
          document.embeddingModelVersion == embeddingService.modelVersion) {
        continue;
      }
      try {
        document.embedding = await embeddingService.getEmbedding(
          document.searchableText,
        );
        document.embeddingModelVersion = embeddingService.modelVersion;
        document.indexedAt = DateTime.now();
        _obxHelper.searchDocumentBox.put(document);
        if (document.embedding == null) failed++;
      } catch (_) {
        failed++;
      }
    }
    return failed;
  }

  @override
  bool get hasPendingSearchEmbeddings => _obxHelper.searchDocumentBox
      .getAll()
      .any((document) => document.embedding == null);

  void _synchronizeSearchDocuments() {
    final diaries = _obxHelper.diaryBox.getAll();
    final activities = _obxHelper.activityBox.getAll();
    final existing = {
      for (final document in _obxHelper.searchDocumentBox.getAll())
        document.searchDocumentId: document,
    };
    final currentIds = <String>{};
    final changed = <SearchDocumentEntity>[];
    final now = DateTime.now();

    for (final diary in diaries) {
      final recordId = diary.recordId;
      if (recordId == null) continue;
      final documentId = 'memo:$recordId';
      currentIds.add(documentId);
      final text = [
        diary.title,
        diary.summary,
        diary.content,
      ].where((part) => part.trim().isNotEmpty).join('\n');
      changed.add(
        _mergeSearchDocument(
          existing[documentId],
          searchDocumentId: documentId,
          sourceRecordId: recordId,
          sourceType: SearchDocumentEntity.sourceTypeMemo,
          sourceEntityId: diary.id,
          sourceDiaryId: diary.id,
          searchableText: text,
          occurredAt: diary.date,
          authorProfileId: diary.createdByAuthorProfileId,
          eventKind: 0,
          numericValue: null,
          indexedAt: now,
        ),
      );
    }

    for (final activity in activities) {
      final diary = activity.diary.target;
      final recordId = diary?.recordId;
      if (diary == null || recordId == null) continue;
      final documentId = 'event:${activity.recordId ?? activity.id}';
      currentIds.add(documentId);
      final kind = _inferEventKind('${activity.type} ${activity.details}');
      changed.add(
        _mergeSearchDocument(
          existing[documentId],
          searchDocumentId: documentId,
          sourceRecordId: recordId,
          sourceType: SearchDocumentEntity.sourceTypeEvent,
          sourceEntityId: activity.id,
          sourceDiaryId: diary.id,
          searchableText: '${activity.type}\n${activity.details}'.trim(),
          occurredAt: activity.time,
          authorProfileId: activity.createdByAuthorProfileId,
          eventKind: kind == null ? 0 : kind.index + 1,
          numericValue: kind == SearchEventKind.temperature
              ? _extractTemperature('${activity.type} ${activity.details}')
              : null,
          indexedAt: now,
        ),
      );
    }

    _obxHelper.store.runInTransaction(TxMode.write, () {
      if (changed.isNotEmpty) _obxHelper.searchDocumentBox.putMany(changed);
      final staleIds = existing.values
          .where((document) => !currentIds.contains(document.searchDocumentId))
          .map((document) => document.id)
          .toList(growable: false);
      if (staleIds.isNotEmpty) {
        _obxHelper.searchDocumentBox.removeMany(staleIds);
      }
    });
  }

  SearchDocumentEntity _mergeSearchDocument(
    SearchDocumentEntity? previous, {
    required String searchDocumentId,
    required String sourceRecordId,
    required String sourceType,
    required int sourceEntityId,
    required int sourceDiaryId,
    required String searchableText,
    required DateTime occurredAt,
    required String? authorProfileId,
    required int eventKind,
    required double? numericValue,
    required DateTime indexedAt,
  }) {
    final hash = _contentHash(
      [
        searchableText,
        occurredAt.toIso8601String(),
        authorProfileId ?? '',
        eventKind.toString(),
        numericValue?.toString() ?? '',
      ].join('\u0000'),
    );
    final unchanged = previous?.sourceContentHash == hash;
    return SearchDocumentEntity(
      id: previous?.id ?? 0,
      searchDocumentId: searchDocumentId,
      sourceRecordId: sourceRecordId,
      sourceType: sourceType,
      sourceEntityId: sourceEntityId,
      sourceDiaryId: sourceDiaryId,
      searchableText: searchableText,
      embedding: unchanged ? previous?.embedding : null,
      embeddingModelVersion: unchanged
          ? previous?.embeddingModelVersion ?? ''
          : '',
      sourceContentHash: hash,
      indexedAt: unchanged ? previous!.indexedAt : indexedAt,
      occurredAt: occurredAt,
      authorProfileId: authorProfileId,
      eventKind: eventKind,
      numericValue: numericValue,
    );
  }

  String _contentHash(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  bool _matchesStructuredCriteria(
    SearchDocumentEntity document,
    HybridSearchQuery query,
  ) {
    if (query.from != null && document.occurredAt.isBefore(query.from!)) {
      return false;
    }
    if (query.untilExclusive != null &&
        !document.occurredAt.isBefore(query.untilExclusive!)) {
      return false;
    }
    if (query.authorProfileId != null &&
        document.authorProfileId != query.authorProfileId) {
      return false;
    }
    if (query.eventKind != null &&
        document.eventKind != query.eventKind!.index + 1) {
      return false;
    }
    final temperature = query.temperature;
    if (temperature != null) {
      final value = document.numericValue;
      if (value == null) return false;
      final matches = switch (temperature.comparison) {
        NumericComparison.atLeast => value >= temperature.value,
        NumericComparison.above => value > temperature.value,
        NumericComparison.atMost => value <= temperature.value,
        NumericComparison.below => value < temperature.value,
      };
      if (!matches) return false;
    }
    return true;
  }

  DiarySearchMatchReason _matchReason(
    SearchDocumentEntity document,
    HybridSearchQuery query,
    String normalizedText,
  ) {
    if (query.temperature != null) {
      return DiarySearchMatchReason.structuredTemperature;
    }
    if (query.eventKind != null) {
      return DiarySearchMatchReason.structuredEvent;
    }
    if (query.authorProfileId != null) {
      return DiarySearchMatchReason.structuredAuthor;
    }
    if (query.from != null || query.untilExclusive != null) {
      return DiarySearchMatchReason.dateRange;
    }
    if (document.sourceType == SearchDocumentEntity.sourceTypeEvent) {
      final activity = _obxHelper.activityBox.get(document.sourceEntityId);
      if (activity != null &&
          activity.type.toLowerCase().contains(normalizedText)) {
        return DiarySearchMatchReason.activityType;
      }
    }
    return DiarySearchMatchReason.exactText;
  }

  DiarySearchResult? _resultForDocument(
    SearchDocumentEntity document, {
    required DiarySearchMatchReason reason,
    required double relevanceScore,
  }) {
    final diary = _obxHelper.diaryBox.get(document.sourceDiaryId);
    if (diary == null) return null;
    final activity = document.sourceType == SearchDocumentEntity.sourceTypeEvent
        ? _obxHelper.activityBox.get(document.sourceEntityId)
        : null;
    if (document.sourceType == SearchDocumentEntity.sourceTypeEvent &&
        activity == null) {
      return null;
    }
    return DiarySearchResult(
      diary: diary,
      activity: activity,
      reason: reason,
      relevanceScore: relevanceScore,
      matchedNumericValue: document.numericValue,
    );
  }

  SearchEventKind? _inferEventKind(String text) {
    final value = text.toLowerCase();
    const aliases = <SearchEventKind, List<String>>{
      SearchEventKind.temperature: [
        '체온',
        '열',
        '발열',
        'temperature',
        'fever',
        '体温',
        '熱',
      ],
      SearchEventKind.medication: [
        '투약',
        '약',
        '복용',
        'medication',
        'medicine',
        '投薬',
        '服薬',
      ],
      SearchEventKind.feeding: ['수유', '분유', 'feeding', 'feed', '授乳', 'ミルク'],
      SearchEventKind.diaper: ['기저귀', 'diaper', 'おむつ', '尿布'],
      SearchEventKind.sleep: ['수면', '잠', 'sleep', 'nap', '睡眠', '昼寝'],
      SearchEventKind.hospital: ['병원', '진료', 'hospital', 'clinic', '病院', '診療'],
    };
    for (final entry in aliases.entries) {
      if (entry.value.any(value.contains)) return entry.key;
    }
    return null;
  }

  double? _extractTemperature(String text) {
    final match = RegExp(
      r'(\d{2}(?:\.\d+)?)\s*(?:°\s*c|℃|도|度)?',
      caseSensitive: false,
    ).firstMatch(text);
    final value = double.tryParse(match?.group(1) ?? '');
    if (value == null || value < 30 || value > 45) return null;
    return value;
  }
}

/// Riverpod에서 제공할 DiaryRepository 프로바이더
final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final obxHelper = ref.watch(objectBoxProvider);
  final profiles = ref.watch(profileRepositoryProvider);
  return DiaryRepositoryImpl(obxHelper, profiles);
}, dependencies: [objectBoxProvider, profileRepositoryProvider]);
