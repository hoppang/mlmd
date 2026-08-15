import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/sharing/application/family_sync_coordinator.dart';
import 'package:mlmd/features/sharing/application/family_sync_transport.dart';
import 'package:mlmd/features/sharing/domain/family_sync_models.dart';
import 'package:mlmd/repositories/family_sync_repository.dart';

void main() {
  testWidgets('local outbox growth triggers one debounced sync', (
    tester,
  ) async {
    final repository = _FakeFamilySyncRepository();
    final retryController = _FakeRetryController();

    await tester.pumpWidget(
      _testApp(
        repository: repository,
        retryController: retryController,
        enqueueDebounce: const Duration(milliseconds: 100),
        foregroundPullInterval: const Duration(hours: 1),
      ),
    );
    expect(retryController.callCount, 1);

    await tester.tap(find.byKey(const Key('queue-change')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('queue-change')));
    await tester.pump(const Duration(milliseconds: 99));
    expect(retryController.callCount, 1);

    await tester.pump(const Duration(milliseconds: 1));
    expect(retryController.callCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('periodic pull only runs while the app is foregrounded', (
    tester,
  ) async {
    final repository = _FakeFamilySyncRepository();
    final retryController = _FakeRetryController();

    await tester.pumpWidget(
      _testApp(
        repository: repository,
        retryController: retryController,
        enqueueDebounce: const Duration(hours: 1),
        foregroundPullInterval: const Duration(seconds: 1),
      ),
    );
    expect(retryController.callCount, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(retryController.callCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(retryController.callCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(retryController.callCount, 3);

    await tester.pump(const Duration(seconds: 1));
    expect(retryController.callCount, 4);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _testApp({
  required _FakeFamilySyncRepository repository,
  required _FakeRetryController retryController,
  required Duration enqueueDebounce,
  required Duration foregroundPullInterval,
}) => ProviderScope(
  overrides: [
    familySyncRepositoryProvider.overrideWithValue(repository),
    familySyncRetryControllerProvider.overrideWithValue(retryController),
    familySyncNetworkAvailableProvider.overrideWith(
      (ref) => const Stream<bool>.empty(),
    ),
  ],
  child: MaterialApp(
    home: FamilySyncLifecycle(
      enqueueDebounce: enqueueDebounce,
      foregroundPullInterval: foregroundPullInterval,
      child: const _QueueChangeButton(),
    ),
  ),
);

class _QueueChangeButton extends ConsumerWidget {
  const _QueueChangeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
    key: const Key('queue-change'),
    onPressed: () {
      final repository =
          ref.read(familySyncRepositoryProvider) as _FakeFamilySyncRepository;
      repository.queueChange();
      ref.read(familySyncStatusProvider.notifier).reload();
    },
    child: const Text('queue'),
  );
}

class _FakeRetryController implements FamilySyncRetryController {
  int callCount = 0;

  @override
  Future<SyncRunResult?> retry() async {
    callCount++;
    return null;
  }
}

class _FakeFamilySyncRepository implements FamilySyncRepository {
  int pendingChangeCount = 0;

  void queueChange() => pendingChangeCount++;

  @override
  String? get activeFamilySpaceId => 'family-1';

  @override
  void acknowledgeResolutionNotice(String noticeId) {}

  @override
  void connect({required String familySpaceId, required String displayName}) {}

  @override
  void disconnect() {}

  @override
  SyncChange? enqueue({
    required String entityType,
    required String entityId,
    required int entityRevision,
    required SyncOperation operation,
    required Map<String, Object?> payload,
    DateTime? occurredAt,
    SyncResolutionMetadata? resolutionMetadata,
  }) => null;

  @override
  List<FamilySyncConflict> getConflicts({bool includeResolved = true}) =>
      const [];

  @override
  List<FamilySyncResolutionNotice> getResolutionNotices({
    bool includeAcknowledged = false,
  }) => const [];

  @override
  FamilySyncSnapshot getSnapshot() => FamilySyncSnapshot(
    familySpaceId: activeFamilySpaceId,
    familyDisplayName: 'Family',
    pendingChangeCount: pendingChangeCount,
  );

  @override
  Future<ConflictResolutionResult> resolveConflict({
    required String conflictId,
    required SyncConflictResolution resolution,
    required RemoteChangeApplier applyRemoteChange,
  }) => throw UnimplementedError();

  @override
  Future<SyncRunResult> synchronize(
    FamilySyncTransport transport, {
    required RemoteChangeApplier applyRemoteChange,
  }) => throw UnimplementedError();
}
