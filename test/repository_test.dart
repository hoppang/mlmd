import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/objectbox.g.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/models/author_profile_entity.dart';
import 'package:mlmd/models/device_profile_entity.dart';
import 'package:mlmd/models/search_document_entity.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/features/search/domain/hybrid_search_query.dart';
import 'package:mlmd/repositories/diary_repository.dart';
import 'package:mlmd/repositories/activity_repository.dart';
import 'package:mlmd/repositories/record_draft_repository.dart';
import 'package:mlmd/repositories/profile_repository.dart';
import 'package:mlmd/services/embedding_service.dart';

// ObjectBoxHelper의 테스트용 구현체 (임시 디렉터리에 데이터베이스 가동)
class TestObjectBoxHelper implements ObjectBoxHelper {
  @override
  late final Store store;
  @override
  late final Box<DiaryEntity> diaryBox;
  @override
  late final Box<ActivityEntity> activityBox;
  @override
  late final Box<RecordDraftEntity> draftBox;
  @override
  late final Box<AuthorProfileEntity> authorProfileBox;
  @override
  late final Box<DeviceProfileEntity> deviceProfileBox;
  @override
  late final Box<SearchDocumentEntity> searchDocumentBox;

  TestObjectBoxHelper(this.store) {
    diaryBox = Box<DiaryEntity>(store);
    activityBox = Box<ActivityEntity>(store);
    draftBox = Box<RecordDraftEntity>(store);
    authorProfileBox = Box<AuthorProfileEntity>(store);
    deviceProfileBox = Box<DeviceProfileEntity>(store);
    searchDocumentBox = Box<SearchDocumentEntity>(store);
  }

  static Future<TestObjectBoxHelper> createTemp() async {
    final tempDir = await Directory.systemTemp.createTemp('obx-test');
    final store = await openStore(directory: tempDir.path);
    return TestObjectBoxHelper(store);
  }

  Future<void> close() async {
    store.close();
  }
}

class _FakeEmbeddingEngine implements EmbeddingEngine {
  @override
  bool get isAvailable => true;

  @override
  String get modelVersion => 'fake-384-v1';

  @override
  Future<List<double>?> getEmbedding(String text) async => _vector;

  @override
  Future<List<double>?> getQueryEmbedding(String query) async => _vector;

  List<double> get _vector => [1, ...List<double>.filled(383, 0)];
}

void main() {
  late TestObjectBoxHelper obxHelper;
  late DiaryRepository diaryRepo;
  late ActivityRepository activityRepo;
  late RecordDraftRepository draftRepo;
  late ProfileRepository profileRepo;

  setUp(() async {
    obxHelper = await TestObjectBoxHelper.createTemp();
    profileRepo = ProfileRepositoryImpl(obxHelper);
    profileRepo.createAuthor(nickname: '테스트 작성자', colorValue: 0xFF00796B);
    diaryRepo = DiaryRepositoryImpl(obxHelper, profileRepo);
    activityRepo = ActivityRepositoryImpl(obxHelper, profileRepo);
    draftRepo = RecordDraftRepositoryImpl(obxHelper);
  });

  tearDown(() async {
    await obxHelper.close();
  });

  group('Diary & Activity Repository CRUD + Trigger Tests', () {
    test('Saving a Diary should automatically set lastModified', () async {
      final diary = DiaryEntity(
        date: DateTime.now(),
        title: '오늘의 일기',
        content: '본문 내용',
        lastModified: DateTime.fromMillisecondsSinceEpoch(0), // 더미 값
      );

      final id = diaryRepo.saveDiary(diary);
      expect(id, greaterThan(0));

      final saved = diaryRepo.getDiary(id);
      expect(saved, isNotNull);
      expect(saved!.title, equals('오늘의 일기'));

      // lastModified가 현재 시간 주변으로 갱신되었는지 검증
      expect(saved.lastModified.millisecondsSinceEpoch, greaterThan(0));
      expect(
        DateTime.now().difference(saved.lastModified).inSeconds,
        lessThan(5),
      );
    });

    test(
      'Saving an Activity should link to Diary and update both lastModified',
      () async {
        // 1. 일기 생성
        final diary = DiaryEntity(
          date: DateTime.now(),
          title: '활동을 기록할 일기',
          content: '본문',
          lastModified: DateTime.fromMillisecondsSinceEpoch(0),
        );
        final diaryId = diaryRepo.saveDiary(diary);
        final savedDiaryBefore = diaryRepo.getDiary(diaryId)!;
        final initialDiaryTime = savedDiaryBefore.lastModified;

        // 2. 활동 로그 저장 (약간의 대기 후 저장하여 타임스탬프 차이를 둠)
        await Future.delayed(const Duration(milliseconds: 100));

        final activity = ActivityEntity(
          type: '수유',
          time: DateTime.now(),
          details: '120ml',
          lastModified: DateTime.fromMillisecondsSinceEpoch(0),
        );

        final activityId = activityRepo.saveActivity(activity, diaryId);
        expect(activityId, greaterThan(0));

        // 3. 활동 로그 갱신 확인
        final savedActivity = activityRepo.getActivity(activityId)!;
        expect(savedActivity.type, equals('수유'));
        expect(
          savedActivity.lastModified.millisecondsSinceEpoch,
          greaterThan(0),
        );
        expect(savedActivity.diary.targetId, equals(diaryId));
        expect(
          activityRepo.getActivitiesByDiary(diaryId).map((a) => a.id),
          contains(activityId),
        );

        // 4. 부모 일기의 타임스탬프가 연쇄 갱신되었는지 검증
        final savedDiaryAfter = diaryRepo.getDiary(diaryId)!;
        expect(savedDiaryAfter.lastModified.isAfter(initialDiaryTime), isTrue);
      },
    );

    test('Quick activity reuses its date container and preserves events', () {
      final occurredAt = DateTime(2026, 7, 23, 9);
      final firstId = diaryRepo.addActivityRecord(
        ActivityEntity(
          type: '수유',
          time: occurredAt,
          details: '180mL',
          lastModified: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      final secondId = diaryRepo.addActivityRecord(
        ActivityEntity(
          type: '투약',
          time: occurredAt.add(const Duration(hours: 2)),
          details: '2.5mL',
          lastModified: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );

      final diaries = diaryRepo.getDiaries();
      expect(diaries, hasLength(1));
      expect(diaries.single.activities.map((activity) => activity.id).toSet(), {
        firstId,
        secondId,
      });
      expect(
        diaries.single.activities.map((activity) => activity.type).toSet(),
        {'수유', '투약'},
      );
    });

    test(
      'Deleting an Activity should update parent Diary lastModified',
      () async {
        // 1. 일기 및 활동 생성
        final diary = DiaryEntity(
          date: DateTime.now(),
          title: '활동 삭제 일기',
          content: '본문',
          lastModified: DateTime.now(),
        );
        final diaryId = diaryRepo.saveDiary(diary);

        final activity = ActivityEntity(
          type: '수면',
          time: DateTime.now(),
          details: '2시간',
          lastModified: DateTime.now(),
        );
        final activityId = activityRepo.saveActivity(activity, diaryId);

        final savedDiaryBefore = diaryRepo.getDiary(diaryId)!;
        final diaryTimeBeforeDelete = savedDiaryBefore.lastModified;

        // 2. 삭제 시 타임스탬프 차이를 위해 약간 지연
        await Future.delayed(const Duration(milliseconds: 100));

        // 3. 활동 삭제
        final isDeleted = activityRepo.deleteActivity(activityId);
        expect(isDeleted, isTrue);

        // 4. 부모 일기 타임스탬프가 갱신되었는지 검증
        final savedDiaryAfter = diaryRepo.getDiary(diaryId)!;
        expect(
          savedDiaryAfter.lastModified.isAfter(diaryTimeBeforeDelete),
          isTrue,
        );

        // 5. 활동이 더이상 조회되지 않는지 검증
        expect(activityRepo.getActivity(activityId), isNull);
      },
    );

    test('Replacing Diary activities removes old activity entities', () {
      final diary = DiaryEntity(
        date: DateTime.now(),
        title: '교체 테스트',
        content: '본문',
        lastModified: DateTime.now(),
      );
      final oldActivity = ActivityEntity(
        type: '수유',
        time: DateTime.now(),
        details: '100ml',
        lastModified: DateTime.now(),
      );

      final diaryId = diaryRepo.saveDiaryWithActivities(diary, [oldActivity]);
      final oldActivityId = oldActivity.id;
      expect(oldActivityId, greaterThan(0));
      expect(
        diaryRepo.getDiary(diaryId)!.activities.map((a) => a.id),
        contains(oldActivityId),
      );

      final newActivity = ActivityEntity(
        type: '수면',
        time: DateTime.now(),
        details: '2시간',
        lastModified: DateTime.now(),
      );
      diaryRepo.saveDiaryWithActivities(diary, [newActivity]);

      expect(activityRepo.getActivity(oldActivityId), isNull);
      expect(
        activityRepo.getActivitiesByDiary(diaryId).map((a) => a.id),
        equals([newActivity.id]),
      );
    });

    test('Deleting a Diary also deletes its activity entities', () {
      final diary = DiaryEntity(
        date: DateTime.now(),
        title: '삭제 테스트',
        content: '본문',
        lastModified: DateTime.now(),
      );
      final activity = ActivityEntity(
        type: '병원',
        time: DateTime.now(),
        details: '정기 검진',
        lastModified: DateTime.now(),
      );
      final diaryId = diaryRepo.saveDiaryWithActivities(diary, [activity]);
      final activityId = activity.id;

      expect(diaryRepo.deleteDiary(diaryId), isTrue);
      expect(activityRepo.getActivity(activityId), isNull);
    });

    test('Exact text search works without an embedding model', () async {
      diaryRepo.saveDiary(
        DiaryEntity(
          date: DateTime.now(),
          title: '정확키워드가 있는 일기',
          content: '본문',
          lastModified: DateTime.now(),
        ),
      );

      final results = await diaryRepo.searchRecords(
        const HybridSearchQuery(text: '정확키워드'),
        EmbeddingService(),
      );

      expect(results, hasLength(1));
      expect(results.single.source, DiarySearchSource.memo);
      expect(results.single.reason, DiarySearchMatchReason.exactText);
      expect(results.single.relevanceScore, 100);
    });

    test(
      'Activity type and details are returned as individual results',
      () async {
        final now = DateTime.now();
        final diary = DiaryEntity(
          date: now,
          title: '하루 기록',
          content: '평범한 하루',
          lastModified: now,
        );
        diaryRepo.saveDiaryWithActivities(diary, [
          ActivityEntity(
            type: '투약',
            time: now,
            details: '해열제 복용',
            lastModified: now,
          ),
        ]);

        final byType = await diaryRepo.searchRecords(
          const HybridSearchQuery(text: '투약'),
          EmbeddingService(),
        );
        final byDetail = await diaryRepo.searchRecords(
          const HybridSearchQuery(text: '해열제'),
          EmbeddingService(),
        );

        expect(byType, hasLength(1));
        expect(byType.single.source, DiarySearchSource.activity);
        expect(byType.single.activity!.type, '투약');
        expect(byType.single.reason, DiarySearchMatchReason.activityType);
        expect(byDetail, hasLength(1));
        expect(byDetail.single.activity!.details, '해열제 복용');
        expect(byDetail.single.reason, DiarySearchMatchReason.exactText);
      },
    );

    test(
      'Structured event, temperature, date, and author filters work without text',
      () async {
        final authorId = profileRepo.currentAuthor!.authorProfileId;
        final occurredAt = DateTime(2026, 7, 20, 9, 30);
        final diary = DiaryEntity(
          date: occurredAt,
          title: '아침 기록',
          content: '',
          lastModified: occurredAt,
        );
        diaryRepo.saveDiaryWithActivities(diary, [
          ActivityEntity(
            type: '체온',
            time: occurredAt,
            details: '38.4도',
            lastModified: occurredAt,
          ),
        ]);

        final results = await diaryRepo.searchRecords(
          HybridSearchQuery(
            from: DateTime(2026, 7, 20),
            untilExclusive: DateTime(2026, 7, 21),
            eventKind: SearchEventKind.temperature,
            authorProfileId: authorId,
            temperature: const TemperatureFilter(
              value: 38,
              comparison: NumericComparison.atLeast,
            ),
          ),
          EmbeddingService(),
        );

        expect(results, hasLength(1));
        expect(results.single.activity?.type, '체온');
        expect(results.single.matchedNumericValue, 38.4);
        expect(
          results.single.reason,
          DiarySearchMatchReason.structuredTemperature,
        );
      },
    );

    test(
      'Derived search documents follow source updates and deletion',
      () async {
        final occurredAt = DateTime(2026, 7, 20, 9, 30);
        final diary = DiaryEntity(
          date: occurredAt,
          title: '하루 기록',
          content: '메모',
          lastModified: occurredAt,
        );
        diaryRepo.saveDiaryWithActivities(diary, [
          ActivityEntity(
            type: '체온',
            time: occurredAt,
            details: '38.4도',
            lastModified: occurredAt,
          ),
        ]);
        await diaryRepo.searchRecords(
          const HybridSearchQuery(eventKind: SearchEventKind.temperature),
          EmbeddingService(),
        );
        expect(obxHelper.searchDocumentBox.count(), 2);

        diaryRepo.saveDiaryWithActivities(diary, [
          ActivityEntity(
            type: '체온',
            time: occurredAt,
            details: '37.2도',
            lastModified: occurredAt,
          ),
        ]);
        final highTemperature = await diaryRepo.searchRecords(
          const HybridSearchQuery(
            eventKind: SearchEventKind.temperature,
            temperature: TemperatureFilter(
              value: 38,
              comparison: NumericComparison.atLeast,
            ),
          ),
          EmbeddingService(),
        );
        expect(highTemperature, isEmpty);
        expect(obxHelper.searchDocumentBox.count(), 2);

        expect(diaryRepo.deleteDiary(diary.id), isTrue);
        expect(obxHelper.searchDocumentBox.count(), 0);
      },
    );

    test('Semantic results use the derived document index', () async {
      final engine = _FakeEmbeddingEngine();
      final diary = DiaryEntity(
        date: DateTime(2026, 7, 20),
        title: '밤 기록',
        content: '아기가 편안하게 오래 잤다',
        lastModified: DateTime(2026, 7, 20),
      );
      diaryRepo.saveDiary(diary);
      expect(
        await diaryRepo.rebuildSearchIndex(
          engine,
          recordIds: {diary.recordId!},
        ),
        0,
      );

      final results = await diaryRepo.searchRecords(
        const HybridSearchQuery(text: '숙면'),
        engine,
      );

      expect(results, hasLength(1));
      expect(results.single.diary.id, diary.id);
      expect(results.single.reason, DiarySearchMatchReason.relatedExpression);
      final document = obxHelper.searchDocumentBox.getAll().single;
      expect(document.embeddingModelVersion, engine.modelVersion);
      expect(document.sourceContentHash, isNotEmpty);
    });

    test('Activity occurrence precision persists independently of time', () {
      final now = DateTime.now();
      final diaryId = diaryRepo.saveDiary(
        DiaryEntity(
          date: now,
          title: '시각 정밀도',
          content: 'AI 집계 이벤트',
          lastModified: now,
        ),
      );
      final activityId = activityRepo.saveActivity(
        ActivityEntity(
          type: '수유',
          time: now,
          timePrecision: ActivityEntity.timePrecisionUnknown,
          details: '여러 번',
          lastModified: now,
        ),
        diaryId,
      );

      final restored = activityRepo.getActivity(activityId)!;
      expect(restored.time.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(restored.hasExactTime, isFalse);
    });
  });

  group('Record draft repository', () {
    test('upserts by stable draft ID instead of creating duplicates', () {
      final now = DateTime.now();
      final draft = RecordDraftEntity(
        draftId: 'draft-stable-id',
        draftKind: 'createRecord',
        recordType: 'diary',
        fieldPayloadJson: '{"rawText":"처음"}',
        createdAt: now,
        lastSavedAt: now,
      );
      draftRepo.saveDraft(draft);
      draft.fieldPayloadJson = '{"rawText":"수정"}';
      draft.lastSavedAt = now.add(const Duration(seconds: 1));
      draftRepo.saveDraft(draft);

      expect(draftRepo.getAllDrafts(), hasLength(1));
      expect(
        draftRepo.getByDraftId('draft-stable-id')?.fieldPayloadJson,
        contains('수정'),
      );
    });

    test('final record commit consumes its draft in the same operation', () {
      final now = DateTime.now();
      draftRepo.saveDraft(
        RecordDraftEntity(
          draftId: 'draft-to-consume',
          draftKind: 'createRecord',
          recordType: 'diary',
          fieldPayloadJson: '{"rawText":"완료할 기록"}',
          createdAt: now,
          lastSavedAt: now,
        ),
      );
      final diary = DiaryEntity(
        date: now,
        title: '완료',
        content: '완료할 기록',
        lastModified: now,
      );

      diaryRepo.saveDiaryWithActivities(
        diary,
        const [],
        consumedDraftId: 'draft-to-consume',
      );

      expect(diaryRepo.getDiary(diary.id), isNotNull);
      expect(draftRepo.getByDraftId('draft-to-consume'), isNull);
    });
  });

  group('UX-012 author and device provenance', () {
    test('device identity is stable and separate from the author profile', () {
      final firstDevice = profileRepo.currentDevice.deviceProfileId;
      final firstAuthor = profileRepo.currentAuthor!.authorProfileId;
      final reopenedProfiles = ProfileRepositoryImpl(obxHelper);

      expect(reopenedProfiles.currentDevice.deviceProfileId, firstDevice);
      expect(reopenedProfiles.currentAuthor!.authorProfileId, firstAuthor);
      expect(firstDevice, isNot(firstAuthor));
    });

    test('creator is preserved while the active editor is updated', () {
      final firstAuthor = profileRepo.currentAuthor!.authorProfileId;
      final deviceId = profileRepo.currentDevice.deviceProfileId;
      final diary = DiaryEntity(
        date: DateTime(2026, 7, 24, 10),
        title: '기록',
        content: '본문',
        lastModified: DateTime.utc(2026),
      );
      final diaryId = diaryRepo.saveDiary(diary);
      final created = diaryRepo.getDiary(diaryId)!;
      final createdAt = created.createdAt;

      final secondAuthor = profileRepo.createAuthor(
        nickname: '다른 작성자',
        colorValue: 0xFF1565C0,
      );
      created.title = '수정된 기록';
      diaryRepo.saveDiary(created);
      final updated = diaryRepo.getDiary(diaryId)!;

      expect(updated.createdByAuthorProfileId, firstAuthor);
      expect(updated.createdByDeviceProfileId, deviceId);
      expect(updated.createdAt, createdAt);
      expect(
        updated.lastModifiedByAuthorProfileId,
        secondAuthor.authorProfileId,
      );
      expect(updated.lastModifiedByDeviceProfileId, deviceId);
    });

    test('quick events store author and device provenance', () {
      final source = profileRepo.requireCurrentSource();
      diaryRepo.addActivityRecord(
        ActivityEntity(
          type: '수유',
          time: DateTime(2026, 7, 24, 11),
          details: '120mL',
          lastModified: DateTime.utc(2026),
        ),
      );

      final activity = activityRepo.getActivities().single;
      expect(activity.createdAt, isNotNull);
      expect(activity.createdByAuthorProfileId, source.authorProfileId);
      expect(activity.createdByDeviceProfileId, source.deviceProfileId);
      expect(activity.lastModifiedByAuthorProfileId, source.authorProfileId);
      expect(activity.lastModifiedByDeviceProfileId, source.deviceProfileId);
    });

    test('removing an earlier event does not move its creator to another', () {
      final firstAuthor = profileRepo.currentAuthor!.authorProfileId;
      final day = DateTime(2026, 7, 24, 12);
      diaryRepo.addActivityRecord(
        ActivityEntity(
          type: '수유',
          time: day,
          details: '100mL',
          lastModified: DateTime.utc(2026),
        ),
      );
      final secondAuthor = profileRepo.createAuthor(
        nickname: '다른 작성자',
        colorValue: 0xFF1565C0,
      );
      diaryRepo.addActivityRecord(
        ActivityEntity(
          type: '체온',
          time: day.add(const Duration(hours: 1)),
          details: '37.2°C',
          lastModified: DateTime.utc(2026),
        ),
      );
      final diary = diaryRepo.getDiaries().single;
      final secondEvent = diary.activities.firstWhere(
        (activity) => activity.type == '체온',
      );

      diaryRepo.saveDiaryWithActivities(diary, [
        ActivityEntity(
          type: secondEvent.type,
          time: secondEvent.time,
          timePrecision: secondEvent.timePrecision,
          details: secondEvent.details,
          lastModified: secondEvent.lastModified,
        ),
      ]);

      final remaining = activityRepo.getActivities().single;
      expect(remaining.createdByAuthorProfileId, secondAuthor.authorProfileId);
      expect(remaining.createdByAuthorProfileId, isNot(firstAuthor));
    });
  });
}
