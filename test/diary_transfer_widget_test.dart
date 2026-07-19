import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/transfer/canonical_transfer_document.dart';
import 'package:mlmd/transfer/diary_transfer_service.dart';
import 'package:mlmd/widgets/import_preview_dialog.dart';

void main() {
  testWidgets('import preview updates counts when conflict policy changes', (
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
            total: 1,
            newCount: 0,
            duplicateCount: 1,
            newerCount: policy == ImportConflictPolicy.overwriteIfNewer ? 1 : 0,
            skippedCount: policy == ImportConflictPolicy.overwriteIfNewer
                ? 0
                : 1,
            activityCount: 2,
          ),
        ),
      ),
    );

    expect(find.text('Import Preview'), findsOneWidget);
    expect(find.text('Skipped 1'), findsOneWidget);

    final overwriteOption = find.text('Overwrite only when backup is newer');
    await tester.ensureVisible(overwriteOption);
    await tester.pumpAndSettle();
    await tester.tap(overwriteOption);
    await tester.pumpAndSettle();

    expect(find.text('Update from newer backup 1'), findsOneWidget);
    expect(find.text('Skipped 0'), findsOneWidget);
  });
}
