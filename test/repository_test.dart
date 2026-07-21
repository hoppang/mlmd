import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/objectbox.g.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/repositories/diary_repository.dart';
import 'package:mlmd/repositories/activity_repository.dart';
import 'package:mlmd/repositories/record_draft_repository.dart';
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

  TestObjectBoxHelper(this.store) {
    diaryBox = Box<DiaryEntity>(store);
    activityBox = Box<ActivityEntity>(store);
    draftBox = Box<RecordDraftEntity>(store);
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

void main() {
  late TestObjectBoxHelper obxHelper;
  late DiaryRepository diaryRepo;
  late ActivityRepository activityRepo;
  late RecordDraftRepository draftRepo;

  setUp(() async {
    obxHelper = await TestObjectBoxHelper.createTemp();
    diaryRepo = DiaryRepositoryImpl(obxHelper);
    activityRepo = ActivityRepositoryImpl(obxHelper);
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
        '정확키워드',
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

        final byType = await diaryRepo.searchRecords('투약', EmbeddingService());
        final byDetail = await diaryRepo.searchRecords(
          '해열제',
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
}
