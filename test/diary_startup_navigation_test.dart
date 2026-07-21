import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/diary/application/diary_draft_payload.dart';
import 'package:mlmd/features/diary/application/diary_list_notifier.dart';
import 'package:mlmd/features/diary/presentation/diary_form_page.dart';
import 'package:mlmd/features/diary/presentation/diary_home_page.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/repositories/record_draft_repository.dart';
import 'package:mlmd/services/llm_diary_service.dart';

class _TestDiaryListNotifier extends DiaryListNotifier {
  _TestDiaryListNotifier(this.diaries);

  final List<DiaryEntity> diaries;
  DateTime? updatedOccurredAt;
  List<ActivitySummary>? updatedActivities;

  @override
  List<DiaryEntity> build() => diaries;

  @override
  Future<void> updateDiary(
    DiaryEntity diary,
    String newTitle,
    String newSummary,
    String newContent, {
    required DateTime occurredAt,
    List<ActivitySummary> activitySummaries = const [],
    String? consumedDraftId,
  }) async {
    updatedOccurredAt = occurredAt;
    updatedActivities = activitySummaries;
  }
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
  _TestDiaryListNotifier? diaryNotifier,
}) {
  return ProviderScope(
    overrides: [
      diaryListProvider.overrideWith(
        () => diaryNotifier ?? _TestDiaryListNotifier(diaries),
      ),
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
      lastModified: DateTime(1999, 1, 1),
    );

    await tester.pumpWidget(_buildApp(diaries: [diary]));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryDemoPage), findsOneWidget);
    expect(find.byType(DiaryFormPage), findsNothing);
    expect(find.text('오늘 기록'), findsOneWidget);
    final homeContext = tester.element(find.byType(DiaryDemoPage));
    final displayedDate = MaterialLocalizations.of(
      homeContext,
    ).formatShortDate(now);
    expect(find.text(displayedDate), findsOneWidget);

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

  testWidgets('기록 수정 시 메모와 이벤트의 발생 시각을 보존한다', (tester) async {
    final recordTime = DateTime(2026, 7, 20, 14, 30);
    final exactEventTime = DateTime(2026, 7, 20, 13, 10);
    final diary = DiaryEntity(
      id: 2,
      recordId: 'time-record',
      date: recordTime,
      title: '시각 보존 기록',
      content: '수정해도 발생 시각은 유지',
      lastModified: DateTime(2026, 7, 21),
    );
    diary.activities.addAll([
      ActivityEntity(
        type: '투약',
        time: exactEventTime,
        details: '해열제',
        lastModified: DateTime(2026, 7, 20, 13, 11),
      ),
      ActivityEntity(
        type: '수유',
        time: recordTime,
        timePrecision: ActivityEntity.timePrecisionUnknown,
        details: '여러 번',
        lastModified: DateTime(2026, 7, 20, 15),
      ),
    ]);
    final notifier = _TestDiaryListNotifier([diary]);

    await tester.pumpWidget(
      _buildApp(diaries: [diary], diaryNotifier: notifier),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('시각 보존 기록'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, '수정'));
    await tester.pumpAndSettle();

    expect(notifier.updatedOccurredAt, recordTime);
    expect(notifier.updatedActivities, hasLength(2));
    expect(notifier.updatedActivities![0].occurredAt, exactEventTime);
    expect(notifier.updatedActivities![1].occurredAt, isNull);
  });
}
