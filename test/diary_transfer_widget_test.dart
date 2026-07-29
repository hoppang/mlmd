import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/transfer/canonical_transfer_document.dart';
import 'package:mlmd/transfer/diary_transfer_service.dart';
import 'package:mlmd/features/settings/presentation/settings_page.dart';
import 'package:mlmd/features/attachments/domain/event_attachment.dart';
import 'package:mlmd/widgets/import_preview_dialog.dart';
import 'package:mlmd/repositories/profile_repository.dart';
import 'package:mlmd/repositories/family_sync_repository.dart';
import 'package:mlmd/features/sharing/domain/family_sync_models.dart';
import 'package:mlmd/features/sharing/application/family_sync_transport.dart';
import 'package:mlmd/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/test_profile_repository.dart';

void main() {
  testWidgets('import preview explains safe merge and conflict counts', (
    tester,
  ) async {
    final prepared = PreparedDiaryImport(
      schemaVersion: 1,
      sourceName: 'backup.mlmd.json',
      document: CanonicalImportDocument(
        exportedAt: DateTime.utc(2026, 7, 18),
        appVersion: '1.0.0+1',
        diaries: const [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImportPreviewDialog(
          prepared: prepared,
          previewFor: (policy) => ImportPreview(
            total: 3,
            newCount: 1,
            duplicateCount: 2,
            newerCount: 0,
            skippedCount: 2,
            activityCount: 2,
            identicalCount: 1,
            conflictCount: 1,
          ),
        ),
      ),
    );

    expect(find.text('Import Preview'), findsOneWidget);
    expect(find.text('Same content 1'), findsOneWidget);
    expect(find.text('Conflicts to review 1'), findsOneWidget);
    expect(find.textContaining('not overwritten'), findsOneWidget);
    expect(find.text('Overwrite only when backup is newer'), findsNothing);
  });

  testWidgets('settings exposes five top-level destinations', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(TestProfileRepository()),
          familySyncRepositoryProvider.overrideWithValue(
            _FakeFamilySyncRepository(),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(
            onExport: (_) async {},
            onImport: () async {},
            backupOverview: () => const BackupOverview(
              diaryCount: 2,
              activityCount: 3,
              estimatedBackupBytes: 2048,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Child information'), findsOneWidget);
    expect(find.text('My name and color'), findsOneWidget);
    expect(find.text('Use with family'), findsOneWidget);
    expect(find.text('Data storage and backup'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Tracking style'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);

    await tester.tap(find.text('Use with family'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('family-sharing-not-connected')),
      findsOneWidget,
    );
    expect(find.text('Keep recording without the internet'), findsOneWidget);
    expect(find.text('Original photos stay on this device'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Data storage and backup'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 diaries · 3 activities\nEstimated file size 2.0 KB'),
      findsOneWidget,
    );
    expect(find.text('Create backup file'), findsNWidgets(2));
    expect(find.text('Records and original attachments'), findsOneWidget);
    final group = tester.widget<RadioGroup<AttachmentExportMode>>(
      find.byType(RadioGroup<AttachmentExportMode>),
    );
    expect(group.groupValue, AttachmentExportMode.originalAttachments);
  });
}

class _FakeFamilySyncRepository implements FamilySyncRepository {
  @override
  String? get activeFamilySpaceId => null;

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
  FamilySyncSnapshot getSnapshot() => const FamilySyncSnapshot();

  @override
  List<FamilySyncConflict> getConflicts({bool includeResolved = true}) =>
      const [];

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
