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
    expect(find.textContaining('새 변경으로 저장되어 연결된 기기에 공유'), findsNWidgets(2));
  });

  testWidgets('medication conflict stays prominent and shows safety details', (
    tester,
  ) async {
    final medicationConflict = FamilySyncConflict(
      conflictId: 'medication-conflict',
      familySpaceId: 'family-1',
      entityType: 'activity',
      entityId: 'medication-1',
      localRevision: 2,
      incomingRevision: 3,
      localPayload: const {
        'type': '투약',
        'structuredDataJson':
            '{"schema":"mlmd.medication","medicationName":"해열제","amount":5,"unit":"mL","administeredAt":"2026-08-03T12:00:00Z"}',
        'lastModifiedByAuthorProfileId': 'author-local',
        'lastModifiedByDeviceProfileId': 'device-local',
        'lastModified': '2026-08-03T12:01:00Z',
      },
      incomingPayload: const {
        'type': '투약',
        'structuredDataJson':
            '{"schema":"mlmd.medication","medicationName":"해열제","amount":7.5,"unit":"mL","administeredAt":"2026-08-03T12:05:00Z"}',
      },
      incomingChangeId: 'change-medication',
      incomingOperation: SyncOperation.update,
      incomingSourceAuthorProfileId: 'author-remote',
      incomingSourceDeviceProfileId: 'device-remote',
      incomingOccurredAt: DateTime.utc(2026, 8, 3, 12, 6),
      detectedAt: DateTime.utc(2026, 8, 3, 12, 7),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familySyncRepositoryProvider.overrideWithValue(
            _ConflictFamilySyncRepository(conflict: medicationConflict),
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

    expect(
      find.byKey(const Key('family-sharing-critical-conflict')),
      findsOneWidget,
    );
    expect(find.textContaining('5 mL'), findsOneWidget);
    expect(find.textContaining('7.5 mL'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('family-sharing-review-critical-conflict')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('sync-conflict-medication-local')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sync-conflict-medication-incoming')),
      findsOneWidget,
    );
    expect(find.text('author-local'), findsOneWidget);
    expect(find.text('device-remote'), findsOneWidget);
  });

  testWidgets('shows a detailed medication resolution notice and acknowledges it', (
    tester,
  ) async {
    final repository = _ConflictFamilySyncRepository(
      notice: FamilySyncResolutionNotice(
        noticeId: 'resolution-a:resolution-b',
        familySpaceId: 'family-1',
        entityType: 'activity',
        entityId: 'medication-1',
        firstChangeId: 'resolution-a',
        secondChangeId: 'resolution-b',
        winningChangeId: 'resolution-b',
        firstPayload: const {
          'structuredDataJson':
              '{"schema":"mlmd.medication","medicationName":"해열제","amount":5,"unit":"mL"}',
        },
        secondPayload: const {
          'structuredDataJson':
              '{"schema":"mlmd.medication","medicationName":"해열제","amount":7.5,"unit":"mL"}',
        },
        firstSourceDeviceProfileId: 'device-a',
        firstSourceAuthorProfileId: 'author-a',
        secondSourceDeviceProfileId: 'device-b',
        secondSourceAuthorProfileId: 'author-b',
        firstOccurredAt: DateTime.utc(2026, 8, 3, 12),
        secondOccurredAt: DateTime.utc(2026, 8, 3, 12, 1),
        detectedAt: DateTime.utc(2026, 8, 3, 12, 2),
        acknowledgedAuthorProfileIds: const {'author-a'},
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [familySyncRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FamilySharingPage(),
        ),
      ),
    );

    expect(
      find.byKey(const Key('family-sharing-resolution-notice')),
      findsOneWidget,
    );
    expect(find.text('투약 충돌의 동시 해소 결과'), findsOneWidget);
    expect(find.textContaining('5 mL'), findsOneWidget);
    expect(find.textContaining('7.5 mL'), findsOneWidget);
    expect(find.text('최종 적용: 두 번째 해소'), findsOneWidget);
    expect(find.text('확인한 구성원 1명'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('family-sharing-acknowledge-resolution-notice')),
    );
    await tester.pump();
    expect(repository.acknowledgedNoticeId, 'resolution-a:resolution-b');
  });
}

class _ConflictFamilySyncRepository implements FamilySyncRepository {
  _ConflictFamilySyncRepository({FamilySyncConflict? conflict, this.notice})
    : conflict =
          conflict ??
          FamilySyncConflict(
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

  final FamilySyncConflict conflict;
  final FamilySyncResolutionNotice? notice;
  String? acknowledgedNoticeId;

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
    SyncResolutionMetadata? resolutionMetadata,
  }) => null;

  @override
  List<FamilySyncResolutionNotice> getResolutionNotices({
    bool includeAcknowledged = false,
  }) => notice == null ? const [] : [notice!];

  @override
  void acknowledgeResolutionNotice(String noticeId) {
    acknowledgedNoticeId = noticeId;
  }

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
