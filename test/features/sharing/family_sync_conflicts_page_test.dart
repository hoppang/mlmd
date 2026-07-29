import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/sharing/application/family_sync_transport.dart';
import 'package:mlmd/features/sharing/domain/family_sync_models.dart';
import 'package:mlmd/features/sharing/presentation/family_sharing_page.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/repositories/family_sync_repository.dart';

void main() {
  testWidgets('opens a conflict and compares both versions before resolving', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familySyncRepositoryProvider.overrideWithValue(
            _ConflictFamilySyncRepository(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FamilySharingPage(),
        ),
      ),
    );

    expect(find.text('충돌 확인하기'), findsOneWidget);
    await tester.tap(find.text('충돌 확인하기'));
    await tester.pumpAndSettle();

    expect(find.text('동기화 충돌 확인'), findsOneWidget);
    expect(find.text('결정 필요'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sync-conflict-conflict-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('sync-conflict-local-version')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sync-conflict-incoming-version')),
      findsOneWidget,
    );
    expect(find.text('이 기기 내용'), findsOneWidget);
    expect(find.text('다른 기기 내용'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sync-conflict-use-incoming')));
    await tester.pumpAndSettle();
    expect(find.text('이 충돌을 해결할까요?'), findsOneWidget);
    expect(
      find.textContaining('새 변경으로 저장되어 연결된 기기에 공유'),
      findsNWidgets(2),
    );
  });
}

class _ConflictFamilySyncRepository implements FamilySyncRepository {
  final conflict = FamilySyncConflict(
    conflictId: 'conflict-1',
    familySpaceId: 'family-1',
    entityType: 'memo',
    entityId: 'memo-1',
    localRevision: 2,
    incomingRevision: 3,
    localPayload: const {'text': '이 기기 내용'},
    incomingPayload: const {'text': '다른 기기 내용'},
    incomingChangeId: 'change-1',
    incomingOperation: SyncOperation.update,
    detectedAt: DateTime(2026, 7, 29),
  );

  @override
  String? get activeFamilySpaceId => 'family-1';

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
  }) => null;

  @override
  List<FamilySyncConflict> getConflicts({bool includeResolved = true}) => [
    conflict,
  ];

  @override
  FamilySyncSnapshot getSnapshot() => const FamilySyncSnapshot(
    familySpaceId: 'family-1',
    familyDisplayName: '튼튼이 기록',
    unresolvedConflictCount: 1,
  );

  @override
  Future<ConflictResolutionResult> resolveConflict({
    required String conflictId,
    required SyncConflictResolution resolution,
    required RemoteChangeApplier applyRemoteChange,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SyncRunResult> synchronize(
    FamilySyncTransport transport, {
    required RemoteChangeApplier applyRemoteChange,
  }) {
    throw UnimplementedError();
  }
}
