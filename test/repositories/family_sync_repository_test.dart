import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/features/sharing/application/family_sync_transport.dart';
import 'package:mlmd/features/sharing/application/family_sync_payloads.dart';
import 'package:mlmd/features/sharing/domain/family_sync_models.dart';
import 'package:mlmd/features/attachments/application/attachment_service.dart';
import 'package:mlmd/features/attachments/domain/event_attachment.dart';
import 'package:mlmd/features/children/application/child_profile_repository.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/ai_summary_entity.dart';
import 'package:mlmd/models/author_profile_entity.dart';
import 'package:mlmd/models/care_task_entity.dart';
import 'package:mlmd/models/care_task_occurrence_entity.dart';
import 'package:mlmd/models/device_profile_entity.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/duplicate_review_edge_entity.dart';
import 'package:mlmd/models/family_sync_entity.dart';
import 'package:mlmd/models/logical_event_group_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/models/search_document_entity.dart';
import 'package:mlmd/models/shared_custom_event_definition_entity.dart';
import 'package:mlmd/objectbox.g.dart' hide SyncChange;
import 'package:mlmd/repositories/family_sync_repository.dart';
import 'package:mlmd/repositories/diary_repository.dart';
import 'package:mlmd/repositories/duplicate_review_repository.dart';
import 'package:mlmd/repositories/profile_repository.dart';
import 'package:mlmd/repositories/task_repository.dart';

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

class _FakeTransport implements FamilySyncTransport {
  _FakeTransport(this.exchangeResult);

  final SyncExchange exchangeResult;
  String? receivedCursor;
  List<SyncChange> receivedOutgoing = const [];

  @override
  Future<SyncExchange> exchange({
    required String familySpaceId,
    required String deviceProfileId,
    required String? afterCursor,
    required List<SyncChange> outgoingChanges,
  }) async {
    receivedCursor = afterCursor;
    receivedOutgoing = outgoingChanges;
    return exchangeResult;
  }
}

class _FakeSnapshotTransport
    implements FamilySyncTransport, FamilySyncSnapshotTransport {
  _FakeSnapshotTransport({
    required this.snapshot,
    required this.exchangeResult,
  });

  final FamilySyncStateSnapshot? snapshot;
  final SyncExchange exchangeResult;
  int downloadCount = 0;
  String? receivedCursor;

  @override
  Future<FamilySyncStateSnapshot?> downloadSnapshot({
    required String familySpaceId,
    required String deviceProfileId,
  }) async {
    downloadCount++;
    return snapshot;
  }

  @override
  Future<SyncExchange> exchange({
    required String familySpaceId,
    required String deviceProfileId,
    required String? afterCursor,
    required List<SyncChange> outgoingChanges,
  }) async {
    receivedCursor = afterCursor;
    return exchangeResult;
  }

  @override
  Future<FamilySyncStateSnapshot> uploadSnapshot({
    required String familySpaceId,
    required String deviceProfileId,
    required int baseServerSequence,
    required List<SyncChange> changes,
  }) => throw UnimplementedError();
}

void main() {
  late Directory tempDirectory;
  late Store store;
  late _TestObjectBoxHelper objectBox;
  late ProfileRepository profiles;
  late FamilySyncRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('family-sync-test');
    store = await openStore(directory: tempDirectory.path);
    objectBox = _TestObjectBoxHelper(store);
    profiles = ProfileRepositoryImpl(objectBox);
    profiles.createAuthor(nickname: '엄마', colorValue: 0xFF00796B);
    repository = FamilySyncRepositoryImpl(objectBox, profiles);
    repository.connect(familySpaceId: 'family-1', displayName: '튼튼이 기록');
  });

  tearDown(() async {
    store.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'failed delivery keeps local changes queued for a later retry',
    () async {
      repository.enqueue(
        entityType: 'memo',
        entityId: 'memo-1',
        entityRevision: 1,
        operation: SyncOperation.create,
        payload: const {'text': '첫 기록'},
      );

      await expectLater(
        repository.synchronize(
          const UnconfiguredFamilySyncTransport(),
          applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
        ),
        throwsA(isA<FamilySyncUnavailable>()),
      );

      final snapshot = repository.getSnapshot();
      expect(snapshot.pendingChangeCount, 2);
      expect(snapshot.lastErrorCode, 'transport_not_configured');
    },
  );

  test(
    'initial sync restores an authenticated snapshot before incremental exchange',
    () async {
      final restoredChange = SyncChange(
        changeId: 'snapshot-change-1',
        familySpaceId: 'family-1',
        sourceDeviceProfileId: 'remote-device',
        sourceAuthorProfileId: 'remote-author',
        entityType: FamilySyncPayloads.activity,
        entityId: 'snapshot-activity',
        entityRevision: 1,
        operation: SyncOperation.create,
        payload: const {'recordId': 'snapshot-activity'},
        occurredAt: DateTime.utc(2026, 8, 15),
      );
      final transport = _FakeSnapshotTransport(
        snapshot: FamilySyncStateSnapshot(
          snapshotId: 'snapshot-1',
          baseServerSequence: 42,
          sourceDeviceProfileId: 'remote-device',
          changes: [restoredChange],
        ),
        exchangeResult: const SyncExchange(
          acknowledgedChangeIds: {},
          incomingChanges: [],
          nextCursor: '43',
        ),
      );
      final applied = <SyncChange>[];

      final first = await repository.synchronize(
        transport,
        applyRemoteChange: (change) {
          applied.add(change);
          return const RemoteApplyResult.applied();
        },
      );

      expect(applied, [restoredChange]);
      expect(first.appliedCount, 1);
      expect(transport.receivedCursor, '42');
      expect(transport.downloadCount, 1);

      await repository.synchronize(
        transport,
        applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
      );
      expect(transport.downloadCount, 1);
      expect(transport.receivedCursor, '43');
    },
  );

  test('first sync backfills existing shareable data exactly once', () async {
    final author = profiles.currentAuthor!;
    final device = profiles.currentDevice;
    final createdAt = DateTime.utc(2026, 8, 15, 1);
    objectBox.activityBox.put(
      ActivityEntity(
        recordId: 'existing-activity',
        revision: 2,
        type: '메모',
        time: createdAt,
        details: '연결 전 기록',
        lastModified: createdAt,
        createdAt: createdAt,
        createdByAuthorProfileId: author.authorProfileId,
        createdByDeviceProfileId: device.deviceProfileId,
        lastModifiedByAuthorProfileId: author.authorProfileId,
        lastModifiedByDeviceProfileId: device.deviceProfileId,
      ),
    );
    final task = CareTaskEntity(
      taskId: 'existing-task',
      title: '연결 전 할 일',
      createdAt: createdAt,
      createdByAuthorProfileId: author.authorProfileId,
      createdByDeviceProfileId: device.deviceProfileId,
    );
    objectBox.careTaskBox.put(task);
    objectBox.careTaskOccurrenceBox.put(
      CareTaskOccurrenceEntity(
        occurrenceId: 'existing-occurrence',
        taskId: task.taskId,
        scheduledAt: createdAt.add(const Duration(hours: 1)),
      ),
    );
    await ObjectBoxAttachmentRepository.fromStore(store).saveAttachment(
      EventAttachment(
        attachmentId: 'existing-attachment',
        recordId: 'existing-activity',
        attachmentType: AttachmentType.general,
        fileName: 'before.txt',
        mimeType: 'text/plain',
        sourceKind: AttachmentSourceKind.filePicker,
        managedOriginalUri: 'file:///local-only/before.txt',
        createdAt: createdAt,
      ),
    );
    objectBox.duplicateReviewEdgeBox.put(
      DuplicateReviewEdgeEntity(
        pairKey: 'existing-a|existing-b',
        recordAId: 'existing-a',
        recordBId: 'existing-b',
        status: DuplicateReviewEdgeEntity.statusDistinctEvents,
        signatureA: 'a',
        signatureB: 'b',
        revisionA: 1,
        revisionB: 1,
        detectionReasonsJson: '[]',
        detectedAt: createdAt,
        detectorVersion: 'test',
        resolvedByAuthorProfileId: author.authorProfileId,
        resolvedByDeviceProfileId: device.deviceProfileId,
        resolvedAt: createdAt.add(const Duration(minutes: 1)),
      ),
    );
    objectBox.duplicateReviewEdgeBox.put(
      DuplicateReviewEdgeEntity(
        pairKey: 'pending-a|pending-b',
        recordAId: 'pending-a',
        recordBId: 'pending-b',
        signatureA: 'a',
        signatureB: 'b',
        revisionA: 1,
        revisionB: 1,
        detectionReasonsJson: '[]',
        detectedAt: createdAt,
        detectorVersion: 'test',
      ),
    );
    final customEventBox = Box<SharedCustomEventDefinitionEntity>(store);
    customEventBox.put(
      SharedCustomEventDefinitionEntity(
        customEventTypeId: 'existing-custom-event',
        familySpaceId: 'local:${device.deviceProfileId}',
        name: '산책',
        createdByAuthorProfileId: author.authorProfileId,
        createdByDeviceProfileId: device.deviceProfileId,
        lastModifiedByAuthorProfileId: author.authorProfileId,
        lastModifiedByDeviceProfileId: device.deviceProfileId,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
    repository.enqueue(
      entityType: FamilySyncPayloads.careTask,
      entityId: task.taskId,
      entityRevision: FamilySyncPayloads.revisionAt(task.createdAt),
      operation: SyncOperation.create,
      payload: FamilySyncPayloads.forTask(task),
      occurredAt: task.createdAt,
    );

    final firstTransport = _FakeTransport(
      const SyncExchange(acknowledgedChangeIds: {}, incomingChanges: []),
    );
    await repository.synchronize(
      firstTransport,
      applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
    );

    expect(firstTransport.receivedOutgoing, hasLength(7));
    expect(
      firstTransport.receivedOutgoing
          .map((change) => change.entityType)
          .toSet(),
      {
        FamilySyncPayloads.authorProfile,
        FamilySyncPayloads.customEventDefinition,
        FamilySyncPayloads.activity,
        FamilySyncPayloads.careTask,
        FamilySyncPayloads.careTaskOccurrence,
        FamilySyncPayloads.attachmentMetadata,
        FamilySyncPayloads.duplicateDecision,
      },
    );
    expect(
      firstTransport.receivedOutgoing.where(
        (change) => change.entityId == task.taskId,
      ),
      hasLength(1),
    );
    expect(
      firstTransport.receivedOutgoing.where(
        (change) => change.entityId == 'pending-a|pending-b',
      ),
      isEmpty,
    );
    expect(customEventBox.getAll().single.familySpaceId, 'family-1');
    expect(
      Box<FamilySpaceEntity>(store).getAll().single.initialBackfillCompletedAt,
      isNotNull,
    );

    repository.connect(familySpaceId: 'family-1', displayName: '튼튼이 기록');
    final secondTransport = _FakeTransport(
      const SyncExchange(acknowledgedChangeIds: {}, incomingChanges: []),
    );
    await repository.synchronize(
      secondTransport,
      applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
    );
    expect(
      secondTransport.receivedOutgoing.map((change) => change.changeId).toSet(),
      firstTransport.receivedOutgoing.map((change) => change.changeId).toSet(),
    );
  });

  test(
    'acknowledged changes are removed and the server cursor is saved',
    () async {
      final pendingIds = <String>[];
      final firstTransport = _FakeTransport(
        const SyncExchange(
          acknowledgedChangeIds: {},
          incomingChanges: [],
          nextCursor: 'cursor-1',
        ),
      );
      await repository.synchronize(
        firstTransport,
        applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
      );
      pendingIds.addAll(
        firstTransport.receivedOutgoing.map((change) => change.changeId),
      );

      final acknowledgeTransport = _FakeTransport(
        SyncExchange(
          acknowledgedChangeIds: pendingIds.toSet(),
          incomingChanges: const [],
          nextCursor: 'cursor-2',
        ),
      );
      final result = await repository.synchronize(
        acknowledgeTransport,
        applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
      );

      expect(acknowledgeTransport.receivedCursor, 'cursor-1');
      expect(result.uploadedCount, pendingIds.length);
      expect(repository.getSnapshot().pendingChangeCount, 0);
      expect(repository.getSnapshot().lastSuccessfulAt, isNotNull);
    },
  );

  test(
    'different edits of the same entity preserve a review conflict',
    () async {
      repository.enqueue(
        entityType: 'memo',
        entityId: 'memo-1',
        entityRevision: 2,
        operation: SyncOperation.update,
        payload: const {'text': '이 기기 수정'},
      );
      final incoming = SyncChange(
        changeId: 'remote-change-1',
        familySpaceId: 'family-1',
        sourceDeviceProfileId: 'other-device',
        sourceAuthorProfileId: 'other-author',
        entityType: 'memo',
        entityId: 'memo-1',
        entityRevision: 3,
        operation: SyncOperation.update,
        payload: const {'text': '다른 기기 수정'},
        occurredAt: DateTime.utc(2026, 7, 29),
      );
      var applyWasCalled = false;
      final result = await repository.synchronize(
        _FakeTransport(
          SyncExchange(
            acknowledgedChangeIds: const {},
            incomingChanges: [incoming],
            nextCursor: 'cursor-conflict',
          ),
        ),
        applyRemoteChange: (_) {
          applyWasCalled = true;
          return const RemoteApplyResult.applied();
        },
      );

      expect(applyWasCalled, isFalse);
      expect(result.conflictCount, 1);
      expect(repository.getSnapshot().unresolvedConflictCount, 1);
      expect(repository.getSnapshot().pendingChangeCount, 2);

      final conflict = repository.getConflicts(includeResolved: false).single;
      expect(conflict.localPayload['text'], '이 기기 수정');
      expect(conflict.incomingPayload['text'], '다른 기기 수정');

      final resolution = await repository.resolveConflict(
        conflictId: conflict.conflictId,
        resolution: SyncConflictResolution.keepLocal,
        applyRemoteChange: (_) => const RemoteApplyResult.applied(),
      );
      expect(resolution.conflict.resolution, SyncConflictResolution.keepLocal);
      expect(resolution.conflict.resolvedByAuthorProfileId, isNotEmpty);
      expect(repository.getSnapshot().unresolvedConflictCount, 0);
      expect(repository.getConflicts().single.isResolved, isTrue);
    },
  );

  test(
    'using the incoming version queues an authoritative new revision',
    () async {
      repository.enqueue(
        entityType: 'memo',
        entityId: 'memo-2',
        entityRevision: 4,
        operation: SyncOperation.update,
        payload: const {'text': '로컬 수정'},
      );
      final incoming = SyncChange(
        changeId: 'remote-change-2',
        familySpaceId: 'family-1',
        sourceDeviceProfileId: 'other-device',
        sourceAuthorProfileId: 'other-author',
        entityType: 'memo',
        entityId: 'memo-2',
        entityRevision: 3,
        operation: SyncOperation.update,
        payload: const {'text': '선택할 다른 기기 수정'},
        occurredAt: DateTime.utc(2026, 7, 29),
      );
      await repository.synchronize(
        _FakeTransport(
          SyncExchange(
            acknowledgedChangeIds: const {},
            incomingChanges: [incoming],
          ),
        ),
        applyRemoteChange: (_) => const RemoteApplyResult.applied(),
      );

      SyncChange? applied;
      final resolution = await repository.resolveConflict(
        conflictId: 'remote-change-2',
        resolution: SyncConflictResolution.useIncoming,
        applyRemoteChange: (change) {
          applied = change;
          return const RemoteApplyResult.applied();
        },
      );

      expect(applied?.entityRevision, 5);
      expect(applied?.payload['text'], '선택할 다른 기기 수정');
      expect(
        resolution.conflict.resolution,
        SyncConflictResolution.useIncoming,
      );

      final transport = _FakeTransport(
        const SyncExchange(acknowledgedChangeIds: {}, incomingChanges: []),
      );
      await repository.synchronize(
        transport,
        applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
      );
      final authoritative = transport.receivedOutgoing.singleWhere(
        (change) => change.entityType == 'memo' && change.entityId == 'memo-2',
      );
      expect(authoritative.entityRevision, 5);
      expect(authoritative.payload['text'], '선택할 다른 기기 수정');
    },
  );

  test(
    'concurrent resolutions converge without creating another conflict',
    () async {
      final localEdit = repository.enqueue(
        entityType: 'memo',
        entityId: 'memo-resolution',
        entityRevision: 2,
        operation: SyncOperation.update,
        payload: const {'text': 'local edit'},
      );
      await repository.synchronize(
        _FakeTransport(
          SyncExchange(
            acknowledgedChangeIds: const {},
            incomingChanges: [
              SyncChange(
                changeId: 'original-remote-change',
                familySpaceId: 'family-1',
                sourceDeviceProfileId: 'remote-device',
                sourceAuthorProfileId: 'remote-author',
                entityType: 'memo',
                entityId: 'memo-resolution',
                entityRevision: 3,
                operation: SyncOperation.update,
                payload: const {'text': 'remote edit'},
                occurredAt: DateTime.utc(2026, 8, 3, 10),
              ),
            ],
          ),
        ),
        applyRemoteChange: (_) => const RemoteApplyResult.applied(),
      );
      final conflict = repository.getConflicts(includeResolved: false).single;
      await repository.resolveConflict(
        conflictId: conflict.conflictId,
        resolution: SyncConflictResolution.keepLocal,
        applyRemoteChange: (_) => const RemoteApplyResult.applied(),
      );

      SyncChange? converged;
      final transport = _FakeTransport(
        SyncExchange(
          acknowledgedChangeIds: const {},
          incomingChanges: [
            SyncChange(
              changeId: 'remote-resolution-change',
              familySpaceId: 'family-1',
              sourceDeviceProfileId: 'remote-device',
              sourceAuthorProfileId: 'remote-author',
              entityType: 'memo',
              entityId: 'memo-resolution',
              entityRevision: 4,
              operation: SyncOperation.update,
              payload: const {'text': 'remote edit'},
              occurredAt: DateTime.utc(2026, 8, 3, 10, 1),
              serverSequence: 20,
              resolutionMetadata: SyncResolutionMetadata(
                sourceConflictId: 'remote-conflict',
                parentChangeIds: [
                  localEdit!.changeId,
                  'original-remote-change',
                ],
                selectedResolution: SyncConflictResolution.useIncoming,
              ),
            ),
          ],
        ),
      );
      final result = await repository.synchronize(
        transport,
        applyRemoteChange: (change) {
          converged = change;
          return const RemoteApplyResult.applied();
        },
      );

      expect(result.conflictCount, 0);
      expect(result.resolutionCollisionCount, 1);
      expect(repository.getSnapshot().unresolvedConflictCount, 0);
      expect(converged?.payload['text'], 'remote edit');
      expect(converged?.entityRevision, 5);
      expect(
        transport.receivedOutgoing
            .where(
              (change) =>
                  change.entityId == 'memo-resolution' &&
                  change.resolutionMetadata != null,
            )
            .single
            .resolutionMetadata
            ?.selectedResolution,
        SyncConflictResolution.keepLocal,
      );
      final notice = repository.getResolutionNotices().single;
      expect(notice.winningChangeId, 'remote-resolution-change');

      final replay = await repository.synchronize(
        _FakeTransport(
          SyncExchange(
            acknowledgedChangeIds: const {},
            incomingChanges: transport.exchangeResult.incomingChanges,
          ),
        ),
        applyRemoteChange: (_) => const RemoteApplyResult.applied(),
      );
      expect(replay.resolutionCollisionCount, 0);
      expect(repository.getResolutionNotices(), hasLength(1));

      final otherAuthorAcknowledgement = SyncChange(
        changeId: 'other-author-ack-change',
        familySpaceId: 'family-1',
        sourceDeviceProfileId: 'other-device',
        sourceAuthorProfileId: 'other-author',
        entityType: FamilySyncPayloads.resolutionNoticeAcknowledgement,
        entityId:
            '${notice.noticeId}\u0000${notice.winningChangeId}\u0000other-author',
        entityRevision: 1,
        operation: SyncOperation.create,
        payload: {
          'schema': 'mlmd.syncResolutionAcknowledgement',
          'version': 1,
          'noticeId': notice.noticeId,
          'winningChangeId': notice.winningChangeId,
          'authorProfileId': 'other-author',
          'acknowledgedAt': '2026-08-03T10:05:00.000Z',
        },
        occurredAt: DateTime.utc(2026, 8, 3, 10, 5),
      );
      final otherAckResult = await repository.synchronize(
        _FakeTransport(
          SyncExchange(
            acknowledgedChangeIds: const {},
            incomingChanges: [otherAuthorAcknowledgement],
          ),
        ),
        applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
      );
      expect(otherAckResult.appliedCount, 1);
      expect(repository.getResolutionNotices(), hasLength(1));
      expect(
        repository
            .getResolutionNotices(includeAcknowledged: true)
            .single
            .acknowledgedAuthorProfileIds,
        contains('other-author'),
      );

      repository.acknowledgeResolutionNotice(notice.noticeId);
      expect(repository.getResolutionNotices(), isEmpty);
      expect(
        repository.getResolutionNotices(includeAcknowledged: true),
        hasLength(1),
      );
      final acknowledgementUpload = _FakeTransport(
        const SyncExchange(acknowledgedChangeIds: {}, incomingChanges: []),
      );
      await repository.synchronize(
        acknowledgementUpload,
        applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
      );
      final uploadedAcknowledgement = acknowledgementUpload.receivedOutgoing
          .singleWhere(
            (change) =>
                change.entityType ==
                FamilySyncPayloads.resolutionNoticeAcknowledgement,
          );
      expect(
        uploadedAcknowledgement.payload['authorProfileId'],
        profiles.currentAuthor!.authorProfileId,
      );
      expect(
        uploadedAcknowledgement.payload['winningChangeId'],
        notice.winningChangeId,
      );

      final acknowledgementReplay = await repository.synchronize(
        _FakeTransport(
          SyncExchange(
            acknowledgedChangeIds: const {},
            incomingChanges: [uploadedAcknowledgement],
          ),
        ),
        applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
      );
      expect(acknowledgementReplay.appliedCount, 0);
      expect(repository.getResolutionNotices(), isEmpty);

      final laterResolution = await repository.synchronize(
        _FakeTransport(
          SyncExchange(
            acknowledgedChangeIds: const {},
            incomingChanges: [
              SyncChange(
                changeId: 'later-resolution-change',
                familySpaceId: 'family-1',
                sourceDeviceProfileId: 'remote-device',
                sourceAuthorProfileId: 'remote-author',
                entityType: 'memo',
                entityId: 'memo-resolution',
                entityRevision: 6,
                operation: SyncOperation.update,
                payload: const {'text': 'later resolved edit'},
                occurredAt: DateTime.utc(2026, 8, 3, 11),
                serverSequence: 30,
                resolutionMetadata: const SyncResolutionMetadata(
                  sourceConflictId: 'later-conflict',
                  parentChangeIds: ['later-change-a', 'later-change-b'],
                  selectedResolution: SyncConflictResolution.keepLocal,
                ),
              ),
            ],
          ),
        ),
        applyRemoteChange: (_) => const RemoteApplyResult.applied(),
      );
      expect(laterResolution.resolutionCollisionCount, 0);
      expect(
        repository.getResolutionNotices(includeAcknowledged: true),
        hasLength(1),
      );
    },
  );

  test('record save paths enqueue shareable text changes', () async {
    final diaryRepository = DiaryRepositoryImpl(
      objectBox,
      profiles,
      familySyncRepository: repository,
    );
    final taskRepository = TaskRepositoryImpl(
      objectBox,
      profiles,
      familySyncRepository: repository,
    );
    final attachmentRepository = ObjectBoxAttachmentRepository.fromStore(
      store,
      familySyncRepository: repository,
    );
    final duplicateRepository = DuplicateReviewRepositoryImpl(
      objectBox,
      profiles,
      familySyncRepository: repository,
    );
    final author = profiles.currentAuthor!;
    profiles.updateAuthor(
      authorProfileId: author.authorProfileId,
      nickname: '엄마 수정',
      colorValue: 0xFF00695C,
    );

    diaryRepository.addActivityRecord(
      ActivityEntity(
        type: '메모',
        time: DateTime.utc(2026, 7, 29, 9),
        details: '공유할 메모',
        lastModified: DateTime.utc(2026, 7, 29, 9),
      ),
    );
    taskRepository.createTask(
      title: '비타민 챙기기',
      firstScheduledAt: DateTime.utc(2026, 7, 29, 10),
    );
    await attachmentRepository.saveAttachment(
      EventAttachment(
        attachmentId: 'attachment-1',
        recordId: 'record-1',
        attachmentType: AttachmentType.general,
        fileName: 'note.txt',
        mimeType: 'text/plain',
        sourceKind: AttachmentSourceKind.filePicker,
        managedOriginalUri: 'file:///local-only/note.txt',
        createdAt: DateTime.utc(2026, 7, 29, 11),
      ),
    );
    objectBox.duplicateReviewEdgeBox.put(
      DuplicateReviewEdgeEntity(
        pairKey: 'a|b',
        recordAId: 'a',
        recordBId: 'b',
        signatureA: 'a',
        signatureB: 'b',
        revisionA: 1,
        revisionB: 1,
        detectionReasonsJson: '[]',
        detectedAt: DateTime.utc(2026, 7, 29, 12),
        detectorVersion: 'test',
      ),
    );
    duplicateRepository.markDistinct('a|b');

    final transport = _FakeTransport(
      const SyncExchange(acknowledgedChangeIds: {}, incomingChanges: []),
    );
    await repository.synchronize(
      transport,
      applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
    );

    final entityTypes = transport.receivedOutgoing
        .map((change) => change.entityType)
        .toSet();
    expect(
      entityTypes,
      containsAll({
        FamilySyncPayloads.authorProfile,
        FamilySyncPayloads.activity,
        FamilySyncPayloads.careTask,
        FamilySyncPayloads.careTaskOccurrence,
        FamilySyncPayloads.attachmentMetadata,
        FamilySyncPayloads.duplicateDecision,
      }),
    );
    final attachmentChange = transport.receivedOutgoing.singleWhere(
      (change) => change.entityType == FamilySyncPayloads.attachmentMetadata,
    );
    expect(attachmentChange.payload, isNot(contains('managedOriginalUri')));
    expect(
      transport.receivedOutgoing
          .where(
            (change) => change.entityType == FamilySyncPayloads.authorProfile,
          )
          .map((change) => change.operation),
      contains(SyncOperation.update),
    );
  });

  test('backfills child profiles and queues later child mutations', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final childProfiles = ChildProfileRepository(prefs);
    childProfiles.create(name: 'Baby', childId: 'child-a');
    final familySpaceBox = Box<FamilySpaceEntity>(store);
    final existingSpace = familySpaceBox.getAll().single
      ..initialBackfillCompletedAt = DateTime.utc(2026, 8, 15);
    familySpaceBox.put(existingSpace);
    (repository as FamilySyncRepositoryImpl).dispose();
    repository = FamilySyncRepositoryImpl(objectBox, profiles, childProfiles);

    final firstTransport = _FakeTransport(
      const SyncExchange(acknowledgedChangeIds: {}, incomingChanges: []),
    );
    await repository.synchronize(
      firstTransport,
      applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
    );

    final childChanges = firstTransport.receivedOutgoing
        .where((change) => change.entityType == FamilySyncPayloads.childProfile)
        .toList();
    expect(childChanges, hasLength(2));
    expect(
      childChanges.map((change) => change.payload['familySpaceId']).toSet(),
      {'family-1'},
    );
    expect(
      familySpaceBox.getAll().single.childProfileBackfillCompletedAt,
      isNotNull,
    );

    childProfiles.update(childId: 'child-a', name: 'Baby updated');
    await Future<void>.delayed(Duration.zero);
    final secondTransport = _FakeTransport(
      const SyncExchange(acknowledgedChangeIds: {}, incomingChanges: []),
    );
    await repository.synchronize(
      secondTransport,
      applyRemoteChange: (_) => const RemoteApplyResult.ignored(),
    );
    expect(
      secondTransport.receivedOutgoing.where(
        (change) =>
            change.entityType == FamilySyncPayloads.childProfile &&
            change.entityId == 'child-a' &&
            change.entityRevision == 2,
      ),
      hasLength(1),
    );
    childProfiles.dispose();
  });
}
