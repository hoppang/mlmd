import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/diary/presentation/diary_form_page.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/repositories/record_draft_repository.dart';

class _MemoryDraftRepository implements RecordDraftRepository {
  final Map<String, RecordDraftEntity> drafts = {};

  @override
  bool deleteDraft(String draftId) => drafts.remove(draftId) != null;

  @override
  List<RecordDraftEntity> getAllDrafts() => drafts.values.toList();

  @override
  RecordDraftEntity? getByDraftId(String draftId) => drafts[draftId];

  @override
  List<RecordDraftEntity> getCreateDrafts(String recordType) => drafts.values
      .where(
        (draft) =>
            draft.draftKind == 'createRecord' &&
            draft.recordType == recordType,
      )
      .toList();

  @override
  RecordDraftEntity? getEditDraft(String targetRecordId) => null;

  @override
  int saveDraft(RecordDraftEntity draft) {
    drafts[draft.draftId] = draft;
    return drafts.length;
  }
}

void main() {
  testWidgets('draft survives back navigation and restores on reopen', (
    tester,
  ) async {
    final repository = _MemoryDraftRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordDraftRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
          locale: const Locale('ko'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    final draftId = repository.drafts.keys.firstOrNull;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiaryFormPage(draftId: draftId),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '사라지면 안 되는 내용');
    await tester.pump(const Duration(milliseconds: 600));

    expect(repository.drafts, hasLength(1));
    expect(find.text('임시 저장됨'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('사라지면 안 되는 내용'), findsOneWidget);
    expect(find.text('임시 저장됨'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('초안 버리기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('초안 버리기'));
    await tester.pumpAndSettle();

    expect(repository.drafts, isEmpty);
    expect(find.text('open'), findsOneWidget);
  });
}
