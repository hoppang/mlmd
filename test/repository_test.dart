import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/objectbox.g.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/models/author_profile_entity.dart';
import 'package:mlmd/models/device_profile_entity.dart';
import 'package:mlmd/models/search_document_entity.dart';
import 'package:mlmd/models/ai_summary_entity.dart';
import 'package:mlmd/models/duplicate_review_edge_entity.dart';
import 'package:mlmd/models/logical_event_group_entity.dart';
import 'package:mlmd/models/shared_custom_event_definition_entity.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/features/search/domain/hybrid_search_query.dart';
import 'package:mlmd/features/events/application/custom_event_notifier.dart';
import 'package:mlmd/features/events/domain/sleep_record.dart';
import 'package:mlmd/repositories/diary_repository.dart';
import 'package:mlmd/repositories/activity_repository.dart';
import 'package:mlmd/repositories/record_draft_repository.dart';
import 'package:mlmd/repositories/profile_repository.dart';
import 'package:mlmd/repositories/ai_summary_repository.dart';
import 'package:mlmd/repositories/duplicate_review_repository.dart';
import 'package:mlmd/repositories/custom_event_repository.dart';
import 'package:mlmd/services/embedding_service.dart';
import 'package:mlmd/features/summaries/domain/summary_source_snapshot.dart';

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
  @override
  late final Box<AiSummaryEntity> aiSummaryBox;
  @override
  late final Box<DuplicateReviewEdgeEntity> duplicateReviewEdgeBox;
  @override
  late final Box<LogicalEventGroupEntity> logicalEventGroupBox;

  TestObjectBoxHelper(this.store) {
    diaryBox = Box<DiaryEntity>(store);
    activityBox = Box<ActivityEntity>(store);
    draftBox = Box<RecordDraftEntity>(store);
    authorProfileBox = Box<AuthorProfileEntity>(store);
    deviceProfileBox = Box<DeviceProfileEntity>(store);
    searchDocumentBox = Box<SearchDocumentEntity>(store);
    aiSummaryBox = Box<AiSummaryEntity>(store);
    duplicateReviewEdgeBox = Box<DuplicateReviewEdgeEntity>(store);
    logicalEventGroupBox = Box<LogicalEventGroupEntity>(store);
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
  late AiSummaryRepository aiSummaryRepo;
  late DuplicateReviewRepository duplicateReviewRepo;
  late CustomEventRepository customEventRepo;

  setUp(() async {
    obxHelper = await TestObjectBoxHelper.createTemp();
    profileRepo = ProfileRepositoryImpl(obxHelper);
    profileRepo.createAuthor(nickname: '테스트 작성자', colorValue: 0xFF00796B);
    diaryRepo = DiaryRepositoryImpl(obxHelper, profileRepo);
    activityRepo = ActivityRepositoryImpl(obxHelper, profileRepo);
    draftRepo = RecordDraftRepositoryImpl(obxHelper);
    aiSummaryRepo = AiSummaryRepositoryImpl(obxHelper);
    duplicateReviewRepo = DuplicateReviewRepositoryImpl(obxHelper, profileRepo);
    customEventRepo = CustomEventRepositoryImpl(
      obxHelper,
      profileRepo,
      familySpaceId: 'family-test',
    );
  });

  tearDown(() async {
    await obxHelper.close();
  });

  group('Diary & Activity Repository CRUD + Trigger Tests', () {
    test('activity UUID survives editing and core edits raise revision', () {
      final time = DateTime(2026, 7, 24, 10);
      final diary = DiaryEntity(
        date: time,
        title: '',
        content: '',
        lastModified: time,
      );
      diaryRepo.saveDiaryWithActivities(diary, [
        ActivityEntity(
          type: '수유',
          time: time,
          details: '180mL',
          lastModified: time,
        ),
      ]);
      final original = activityRepo.getActivities().single;

      diaryRepo.saveDiaryWithActivities(diary, [
        ActivityEntity(
          recordId: original.recordId,
          revision: original.revision,
          type: '수유',
          time: time,
          details: '200mL',
          lastModified: time,
        ),
      ]);
      final edited = activityRepo.getActivities().single;

      expect(edited.recordId, original.recordId);
      expect(edited.revision, original.revision + 1);
    });

    test(
      'duplicate decisions preserve originals and reopen after revision',
      () {
        final time = DateTime(2026, 7, 24, 11);
        for (final device in ['device-a', 'device-b']) {
          final diary = DiaryEntity(
            date: time,
            title: '',
            content: '',
            lastModified: time,
          );
          diaryRepo.saveDiaryWithActivities(diary, [
            ActivityEntity(
              type: '수유',
              time: time,
              details: '180mL',
              createdByDeviceProfileId: device,
              lastModified: time,
            ),
          ]);
        }

        var items = duplicateReviewRepo.synchronize(diaryRepo.getDiaries());
        expect(items, hasLength(1));
        final pairKey = items.single.edge.pairKey;
        final representative = items.single.firstActivity.recordId!;

        duplicateReviewRepo.defer(pairKey);
        items = duplicateReviewRepo.synchronize(diaryRepo.getDiaries());
        expect(items, hasLength(1));
        expect(items.single.edge.deferredAt, isNotNull);

        duplicateReviewRepo.useRepresentative(pairKey, representative);
        expect(obxHelper.activityBox.count(), 2);
        expect(obxHelper.logicalEventGroupBox.count(), 1);
        expect(
          duplicateReviewRepo.synchronize(diaryRepo.getDiaries()),
          isEmpty,
        );

        duplicateReviewRepo.resetDecision(pairKey);
        duplicateReviewRepo.markDistinct(pairKey);
        expect(obxHelper.logicalEventGroupBox.count(), 0);
        expect(
          duplicateReviewRepo.synchronize(diaryRepo.getDiaries()),
          isEmpty,
        );

        final first = activityRepo.getActivities().first;
        activityRepo.saveActivity(
          ActivityEntity(
            id: first.id,
            recordId: first.recordId,
            revision: first.revision,
            type: first.type,
            time: first.time,
            details: '200mL',
            lastModified: first.lastModified,
          ),
          first.diary.targetId,
        );
        items = duplicateReviewRepo.synchronize(diaryRepo.getDiaries());
        expect(items, hasLength(1));
        expect(
          items.single.edge.status,
          DuplicateReviewEdgeEntity.statusPending,
        );
        expect(obxHelper.activityBox.count(), 2);
      },
    );

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

  group('UX-015 derived AI summaries', () {
    test('stores generated text, evidence, edits, and hidden state', () {
      final occurredAt = DateTime(2026, 7, 20, 9);
      final diary = DiaryEntity(
        date: occurredAt,
        title: '아침',
        content: '공원에 다녀왔다',
        lastModified: occurredAt,
      );
      diaryRepo.saveDiaryWithActivities(diary, [
        ActivityEntity(
          type: '수유',
          time: occurredAt.add(const Duration(minutes: 30)),
          details: '120mL',
          lastModified: occurredAt,
        ),
      ]);
      final snapshot = const SummarySourceSnapshotBuilder().build(
        diaryRepo.getDiaries(),
        periodType: SummaryPeriodType.daily,
        start: DateTime(2026, 7, 20),
        endExclusive: DateTime(2026, 7, 21),
      );

      final saved = aiSummaryRepo.saveGenerated(
        snapshot,
        '공원에 다녀오고 수유를 기록했다.',
        automatic: false,
        modelVersion: 'test-v1',
      );

      expect(saved.generatedText, contains('공원'));
      expect(aiSummaryRepo.evidenceFor(saved), hasLength(2));
      expect(
        aiSummaryRepo.freshness(saved, snapshot),
        AiSummaryFreshness.fresh,
      );

      final edited = aiSummaryRepo.edit(saved.id, '보호자가 고친 문장');
      expect(edited.generatedText, contains('공원'));
      expect(edited.displayText, '보호자가 고친 문장');
      expect(edited.userEdited, isTrue);

      final hidden = aiSummaryRepo.setHidden(saved.id, true);
      expect(hidden.hidden, isTrue);
      expect(aiSummaryRepo.setHidden(saved.id, false).hidden, isFalse);
    });

    test('distinguishes appended evidence from changed source text', () {
      final occurredAt = DateTime(2026, 7, 20, 9);
      final diary = DiaryEntity(
        date: occurredAt,
        title: '기록',
        content: '처음 원문',
        lastModified: occurredAt,
      );
      diaryRepo.saveDiary(diary);
      final builder = const SummarySourceSnapshotBuilder();
      final before = builder.build(
        diaryRepo.getDiaries(),
        periodType: SummaryPeriodType.daily,
        start: DateTime(2026, 7, 20),
        endExclusive: DateTime(2026, 7, 21),
      );
      final saved = aiSummaryRepo.saveGenerated(
        before,
        '처음 정리',
        automatic: false,
        modelVersion: 'test-v1',
      );

      diaryRepo.addActivityRecord(
        ActivityEntity(
          type: '수면',
          time: occurredAt.add(const Duration(hours: 1)),
          details: '낮잠',
          lastModified: occurredAt,
        ),
      );
      final withNewRecord = builder.build(
        diaryRepo.getDiaries(),
        periodType: SummaryPeriodType.daily,
        start: DateTime(2026, 7, 20),
        endExclusive: DateTime(2026, 7, 21),
      );
      expect(
        aiSummaryRepo.freshness(saved, withNewRecord),
        AiSummaryFreshness.newRecords,
      );

      diary.content = '수정한 원문';
      diaryRepo.saveDiary(diary);
      final changed = builder.build(
        diaryRepo.getDiaries(),
        periodType: SummaryPeriodType.daily,
        start: DateTime(2026, 7, 20),
        endExclusive: DateTime(2026, 7, 21),
      );
      expect(
        aiSummaryRepo.freshness(saved, changed),
        AiSummaryFreshness.sourceChanged,
      );
    });
  });

  group('UX-018 shared custom events', () {
    test('same names remain separate definitions with stable UUIDs', () {
      final first = customEventRepo.create('산책 준비');
      final second = customEventRepo.create('  산책   준비  ');

      expect(first.customEventTypeId, isNot(second.customEventTypeId));
      expect(first.familySpaceId, 'family-test');
      expect(second.name, '산책 준비');
      expect(
        first.createdByDeviceProfileId,
        profileRepo.currentDevice.deviceProfileId,
      );
      expect(customEventRepo.getDefinitions(), hasLength(2));
    });

    test('rename and archive preserve the record name snapshot', () async {
      final definition = customEventRepo.create('산책 준비');
      final occurredAt = DateTime(2026, 7, 24, 17, 30);
      diaryRepo.addActivityRecord(
        ActivityEntity(
          type: definition.name,
          time: occurredAt,
          details: '모자 챙김',
          customEventTypeId: definition.customEventTypeId,
          customEventNameSnapshot: definition.name,
          lastModified: occurredAt,
        ),
      );

      customEventRepo.rename(definition.customEventTypeId, '외출 준비');
      customEventRepo.setArchived(definition.customEventTypeId, archived: true);

      expect(customEventRepo.getDefinitions(), isEmpty);
      expect(
        customEventRepo.getDefinitions(includeArchived: true).single.name,
        '외출 준비',
      );
      final record = activityRepo.getActivities().single;
      expect(record.customEventTypeId, definition.customEventTypeId);
      expect(record.customEventNameSnapshot, '산책 준비');
      expect(record.type, '산책 준비');

      final byName = await diaryRepo.searchRecords(
        const HybridSearchQuery(text: '산책 준비'),
        EmbeddingService(),
      );
      final byMemo = await diaryRepo.searchRecords(
        const HybridSearchQuery(text: '모자'),
        EmbeddingService(),
      );
      expect(byName.single.activity?.id, record.id);
      expect(byMemo.single.activity?.id, record.id);
    });

    test('shared merge uses UUID and revision instead of the name', () {
      final now = DateTime.utc(2026, 7, 24);
      SharedCustomEventDefinitionEntity incoming({
        required String id,
        required String name,
        required int revision,
        required DateTime updatedAt,
      }) => SharedCustomEventDefinitionEntity(
        customEventTypeId: id,
        familySpaceId: 'family-test',
        name: name,
        revision: revision,
        createdByAuthorProfileId: 'remote-author',
        createdByDeviceProfileId: 'remote-device',
        lastModifiedByAuthorProfileId: 'remote-author',
        lastModifiedByDeviceProfileId: 'remote-device',
        createdAt: now,
        updatedAt: updatedAt,
      );

      customEventRepo.applySharedDefinition(
        incoming(
          id: '00000000-0000-4000-8000-000000000001',
          name: '비타민',
          revision: 2,
          updatedAt: now.add(const Duration(minutes: 2)),
        ),
      );
      customEventRepo.applySharedDefinition(
        incoming(
          id: '00000000-0000-4000-8000-000000000002',
          name: '비타민',
          revision: 1,
          updatedAt: now,
        ),
      );
      customEventRepo.applySharedDefinition(
        incoming(
          id: '00000000-0000-4000-8000-000000000001',
          name: '오래된 이름',
          revision: 1,
          updatedAt: now.add(const Duration(days: 1)),
        ),
      );

      final definitions = customEventRepo.getDefinitions();
      expect(definitions, hasLength(2));
      expect(
        definitions
            .firstWhere(
              (item) =>
                  item.customEventTypeId ==
                  '00000000-0000-4000-8000-000000000001',
            )
            .name,
        '비타민',
      );
    });

    test('quick-record pins are device-local and archive removes them', () {
      final definition = customEventRepo.create('등원 준비');
      customEventRepo.setPinned(definition.customEventTypeId, pinned: true);
      expect(customEventRepo.getPinnedTypeIds(), [
        definition.customEventTypeId,
      ]);

      customEventRepo.setArchived(definition.customEventTypeId, archived: true);
      expect(customEventRepo.getPinnedTypeIds(), isEmpty);
      expect(
        customEventRepo.getDefinitions(includeArchived: true).single.isArchived,
        isTrue,
      );
    });

    test('catalog notifier refreshes after create and pin actions', () {
      final container = ProviderContainer(
        overrides: [
          objectBoxProvider.overrideWithValue(obxHelper),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          customEventRepositoryProvider.overrideWithValue(customEventRepo),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(customEventCatalogProvider).definitions, isEmpty);
      final notifier = container.read(customEventCatalogProvider.notifier);
      final created = notifier.create('낮 산책');
      expect(
        container
            .read(customEventCatalogProvider)
            .definitions
            .single
            .customEventTypeId,
        created.customEventTypeId,
      );

      notifier.setPinned(created.customEventTypeId, pinned: true);
      expect(
        container
            .read(customEventCatalogProvider)
            .pinnedDefinitions
            .single
            .name,
        '낮 산책',
      );
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
          structuredDataJson:
              '{"version":1,"kind":"feeding","method":"bottle","bottleContents":"formula","amountExpression":{"kind":"exact","exactValue":120,"unit":"ml"}}',
          lastModified: DateTime.utc(2026),
        ),
      );

      final activity = activityRepo.getActivities().single;
      expect(activity.createdAt, isNotNull);
      expect(activity.createdByAuthorProfileId, source.authorProfileId);
      expect(activity.createdByDeviceProfileId, source.deviceProfileId);
      expect(activity.lastModifiedByAuthorProfileId, source.authorProfileId);
      expect(activity.lastModifiedByDeviceProfileId, source.deviceProfileId);
      expect(activity.structuredDataJson, contains('"kind":"feeding"'));
    });

    test('sleep completion preserves identity and moves to the end date', () {
      final firstSource = profileRepo.requireCurrentSource();
      final startedAt = DateTime(2026, 7, 24, 23);
      final endedAt = DateTime(2026, 7, 25, 1);
      diaryRepo.addActivityRecord(
        ActivityEntity(
          type: '수면',
          time: startedAt,
          details: '',
          structuredDataJson: SleepRecord(
            status: SleepRecordStatus.active,
            kind: SleepRecordKind.unspecified,
            source: SleepRecordSource.suggested,
            startedAt: startedAt,
          ).encode(),
          lastModified: startedAt,
        ),
      );
      final started = activityRepo.getActivities().single;
      final recordId = started.recordId;

      final secondAuthor = profileRepo.createAuthor(
        nickname: '종료한 작성자',
        colorValue: 0xFF6A1B9A,
      );
      started
        ..time = endedAt
        ..details = '2시간 · 밤잠'
        ..structuredDataJson = SleepRecord(
          status: SleepRecordStatus.completed,
          kind: SleepRecordKind.night,
          source: SleepRecordSource.suggested,
          startedAt: startedAt,
          endedAt: endedAt,
          endedByAuthorProfileId: secondAuthor.authorProfileId,
          endedByDeviceProfileId: firstSource.deviceProfileId,
        ).encode();
      diaryRepo.updateActivityRecord(started);

      final completed = activityRepo.getActivities().single;
      expect(completed.recordId, recordId);
      expect(completed.revision, 2);
      expect(completed.createdByAuthorProfileId, firstSource.authorProfileId);
      expect(
        completed.lastModifiedByAuthorProfileId,
        secondAuthor.authorProfileId,
      );
      final endDay = diaryRepo.getDiaries().firstWhere(
        (diary) =>
            diary.date.year == endedAt.year &&
            diary.date.month == endedAt.month &&
            diary.date.day == endedAt.day,
      );
      expect(endDay.activities.single.recordId, recordId);
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
