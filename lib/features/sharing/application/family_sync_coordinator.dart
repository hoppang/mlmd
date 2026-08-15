import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/objectbox_helper.dart';
import '../../../repositories/custom_event_repository.dart';
import '../../../repositories/family_sync_repository.dart';
import '../domain/family_sync_models.dart';
import 'family_sync_remote_applier.dart';
import 'family_sync_transport.dart';
import 'family_sync_transport_provider.dart';

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
  bool _rerunRequested = false;

  Future<SyncRunResult?> retry() {
    final existing = _activeRun;
    if (existing != null) {
      _rerunRequested = true;
      return existing;
    }
    final run = _runUntilIdle();
    _activeRun = run;
    return run.whenComplete(() {
      if (identical(_activeRun, run)) _activeRun = null;
    });
  }

  Future<SyncRunResult?> _runUntilIdle() async {
    SyncRunResult? result;
    do {
      _rerunRequested = false;
      result = await _run();
    } while (_rerunRequested);
    return result;
  }

  Future<SyncRunResult?> _run() async {
    final repository = _ref.read(familySyncRepositoryProvider);
    if (!repository.getSnapshot().isConnected) return null;
    final transport = _ref.read(familySyncTransportProvider);
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

/// Synchronizes on startup, connectivity recovery, foreground resume, local
/// outbox growth, and periodically while the application stays foregrounded.
class FamilySyncLifecycle extends ConsumerStatefulWidget {
  const FamilySyncLifecycle({
    required this.child,
    this.enqueueDebounce = const Duration(milliseconds: 750),
    this.foregroundPullInterval = const Duration(seconds: 30),
    super.key,
  });

  final Widget child;
  final Duration enqueueDebounce;
  final Duration foregroundPullInterval;

  @override
  ConsumerState<FamilySyncLifecycle> createState() =>
      _FamilySyncLifecycleState();
}

class _FamilySyncLifecycleState extends ConsumerState<FamilySyncLifecycle>
    with WidgetsBindingObserver {
  Timer? _enqueueTimer;
  Timer? _periodicTimer;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startPeriodicPull();
      _retry();
    });
  }

  @override
  void dispose() {
    _enqueueTimer?.cancel();
    _periodicTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _startPeriodicPull();
      _retry();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _isForeground = false;
      _enqueueTimer?.cancel();
      _enqueueTimer = null;
      _periodicTimer?.cancel();
      _periodicTimer = null;
    }
  }

  void _retry() {
    if (!mounted || !_isForeground) return;
    unawaited(ref.read(familySyncRetryControllerProvider).retry());
  }

  void _scheduleEnqueueRetry() {
    if (!_isForeground) return;
    _enqueueTimer?.cancel();
    _enqueueTimer = Timer(widget.enqueueDebounce, _retry);
  }

  void _startPeriodicPull() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      widget.foregroundPullInterval,
      (_) => _retry(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(familySyncNetworkAvailableProvider, (
      previous,
      next,
    ) {
      if (next.value == true && previous?.value != true) _retry();
    });
    ref.listen<FamilySyncSnapshot>(familySyncStatusProvider, (previous, next) {
      if (next.isConnected &&
          next.pendingChangeCount > (previous?.pendingChangeCount ?? 0)) {
        _scheduleEnqueueRetry();
      }
    });
    return widget.child;
  }
}
