import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/features/sharing/application/family_sync_transport.dart';
import 'package:mlmd/features/sharing/application/family_sync_payloads.dart';
import 'package:mlmd/features/sharing/domain/family_sync_models.dart';
import 'package:mlmd/features/attachments/application/attachment_service.dart';
import 'package:mlmd/features/attachments/domain/event_attachment.dart';
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

  test('using the incoming version queues an authoritative new revision', () async {
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
    expect(resolution.conflict.resolution, SyncConflictResolution.useIncoming);

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
  });

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
}
