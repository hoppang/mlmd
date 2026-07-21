import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/diary/application/diary_draft_payload.dart';
import 'package:mlmd/features/diary/application/diary_list_notifier.dart';
import 'package:mlmd/features/diary/presentation/diary_form_page.dart';
import 'package:mlmd/features/diary/presentation/diary_home_page.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/repositories/record_draft_repository.dart';

class _TestDiaryListNotifier extends DiaryListNotifier {
  _TestDiaryListNotifier(this.diaries);

  final List<DiaryEntity> diaries;

  @override
  List<DiaryEntity> build() => diaries;
}

class _TestDraftListNotifier extends RecordDraftListNotifier {
  _TestDraftListNotifier(this.drafts);

  final List<RecordDraftEntity> drafts;

  @override
  List<RecordDraftEntity> build() => drafts;
}

class _MemoryDraftRepository implements RecordDraftRepository {
  _MemoryDraftRepository([Iterable<RecordDraftEntity> drafts = const []]) {
    for (final draft in drafts) {
      _drafts[draft.draftId] = draft;
    }
  }

  final Map<String, RecordDraftEntity> _drafts = {};

  @override
  bool deleteDraft(String draftId) => _drafts.remove(draftId) != null;

  @override
  List<RecordDraftEntity> getAllDrafts() => _drafts.values.toList();

  @override
  RecordDraftEntity? getByDraftId(String draftId) => _drafts[draftId];

  @override
  List<RecordDraftEntity> getCreateDrafts(String recordType) => _drafts.values
      .where(
        (draft) =>
            draft.draftKind == 'createRecord' && draft.recordType == recordType,
      )
      .toList();

  @override
  RecordDraftEntity? getEditDraft(String targetRecordId) {
    for (final draft in _drafts.values) {
      if (draft.draftKind == 'editRecord' &&
          draft.targetRecordId == targetRecordId) {
        return draft;
      }
    }
    return null;
  }

  @override
  int saveDraft(RecordDraftEntity draft) {
    _drafts[draft.draftId] = draft;
    return _drafts.length;
  }
}

Widget _buildApp({
  List<DiaryEntity> diaries = const [],
  List<RecordDraftEntity> drafts = const [],
}) {
  return ProviderScope(
    overrides: [
      diaryListProvider.overrideWith(() => _TestDiaryListNotifier(diaries)),
      recordDraftRepositoryProvider.overrideWithValue(
        _MemoryDraftRepository(drafts),
      ),
      recordDraftListProvider.overrideWith(
        () => _TestDraftListNotifier(drafts),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('ko'), Locale('en'), Locale('ja')],
      locale: Locale('ko'),
      home: DiaryDemoPage(),
    ),
  );
}

void main() {
  testWidgets('오늘 일기가 있어도 홈에서 시작하고 선택한 뒤에만 편집한다', (tester) async {
    final now = DateTime.now();
    final diary = DiaryEntity(
      id: 1,
      recordId: 'today-record',
      date: now,
      title: '오늘 기록',
      content: '자동으로 열리면 안 됩니다.',
      lastModified: now,
    );

    await tester.pumpWidget(_buildApp(diaries: [diary]));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryDemoPage), findsOneWidget);
    expect(find.byType(DiaryFormPage), findsNothing);
    expect(find.text('오늘 기록'), findsOneWidget);

    await tester.tap(find.text('오늘 기록'));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryFormPage), findsOneWidget);
  });

  testWidgets('저장된 초안은 홈 카드에 표시하고 명시적으로 이어서 작성한다', (tester) async {
    final now = DateTime.now();
    final draft = RecordDraftEntity(
      draftId: 'draft-1',
      draftKind: 'createRecord',
      recordType: 'diary',
      payloadSchemaVersion: DiaryDraftPayload.schemaVersion,
      fieldPayloadJson: const DiaryDraftPayload(
        inputMode: 'simple',
        title: '',
        rawText: '작성 중인 메모',
        summary: '',
        activities: [],
      ).encode(),
      createdAt: now,
      lastSavedAt: now,
    );

    await tester.pumpWidget(_buildApp(drafts: [draft]));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryDemoPage), findsOneWidget);
    expect(find.byType(DiaryFormPage), findsNothing);
    expect(find.text('작성 중인 기록 1개'), findsOneWidget);

    await tester.tap(find.text('이어서 작성'));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryFormPage), findsOneWidget);
    expect(find.text('작성 중인 메모'), findsOneWidget);
  });
}
