import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/features/sharing/application/family_sync_transport.dart';
import 'package:mlmd/features/sharing/domain/family_sync_models.dart';
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
    },
  );
}
