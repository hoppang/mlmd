import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/features/attachments/domain/event_attachment.dart';
import 'package:mlmd/features/sharing/application/family_sync_remote_applier.dart';
import 'package:mlmd/features/sharing/application/family_sync_payloads.dart';
import 'package:mlmd/features/sharing/domain/family_sync_models.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/ai_summary_entity.dart';
import 'package:mlmd/models/attachment_entity.dart';
import 'package:mlmd/models/author_profile_entity.dart';
import 'package:mlmd/models/care_task_entity.dart';
import 'package:mlmd/models/care_task_occurrence_entity.dart';
import 'package:mlmd/models/device_profile_entity.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/duplicate_review_edge_entity.dart';
import 'package:mlmd/models/logical_event_group_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/models/search_document_entity.dart';
import 'package:mlmd/models/shared_custom_event_definition_entity.dart';
import 'package:mlmd/objectbox.g.dart' hide SyncChange;
import 'package:mlmd/repositories/custom_event_repository.dart';
import 'package:mlmd/repositories/profile_repository.dart';

class _TestObjectBoxHelper implements ObjectBoxHelper {
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
}

void main() {
  late Directory tempDirectory;
  late Store store;
  late _TestObjectBoxHelper objectBox;
  late ProfileRepository profiles;
  late CustomEventRepository customEvents;
  late FamilySyncRemoteApplier applier;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'family-sync-applier',
    );
    store = await openStore(directory: tempDirectory.path);
    objectBox = _TestObjectBoxHelper(store);
    profiles = ProfileRepositoryImpl(objectBox);
    profiles.createAuthor(nickname: 'Parent', colorValue: 0xFF00796B);
    customEvents = CustomEventRepositoryImpl(
      objectBox,
      profiles,
      familySpaceId: 'family-1',
    );
    applier = FamilySyncRemoteApplier(objectBox, customEvents);
  });

  tearDown(() async {
    store.close();
    await tempDirectory.delete(recursive: true);
  });

  test('applies activity create, update, and delete with diary creation', () {
    final created = applier(
      SyncChange(
        changeId: 'change-1',
        familySpaceId: 'family-1',
        sourceDeviceProfileId: 'remote-device',
        sourceAuthorProfileId: 'remote-author',
        entityType: 'activity',
        entityId: 'record-1',
        entityRevision: 1,
        operation: SyncOperation.create,
        payload: {
          'recordId': 'record-1',
          'revision': 1,
          'type': 'meal',
          'time': '2026-07-29T10:15:00.000Z',
          'timePrecision': ActivityEntity.timePrecisionExact,
          'details': 'milk',
          'structuredDataJson': '{"amount":120}',
          'customEventTypeId': 'event-1',
          'customEventNameSnapshot': 'Bottle',
          'lastModified': '2026-07-29T10:15:00.000Z',
          'createdAt': '2026-07-29T10:15:00.000Z',
          'createdByAuthorProfileId': 'remote-author',
          'createdByDeviceProfileId': 'remote-device',
          'lastModifiedByAuthorProfileId': 'remote-author',
          'lastModifiedByDeviceProfileId': 'remote-device',
        },
        occurredAt: DateTime.utc(2026, 7, 29, 10, 15),
      ),
    );

    expect(created.disposition, RemoteApplyDisposition.applied);
    expect(objectBox.activityBox.getAll(), hasLength(1));
    expect(objectBox.diaryBox.getAll(), hasLength(1));
    final activity = objectBox.activityBox.getAll().single;
    expect(activity.diary.target, isNotNull);
    expect(activity.diary.target!.date.toUtc(), DateTime.utc(2026, 7, 29));
    expect(activity.createdByAuthorProfileId, 'remote-author');
    expect(activity.lastModifiedByDeviceProfileId, 'remote-device');

    final updated = applier(
      SyncChange(
        changeId: 'change-2',
        familySpaceId: 'family-1',
        sourceDeviceProfileId: 'remote-device',
        sourceAuthorProfileId: 'remote-author',
        entityType: 'activity',
        entityId: 'record-1',
        entityRevision: 2,
        operation: SyncOperation.update,
        payload: {
          'recordId': 'record-1',
          'revision': 2,
          'type': 'meal',
          'time': '2026-07-29T10:15:00.000Z',
          'timePrecision': ActivityEntity.timePrecisionExact,
          'details': 'milk and cereal',
          'structuredDataJson': '{"amount":180}',
          'customEventTypeId': 'event-1',
          'customEventNameSnapshot': 'Bottle',
          'lastModified': '2026-07-29T10:30:00.000Z',
          'createdAt': '2026-07-29T10:15:00.000Z',
          'createdByAuthorProfileId': 'remote-author',
          'createdByDeviceProfileId': 'remote-device',
          'lastModifiedByAuthorProfileId': 'remote-author',
          'lastModifiedByDeviceProfileId': 'remote-device',
        },
        occurredAt: DateTime.utc(2026, 7, 29, 10, 30),
      ),
    );

    expect(updated.disposition, RemoteApplyDisposition.applied);
    expect(objectBox.activityBox.getAll().single.details, 'milk and cereal');

    final deleted = applier(
      SyncChange(
        changeId: 'change-3',
        familySpaceId: 'family-1',
        sourceDeviceProfileId: 'remote-device',
        sourceAuthorProfileId: 'remote-author',
        entityType: 'activity',
        entityId: 'record-1',
        entityRevision: 3,
        operation: SyncOperation.delete,
        payload: const {},
        occurredAt: DateTime.utc(2026, 7, 29, 11, 0),
      ),
    );

    expect(deleted.disposition, RemoteApplyDisposition.applied);
    expect(objectBox.activityBox.getAll(), isEmpty);
  });

  test('returns ignored for unsupported entity types', () {
    final result = applier(
      SyncChange(
        changeId: 'change-x',
        familySpaceId: 'family-1',
        sourceDeviceProfileId: 'remote-device',
        sourceAuthorProfileId: 'remote-author',
        entityType: 'notSupported',
        entityId: 'id-1',
        entityRevision: 1,
        operation: SyncOperation.create,
        payload: const {},
        occurredAt: DateTime.utc(2026, 7, 29),
      ),
    );

    expect(result.disposition, RemoteApplyDisposition.ignored);
  });

  test('applies shared task, profile, attachment, and review metadata', () {
    final occurredAt = DateTime.utc(2026, 7, 29, 12);
    final revision = FamilySyncPayloads.revisionAt(occurredAt);
    final task = CareTaskEntity(
      taskId: 'task-1',
      title: 'Medicine',
      createdAt: DateTime.utc(2026, 7, 29, 8),
      createdByAuthorProfileId: 'remote-author',
      createdByDeviceProfileId: 'remote-device',
    );
    final occurrence = CareTaskOccurrenceEntity(
      occurrenceId: 'occurrence-1',
      taskId: task.taskId,
      scheduledAt: DateTime.utc(2026, 7, 29, 13),
    );
    final author = AuthorProfileEntity(
      authorProfileId: 'remote-author',
      nickname: 'Dad',
      colorValue: 0xFF123456,
      createdAt: DateTime.utc(2026, 7, 29, 7),
    );
    final attachment = EventAttachment(
      attachmentId: 'attachment-1',
      recordId: 'record-1',
      attachmentType: AttachmentType.general,
      fileName: 'note.txt',
      mimeType: 'text/plain',
      sourceKind: AttachmentSourceKind.filePicker,
      managedOriginalUri: 'file:///not-shared',
      createdAt: _attachmentCreatedAt,
    );
    final decision = DuplicateReviewEdgeEntity(
      pairKey: 'a|b',
      recordAId: 'a',
      recordBId: 'b',
      status: DuplicateReviewEdgeEntity.statusDistinctEvents,
      signatureA: 'a',
      signatureB: 'b',
      revisionA: 1,
      revisionB: 1,
      detectionReasonsJson: '[]',
      detectedAt: DateTime.utc(2026, 7, 29, 9),
      detectorVersion: 'test',
      resolvedAt: occurredAt,
    );

    final changes = [
      _change(
        entityType: FamilySyncPayloads.careTask,
        entityId: task.taskId,
        revision: revision,
        payload: FamilySyncPayloads.forTask(task),
      ),
      _change(
        entityType: FamilySyncPayloads.careTaskOccurrence,
        entityId: occurrence.occurrenceId,
        revision: revision,
        payload: FamilySyncPayloads.forOccurrence(occurrence),
      ),
      _change(
        entityType: FamilySyncPayloads.authorProfile,
        entityId: author.authorProfileId,
        revision: revision,
        payload: FamilySyncPayloads.forAuthor(author),
      ),
      _change(
        entityType: FamilySyncPayloads.attachmentMetadata,
        entityId: attachment.attachmentId,
        revision: revision,
        payload: FamilySyncPayloads.forAttachment(attachment),
      ),
      _change(
        entityType: FamilySyncPayloads.duplicateDecision,
        entityId: decision.pairKey,
        revision: revision,
        payload: FamilySyncPayloads.forDuplicateDecision(decision),
      ),
      _change(
        entityType: FamilySyncPayloads.customEventDefinition,
        entityId: 'custom-1',
        revision: 1,
        payload: {
          'customEventTypeId': 'custom-1',
          'familySpaceId': 'family-1',
          'name': 'Walk',
          'revision': 1,
          'createdByAuthorProfileId': 'remote-author',
          'createdByDeviceProfileId': 'remote-device',
          'lastModifiedByAuthorProfileId': 'remote-author',
          'lastModifiedByDeviceProfileId': 'remote-device',
          'createdAt': occurredAt.toIso8601String(),
          'updatedAt': occurredAt.toIso8601String(),
        },
      ),
    ];

    expect(
      changes.map(applier.call).map((result) => result.disposition),
      everyElement(RemoteApplyDisposition.applied),
    );
    expect(objectBox.careTaskBox.getAll(), hasLength(1));
    expect(objectBox.careTaskOccurrenceBox.getAll(), hasLength(1));
    expect(
      objectBox.authorProfileBox
          .getAll()
          .where((item) => item.authorProfileId == 'remote-author'),
      hasLength(1),
    );
    final storedAttachment = Box<AttachmentEntity>(store).getAll().single;
    expect(storedAttachment.toDomain()!.missingReason, 'binary_not_shared');
    expect(objectBox.duplicateReviewEdgeBox.getAll(), hasLength(1));
    expect(
      Box<SharedCustomEventDefinitionEntity>(store).getAll(),
      hasLength(1),
    );
  });
}

final _attachmentCreatedAt = DateTime.utc(2026, 7, 29, 10);

SyncChange _change({
  required String entityType,
  required String entityId,
  required int revision,
  required Map<String, Object?> payload,
}) {
  return SyncChange(
    changeId: 'change-$entityType',
    familySpaceId: 'family-1',
    sourceDeviceProfileId: 'remote-device',
    sourceAuthorProfileId: 'remote-author',
    entityType: entityType,
    entityId: entityId,
    entityRevision: revision,
    operation: SyncOperation.create,
    payload: payload,
    occurredAt: DateTime.utc(2026, 7, 29, 12),
  );
}
