import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/features/tasks/domain/care_task_model.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/ai_summary_entity.dart';
import 'package:mlmd/models/author_profile_entity.dart';
import 'package:mlmd/models/care_task_entity.dart';
import 'package:mlmd/models/care_task_occurrence_entity.dart';
import 'package:mlmd/models/device_profile_entity.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/duplicate_review_edge_entity.dart';
import 'package:mlmd/models/logical_event_group_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/models/search_document_entity.dart';
import 'package:mlmd/objectbox.g.dart';
import 'package:mlmd/repositories/profile_repository.dart';
import 'package:mlmd/repositories/task_repository.dart';

class _TestObjectBoxHelper implements ObjectBoxHelper {
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
  late final Box<CareTaskEntity> careTaskBox;
  @override
  late final Box<CareTaskOccurrenceEntity> careTaskOccurrenceBox;

  _TestObjectBoxHelper(this.store) {
    diaryBox = Box<DiaryEntity>(store);
    activityBox = Box<ActivityEntity>(store);
    draftBox = Box<RecordDraftEntity>(store);
    authorProfileBox = Box<AuthorProfileEntity>(store);
    deviceProfileBox = Box<DeviceProfileEntity>(store);
    searchDocumentBox = Box<SearchDocumentEntity>(store);
    aiSummaryBox = Box<AiSummaryEntity>(store);
    duplicateReviewEdgeBox = Box<DuplicateReviewEdgeEntity>(store);
    logicalEventGroupBox = Box<LogicalEventGroupEntity>(store);
    careTaskBox = Box<CareTaskEntity>(store);
    careTaskOccurrenceBox = Box<CareTaskOccurrenceEntity>(store);
  }

  static Future<_TestObjectBoxHelper> createTemp() async {
    final tempDir = await Directory.systemTemp.createTemp('task_repo_test');
    final store = await openStore(directory: tempDir.path);
    return _TestObjectBoxHelper(store);
  }

  Future<void> close() async {
    store.close();
  }
}

void main() {
  late _TestObjectBoxHelper objectBox;
  late ProfileRepository profileRepo;
  late TaskRepository taskRepo;

  setUp(() async {
    objectBox = await _TestObjectBoxHelper.createTemp();
    profileRepo = ProfileRepositoryImpl(objectBox);
    profileRepo.createAuthor(nickname: '엄마', colorValue: 0xFFFF5722);
    taskRepo = TaskRepositoryImpl(objectBox, profileRepo);
  });

  tearDown(() async {
    await objectBox.close();
  });

  test('createTask - creates CareTask and initial occurrence', () {
    final now = DateTime.now();
    final task = taskRepo.createTask(
      title: '오후 6:30 해열제 먹이기',
      linkedCategory: 'medication',
      notificationMode: TaskNotificationMode.quietToAssignee,
      firstScheduledAt: now,
    );

    expect(task.title, '오후 6:30 해열제 먹이기');
    expect(task.linkedCategory, 'medication');
    expect(task.notificationMode, TaskNotificationMode.quietToAssignee);

    final occurrences = taskRepo.getOccurrencesForDate(now);
    expect(occurrences.length, 1);
    expect(occurrences.first.taskId, task.taskId);
    expect(occurrences.first.status, TaskStatus.scheduled);
  });

  test('completeOccurrence - creates linked ActivityEntity when linkedCategory is present', () {
    final scheduledAt = DateTime.now();
    final task = taskRepo.createTask(
      title: '체온 측정하기',
      linkedCategory: 'temperature',
      firstScheduledAt: scheduledAt,
    );

    final initialOccurrences = taskRepo.getOccurrencesForDate(scheduledAt);
    final occurrenceId = initialOccurrences.first.occurrenceId;

    final completedOccurrence = taskRepo.completeOccurrence(
      occurrenceId: occurrenceId,
    );

    expect(completedOccurrence.isCompleted, isTrue);
    expect(completedOccurrence.linkedRecordId, isNotNull);

    // Verify ActivityEntity created in ObjectBox
    final activities = objectBox.activityBox.getAll();
    expect(activities.length, 1);
    expect(activities.first.recordId, completedOccurrence.linkedRecordId);
    expect(activities.first.type, 'temperature');
    expect(activities.first.details, '체온 측정하기');
  });

  test('undoOccurrenceCompletion - removes linked ActivityEntity and resets status', () {
    final scheduledAt = DateTime.now();
    final task = taskRepo.createTask(
      title: '해열제 투약',
      linkedCategory: 'medication',
      firstScheduledAt: scheduledAt,
    );

    final occurrenceId = taskRepo.getOccurrencesForDate(scheduledAt).first.occurrenceId;
    final completed = taskRepo.completeOccurrence(occurrenceId: occurrenceId);

    expect(objectBox.activityBox.getAll().length, 1);

    final undone = taskRepo.undoOccurrenceCompletion(occurrenceId);
    expect(undone.isCompleted, isFalse);
    expect(undone.linkedRecordId, isNull);
    expect(objectBox.activityBox.getAll().length, 0);
  });

  test('skipOccurrence - marks status as skipped and creates no event', () {
    final scheduledAt = DateTime.now();
    final task = taskRepo.createTask(
      title: '목욕하기',
      linkedCategory: 'bath',
      firstScheduledAt: scheduledAt,
    );

    final occurrenceId = taskRepo.getOccurrencesForDate(scheduledAt).first.occurrenceId;
    final skipped = taskRepo.skipOccurrence(occurrenceId);

    expect(skipped.isSkipped, isTrue);
    expect(objectBox.activityBox.getAll().length, 0);
  });
}
