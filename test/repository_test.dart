import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/objectbox.g.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/repositories/diary_repository.dart';
import 'package:mlmd/repositories/activity_repository.dart';

// ObjectBoxHelper의 테스트용 구현체 (임시 디렉터리에 데이터베이스 가동)
class TestObjectBoxHelper implements ObjectBoxHelper {
  @override
  late final Store store;
  @override
  late final Box<DiaryEntity> diaryBox;
  @override
  late final Box<ActivityEntity> activityBox;

  TestObjectBoxHelper(this.store) {
    diaryBox = Box<DiaryEntity>(store);
    activityBox = Box<ActivityEntity>(store);
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

  setUp(() async {
    obxHelper = await TestObjectBoxHelper.createTemp();
    diaryRepo = DiaryRepositoryImpl(obxHelper);
    activityRepo = ActivityRepositoryImpl(obxHelper);
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
      expect(DateTime.now().difference(saved.lastModified).inSeconds, lessThan(5));
    });

    test('Saving an Activity should link to Diary and update both lastModified', () async {
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
      expect(savedActivity.lastModified.millisecondsSinceEpoch, greaterThan(0));
      expect(savedActivity.diary.targetId, equals(diaryId));

      // 4. 부모 일기의 타임스탬프가 연쇄 갱신되었는지 검증
      final savedDiaryAfter = diaryRepo.getDiary(diaryId)!;
      expect(savedDiaryAfter.lastModified.isAfter(initialDiaryTime), isTrue);
    });

    test('Deleting an Activity should update parent Diary lastModified', () async {
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
      expect(savedDiaryAfter.lastModified.isAfter(diaryTimeBeforeDelete), isTrue);
      
      // 5. 활동이 더이상 조회되지 않는지 검증
      expect(activityRepo.getActivity(activityId), isNull);
    });
  });
}
