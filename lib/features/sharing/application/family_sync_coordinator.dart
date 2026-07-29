import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/objectbox_helper.dart';
import '../../../repositories/custom_event_repository.dart';
import '../../../repositories/family_sync_repository.dart';
import '../domain/family_sync_models.dart';
import 'family_sync_remote_applier.dart';
import 'family_sync_transport.dart';

/// Platform/provider integrations may override this with their connectivity
/// stream. The default emits once so a configured transport synchronizes at
/// startup without adding a network-observation dependency to the local core.
final familySyncNetworkAvailableProvider = StreamProvider<bool>(
  (ref) => Stream<bool>.value(true),
);

class FamilySyncRetryController {
  FamilySyncRetryController(this._ref);

  final Ref _ref;
  Future<SyncRunResult?>? _activeRun;

  Future<SyncRunResult?> retry() {
    final existing = _activeRun;
    if (existing != null) return existing;
    final run = _run();
    _activeRun = run;
    return run.whenComplete(() {
      if (identical(_activeRun, run)) _activeRun = null;
    });
  }

  Future<SyncRunResult?> _run() async {
    final repository = _ref.read(familySyncRepositoryProvider);
    if (!repository.getSnapshot().isConnected) return null;
    final transport = _ref.read(familySyncTransportProvider);
    if (transport is UnconfiguredFamilySyncTransport) return null;
    final applier = FamilySyncRemoteApplier(
      _ref.read(objectBoxProvider),
      _ref.read(customEventRepositoryProvider),
    );
    try {
      return await repository.synchronize(
        transport,
        applyRemoteChange: applier.call,
      );
    } on FamilySyncUnavailable {
      return null;
    } catch (_) {
      // The repository already records transport failures and preserves its
      // outbox. Automatic retries must never interrupt the active UI.
      return null;
    } finally {
      _ref.read(familySyncStatusProvider.notifier).reload();
    }
  }
}

final familySyncRetryControllerProvider = Provider<FamilySyncRetryController>(
  FamilySyncRetryController.new,
  dependencies: [
    familySyncRepositoryProvider,
    familySyncTransportProvider,
    objectBoxProvider,
    customEventRepositoryProvider,
    familySyncStatusProvider,
  ],
);

class FamilySyncConflictController {
  FamilySyncConflictController(this._ref);

  final Ref _ref;

  Future<ConflictResolutionResult> resolve({
    required String conflictId,
    required SyncConflictResolution resolution,
  }) async {
    final applier = FamilySyncRemoteApplier(
      _ref.read(objectBoxProvider),
      _ref.read(customEventRepositoryProvider),
    );
    final result = await _ref
        .read(familySyncRepositoryProvider)
        .resolveConflict(
          conflictId: conflictId,
          resolution: resolution,
          applyRemoteChange: applier.call,
        );
    _ref.read(familySyncStatusProvider.notifier).reload();
    return result;
  }
}

final familySyncConflictControllerProvider =
    Provider<FamilySyncConflictController>(
      FamilySyncConflictController.new,
      dependencies: [
        familySyncRepositoryProvider,
        objectBoxProvider,
        customEventRepositoryProvider,
        familySyncStatusProvider,
      ],
    );

/// Retries on startup, when a connectivity adapter reports availability, and
/// whenever the application returns to the foreground.
class FamilySyncLifecycle extends ConsumerStatefulWidget {
  const FamilySyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FamilySyncLifecycle> createState() =>
      _FamilySyncLifecycleState();
}

class _FamilySyncLifecycleState extends ConsumerState<FamilySyncLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _retry());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retry();
  }

  void _retry() {
    if (!mounted) return;
    unawaited(ref.read(familySyncRetryControllerProvider).retry());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(familySyncNetworkAvailableProvider, (
      previous,
      next,
    ) {
      if (next.value == true && previous?.value != true) _retry();
    });
    return widget.child;
  }
}
