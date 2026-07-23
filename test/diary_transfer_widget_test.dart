import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/transfer/canonical_transfer_document.dart';
import 'package:mlmd/transfer/diary_transfer_service.dart';
import 'package:mlmd/features/settings/presentation/settings_page.dart';
import 'package:mlmd/widgets/import_preview_dialog.dart';
import 'package:mlmd/repositories/profile_repository.dart';
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(TestProfileRepository()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(
            onExport: () async {},
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

    await tester.tap(find.text('Data storage and backup'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 diaries · 3 activities\nEstimated file size 2.0 KB'),
      findsOneWidget,
    );
    expect(find.text('Create backup file'), findsNWidgets(2));
  });
}
