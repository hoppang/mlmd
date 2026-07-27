import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/features/events/domain/memo_record.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/ai_summary_entity.dart';
import 'package:mlmd/models/author_profile_entity.dart';
import 'package:mlmd/models/device_profile_entity.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/duplicate_review_edge_entity.dart';
import 'package:mlmd/models/logical_event_group_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/models/search_document_entity.dart';
import 'package:mlmd/models/shared_custom_event_definition_entity.dart';
import 'package:mlmd/models/care_task_entity.dart';
import 'package:mlmd/models/care_task_occurrence_entity.dart';
import 'package:mlmd/objectbox.g.dart';
import 'package:mlmd/repositories/diary_repository.dart';
import 'package:mlmd/repositories/profile_repository.dart';

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
  @override
  late final Box<SharedCustomEventDefinitionEntity>
      sharedCustomEventDefinitionBox;
  @override
  late final Box<CareTaskEntity> careTaskBox;
  @override
  late final Box<CareTaskOccurrenceEntity> careTaskOccurrenceBox;

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
    sharedCustomEventDefinitionBox =
        Box<SharedCustomEventDefinitionEntity>(store);
    careTaskBox = Box<CareTaskEntity>(store);
    careTaskOccurrenceBox = Box<CareTaskOccurrenceEntity>(store);
  }
}

void main() {
  late Directory tempDir;
  late Store store;
  late TestObjectBoxHelper obxHelper;
  late ProfileRepository profileRepo;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('memo_migration_test_');
    store = await openStore(directory: tempDir.path);
    obxHelper = TestObjectBoxHelper(store);
    profileRepo = ProfileRepositoryImpl(obxHelper);
    profileRepo.createAuthor(nickname: '테스트 작성자', colorValue: 0xFF4285F4);
  });

  tearDown(() {
    store.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('migrates legacy diary to memo event preserving legacyTitle and content', () {
    final legacyDiary = DiaryEntity(
      date: DateTime(2026, 7, 20, 14, 0),
      title: '레거시 일기 제목',
      content: '레거시 일기 본문 내용입니다.',
      lastModified: DateTime(2026, 7, 20, 14, 0),
    );
    obxHelper.diaryBox.put(legacyDiary);

    final diaryRepo = DiaryRepositoryImpl(obxHelper, profileRepo);

    final activities = obxHelper.activityBox.getAll();
    expect(activities.length, equals(1));

    final activity = activities.first;
    expect(activity.type, equals('메모'));
    expect(activity.details, equals('레거시 일기 본문 내용입니다.'));

    final memoRecord = MemoRecord.decode(activity.structuredDataJson ?? '');
    expect(memoRecord, isNotNull);
    expect(memoRecord!.content, equals('레거시 일기 본문 내용입니다.'));
    expect(memoRecord.legacyTitle, equals('레거시 일기 제목'));
  });

  test('supports adding multiple memo activities to the same day', () {
    final diaryRepo = DiaryRepositoryImpl(obxHelper, profileRepo);
    final now = DateTime(2026, 7, 28, 10, 0);

    final memo1 = MemoRecord(occurredAt: now, content: '첫 번째 메모');
    diaryRepo.addActivityRecord(
      ActivityEntity(
        type: '메모',
        time: now,
        details: memo1.content,
        structuredDataJson: memo1.encode(),
        lastModified: now,
      ),
    );

    final now2 = DateTime(2026, 7, 28, 15, 30);
    final memo2 = MemoRecord(occurredAt: now2, content: '두 번째 메모');
    diaryRepo.addActivityRecord(
      ActivityEntity(
        type: '메모',
        time: now2,
        details: memo2.content,
        structuredDataJson: memo2.encode(),
        lastModified: now2,
      ),
    );

    final activities = obxHelper.activityBox.getAll();
    expect(activities.length, equals(2));
    expect(activities[0].details, equals('첫 번째 메모'));
    expect(activities[1].details, equals('두 번째 메모'));
  });
}
