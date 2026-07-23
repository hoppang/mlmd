import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/diary/application/diary_draft_payload.dart';
import 'package:mlmd/core/layout/adaptive_content_frame.dart';
import 'package:mlmd/features/diary/application/diary_list_notifier.dart';
import 'package:mlmd/features/diary/presentation/diary_form_page.dart';
import 'package:mlmd/features/diary/presentation/diary_home_page.dart';
import 'package:mlmd/features/search/domain/hybrid_search_query.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/ai_summary_entity.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/repositories/diary_repository.dart';
import 'package:mlmd/repositories/record_draft_repository.dart';
import 'package:mlmd/repositories/profile_repository.dart';
import 'package:mlmd/services/llm_diary_service.dart';
import 'package:mlmd/features/summaries/application/ai_summary_notifier.dart';
import 'package:mlmd/features/summaries/domain/summary_source_snapshot.dart';
import 'package:mlmd/repositories/ai_summary_repository.dart';
import 'support/test_profile_repository.dart';

class _TestDiaryListNotifier extends DiaryListNotifier {
  _TestDiaryListNotifier(
    this.diaries, {
    this.searchResults = const [],
    this.searchError,
    this.activitySaveError,
  });

  final List<DiaryEntity> diaries;
  final List<DiarySearchResult> searchResults;
  final Object? searchError;
  final Object? activitySaveError;
  DateTime? updatedOccurredAt;
  List<ActivitySummary>? updatedActivities;
  bool addedDiary = false;
  String? addedTitle;
  String? addedSummary;
  String? addedContent;
  HybridSearchQuery? searchedQuery;
  String? addedActivityType;
  String? addedActivityDetails;
  DateTime? addedActivityOccurredAt;

  @override
  bool get isSemanticSearchAvailable => true;

  @override
  bool get hasPendingSearchEmbeddings => false;

  @override
  List<DiaryEntity> build() => diaries;

  @override
  Future<List<DiarySearchResult>> searchRecords(
    HybridSearchQuery query, {
    int limit = 50,
  }) async {
    searchedQuery = query;
    if (searchError != null) throw searchError!;
    return searchResults.take(limit).toList(growable: false);
  }

  @override
  Future<void> addDiary(
    String title,
    String summary,
    String content, {
    required DateTime occurredAt,
    List<ActivitySummary> activitySummaries = const [],
    String? consumedDraftId,
  }) async {
    addedDiary = true;
    addedTitle = title;
    addedSummary = summary;
    addedContent = content;
  }

  @override
  Future<void> addActivityRecord({
    required String type,
    required String details,
    required DateTime occurredAt,
  }) async {
    if (activitySaveError != null) throw activitySaveError!;
    addedActivityType = type;
    addedActivityDetails = details;
    addedActivityOccurredAt = occurredAt;
  }

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

class _TestAiSummaryNotifier extends AiSummaryNotifier {
  _TestAiSummaryNotifier({this.candidateText, this.automaticAvailable = false});

  final String? candidateText;
  final bool automaticAvailable;
  List<SummaryEvidence> _savedEvidence = const [];
  bool? lastAutomatic;

  @override
  List<AiSummaryEntity> build() => const [];

  @override
  bool get canGenerateAutomatically => automaticAvailable;

  @override
  Future<SummaryGenerationCandidate> generateCandidate(
    SummarySourceSnapshot snapshot, {
    required String languageCode,
  }) async => candidateText == null
      ? const SummaryGenerationCandidate(
          status: SummaryGenerationStatus.unavailable,
        )
      : SummaryGenerationCandidate(
          status: SummaryGenerationStatus.success,
          text: candidateText,
        );

  @override
  AiSummaryEntity saveCandidate(
    SummarySourceSnapshot snapshot,
    String text, {
    required bool automatic,
  }) {
    _savedEvidence = snapshot.evidence;
    lastAutomatic = automatic;
    final entity = AiSummaryEntity(
      id: 1,
      summaryId: '${snapshot.periodType.name}:test',
      periodType: snapshot.periodType == SummaryPeriodType.daily
          ? AiSummaryEntity.periodDaily
          : AiSummaryEntity.periodWeekly,
      periodStart: snapshot.start,
      periodEndExclusive: snapshot.endExclusive,
      generatedText: text,
      generatedAt: DateTime.now(),
      cutoffAt: snapshot.cutoffAt!,
      sourceFingerprint: snapshot.sourceFingerprint,
      evidenceJson: '[]',
      automatic: automatic,
      modelVersion: 'test',
    );
    state = [entity];
    return entity;
  }

  @override
  List<SummaryEvidence> evidenceFor(AiSummaryEntity summary) => _savedEvidence;

  @override
  AiSummaryFreshness freshness(
    AiSummaryEntity summary,
    SummarySourceSnapshot snapshot,
  ) => AiSummaryFreshness.fresh;
}

class _TestWeeklyAiAutoSummaryNotifier extends WeeklyAiAutoSummaryNotifier {
  _TestWeeklyAiAutoSummaryNotifier(this.enabled);

  final bool enabled;

  @override
  bool build() => enabled;
}

class _TestDiaryAnalysisService implements DiaryAnalysisService {
  _TestDiaryAnalysisService({
    required this.isAvailable,
    required this.onAnalyze,
  });

  @override
  final bool isAvailable;
  final Future<DiaryAnalysisOutcome> Function(
    String content,
    String languageCode,
  )
  onAnalyze;
  int callCount = 0;

  @override
  Future<DiaryAnalysisOutcome> analyze(
    String content, {
    String languageCode = 'ko',
  }) {
    callCount += 1;
    return onAnalyze(content, languageCode);
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
  _TestAiSummaryNotifier? summaryNotifier,
  bool weeklyAutoSummary = false,
  DiaryAnalysisService? analysisService,
  TextScaler? textScaler,
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
      profileRepositoryProvider.overrideWithValue(TestProfileRepository()),
      aiSummaryListProvider.overrideWith(
        () => summaryNotifier ?? _TestAiSummaryNotifier(),
      ),
      weeklyAiAutoSummaryProvider.overrideWith(
        () => _TestWeeklyAiAutoSummaryNotifier(weeklyAutoSummary),
      ),
      if (analysisService != null)
        diaryAnalysisServiceProvider.overrideWithValue(analysisService),
    ],
    child: MaterialApp(
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
      locale: const Locale('ko'),
      home: const DiaryDemoPage(),
    ),
  );
}

void main() {
  testWidgets('기록 시트에서 빠른 기록과 최근 사용, 카테고리를 제공한다', (tester) async {
    final now = DateTime.now();
    final diary = DiaryEntity(
      id: 1,
      recordId: 'record-entry-source',
      date: now,
      title: '',
      content: '',
      lastModified: now,
    );
    diary.activities.addAll([
      ActivityEntity(
        type: '이유식·식사',
        time: now.subtract(const Duration(hours: 1)),
        details: '120g',
        lastModified: now,
      ),
      ActivityEntity(
        type: '수유',
        time: now,
        details: '180mL',
        lastModified: now,
      ),
    ]);
    final notifier = _TestDiaryListNotifier([diary]);

    await tester.pumpWidget(
      _buildApp(diaries: [diary], diaryNotifier: notifier),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-entry-button')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('빠른 기록'), findsOneWidget);
    expect(find.text('최근 사용'), findsOneWidget);
    expect(find.text('이유식·식사 · 120g'), findsOneWidget);
    expect(find.text('수유 · 180mL'), findsNothing);

    await tester.tap(find.byKey(const Key('event-category-healthMedical')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-event-medication')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-record-feeding')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-record-details')),
      '200mL',
    );
    await tester.tap(find.byKey(const Key('save-quick-record')));
    await tester.pumpAndSettle();

    expect(notifier.addedActivityType, '수유');
    expect(notifier.addedActivityDetails, '200mL');
    expect(notifier.addedActivityOccurredAt, isNotNull);
    expect(find.text('수유 기록을 저장했어요.'), findsOneWidget);
  });

  testWidgets('빠른 기록 저장 실패 시 입력을 유지하고 다시 시도할 수 있다', (tester) async {
    final notifier = _TestDiaryListNotifier(
      const [],
      activitySaveError: StateError('save failed'),
    );
    await tester.pumpWidget(_buildApp(diaryNotifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record-entry-button')));
    await tester.pumpAndSettle();
    expect(find.text('최근 사용'), findsNothing);
    await tester.tap(find.byKey(const Key('quick-record-sleep')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-record-details')),
      '낮잠 시작',
    );
    await tester.tap(find.byKey(const Key('save-quick-record')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record-entry-form')), findsOneWidget);
    expect(find.text('낮잠 시작'), findsOneWidget);
    expect(find.text('기록을 저장하지 못했어요. 입력 내용은 그대로 유지됩니다.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-quick-record')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Windows에서도 같은 기록 선택 내용을 중앙 대화상자로 연다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record-entry-button')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('빠른 기록'), findsOneWidget);
    expect(find.text('전체 카테고리'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

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
    expect(find.text('오늘 기록'), findsAtLeastNWidgets(1));
    final homeContext = tester.element(find.byType(DiaryDemoPage));
    final displayedDate = MaterialLocalizations.of(
      homeContext,
    ).formatFullDate(now);
    expect(find.text(displayedDate), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('today-memo:1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today-record-edit-button')));
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

    final notifier = _TestDiaryListNotifier(const []);
    await tester.pumpWidget(
      _buildApp(drafts: [draft], diaryNotifier: notifier),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DiaryDemoPage), findsOneWidget);
    expect(find.byType(DiaryFormPage), findsNothing);
    expect(find.text('작성 중인 기록 1개'), findsOneWidget);

    await tester.tap(find.text('이어서 작성'));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryFormPage), findsOneWidget);
    expect(find.text('작성 중인 메모'), findsOneWidget);

    final aiButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('ai-analyze-button')),
    );
    expect(aiButton.onPressed, isNull);
    expect(
      find.text('현재 AI를 사용할 수 없어요. 원문 기록은 그대로 저장할 수 있어요.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FloatingActionButton, '저장'));
    await tester.pumpAndSettle();

    expect(notifier.addedDiary, isTrue);
    expect(notifier.addedTitle, '작성 중인 메모');
    expect(notifier.addedContent, '작성 중인 메모');
    expect(find.byType(DiaryDemoPage), findsOneWidget);
    expect(find.text('작성 중인 기록 1개'), findsNothing);
  });

  testWidgets('AI 정리는 진행 상태를 표시하고 성공해도 원문을 보존한다', (tester) async {
    final now = DateTime.now();
    final draft = RecordDraftEntity(
      draftId: 'draft-ai-success',
      draftKind: 'createRecord',
      recordType: 'diary',
      payloadSchemaVersion: DiaryDraftPayload.schemaVersion,
      fieldPayloadJson: const DiaryDraftPayload(
        inputMode: 'simple',
        title: '',
        rawText: 'AI에게 전달할 원문',
        summary: '',
        activities: [],
      ).encode(),
      createdAt: now,
      lastSavedAt: now,
    );
    final completion = Completer<DiaryAnalysisOutcome>();
    final service = _TestDiaryAnalysisService(
      isAvailable: true,
      onAnalyze: (_, _) => completion.future,
    );
    final notifier = _TestDiaryListNotifier(const []);

    await tester.pumpWidget(
      _buildApp(
        drafts: [draft],
        diaryNotifier: notifier,
        analysisService: service,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이어서 작성'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-analyze-button')));
    await tester.pump();

    expect(find.text('AI가 기록을 정리하고 있어요…'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('ai-analyze-button')))
          .onPressed,
      isNull,
    );
    expect(find.text('AI에게 전달할 원문'), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(
            find.widgetWithText(FloatingActionButton, '저장'),
          )
          .onPressed,
      isNotNull,
    );

    completion.complete(
      const DiaryAnalysisOutcome.success(
        DiaryExtractionResult(title: 'AI 제목', summary: 'AI 요약', activities: []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 정리 결과를 적용했어요. 입력한 원문은 그대로 보존됩니다.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FloatingActionButton, '저장'));
    await tester.pumpAndSettle();

    expect(service.callCount, 1);
    expect(notifier.addedTitle, 'AI 제목');
    expect(notifier.addedSummary, 'AI 요약');
    expect(notifier.addedContent, 'AI에게 전달할 원문');
  });

  testWidgets('AI 정리 실패 후 원문을 유지하고 다시 시도할 수 있다', (tester) async {
    final now = DateTime.now();
    final draft = RecordDraftEntity(
      draftId: 'draft-ai-failure',
      draftKind: 'createRecord',
      recordType: 'diary',
      payloadSchemaVersion: DiaryDraftPayload.schemaVersion,
      fieldPayloadJson: const DiaryDraftPayload(
        inputMode: 'simple',
        title: '',
        rawText: '실패해도 남을 원문',
        summary: '',
        activities: [],
      ).encode(),
      createdAt: now,
      lastSavedAt: now,
    );
    final service = _TestDiaryAnalysisService(
      isAvailable: true,
      onAnalyze: (_, _) async => const DiaryAnalysisOutcome.failed(),
    );

    await tester.pumpWidget(
      _buildApp(drafts: [draft], analysisService: service),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이어서 작성'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-analyze-button')));
    await tester.pumpAndSettle();

    expect(find.text('AI 정리에 실패했어요. 원문은 그대로 유지됩니다.'), findsOneWidget);
    expect(find.text('실패해도 남을 원문'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'AI 정리 다시 시도'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('ai-analyze-button')));
    await tester.tap(find.byKey(const Key('ai-analyze-button')));
    await tester.pumpAndSettle();

    expect(service.callCount, 2);
  });

  testWidgets('검색 탭은 메모와 이벤트 결과를 이유와 함께 표시하고 읽기 전용으로 연다', (tester) async {
    final older = DiaryEntity(
      id: 21,
      recordId: 'older-search-record',
      date: DateTime(2026, 7, 18, 9),
      title: '투약이 있던 날',
      content: '열이 올라 상태를 살폈다.',
      lastModified: DateTime(2026, 7, 18, 10),
    );
    final medication = ActivityEntity(
      id: 31,
      type: '투약',
      time: DateTime(2026, 7, 18, 9, 30),
      details: '해열제 복용',
      lastModified: DateTime(2026, 7, 18, 9, 31),
    );
    older.activities.add(medication);
    final newer = DiaryEntity(
      id: 22,
      recordId: 'newer-search-record',
      date: DateTime(2026, 7, 20, 14),
      title: '회복 메모',
      content: '오후에는 열이 내렸다.',
      lastModified: DateTime(2026, 7, 20, 15),
    );
    final notifier = _TestDiaryListNotifier(
      [newer, older],
      searchResults: [
        DiarySearchResult(
          diary: older,
          activity: medication,
          reason: DiarySearchMatchReason.activityType,
          relevanceScore: 100,
        ),
        DiarySearchResult(
          diary: newer,
          reason: DiarySearchMatchReason.exactText,
          relevanceScore: 80,
        ),
      ],
    );

    await tester.pumpWidget(
      _buildApp(diaries: [newer, older], diaryNotifier: notifier),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-query-field')), findsNothing);
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();

    expect(find.text('기록 검색'), findsOneWidget);
    expect(find.text('지난 기록을 찾아보세요'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-query-field')), '투약');
    await tester.tap(find.byKey(const Key('search-submit-button')));
    await tester.pumpAndSettle();

    expect(notifier.searchedQuery?.text, isEmpty);
    expect(notifier.searchedQuery?.eventKind, SearchEventKind.medication);
    expect(find.text('검색 결과 2건'), findsOneWidget);
    expect(find.text('이벤트 종류 일치'), findsOneWidget);
    expect(find.text('정확한 문구 일치'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    final activityTitle = find.descendant(
      of: find.byKey(const ValueKey('activity:31')),
      matching: find.text('투약'),
    );
    final memoTitle = find.descendant(
      of: find.byKey(const ValueKey('memo:22')),
      matching: find.text('회복 메모'),
    );
    expect(
      tester.getTopLeft(activityTitle).dy,
      lessThan(tester.getTopLeft(memoTitle).dy),
    );

    await tester.tap(find.byKey(const Key('search-sort-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('최신순').last);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(memoTitle).dy,
      lessThan(tester.getTopLeft(activityTitle).dy),
    );

    await tester.ensureVisible(activityTitle);
    await tester.pumpAndSettle();
    await tester.tap(activityTitle);
    await tester.pumpAndSettle();

    expect(find.text('검색 결과 상세'), findsOneWidget);
    expect(find.text('읽기 전용'), findsOneWidget);
    expect(find.byType(DiaryFormPage), findsNothing);
    expect(find.text('해열제 복용'), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const Key('search-result-edit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryFormPage), findsOneWidget);
  });

  testWidgets('검색 결과가 없으면 검색어를 유지하고 다시 찾는 방법을 안내한다', (tester) async {
    final notifier = _TestDiaryListNotifier(const []);
    await tester.pumpWidget(_buildApp(diaryNotifier: notifier));
    await tester.pumpAndSettle();
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('search-query-field')),
      '없는 기록',
    );
    await tester.tap(find.byKey(const Key('search-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('일치하는 기록이 없어요.'), findsOneWidget);
    expect(find.text('검색 조건은 유지돼요. 기간을 넓히거나 조건을 하나씩 빼보세요.'), findsOneWidget);
    expect(find.text('없는 기록'), findsOneWidget);
  });

  testWidgets('검색 실패를 원본 손상으로 오해하지 않도록 안내하고 재시도를 제공한다', (tester) async {
    final notifier = _TestDiaryListNotifier(
      const [],
      searchError: StateError('test search failure'),
    );
    await tester.pumpWidget(_buildApp(diaryNotifier: notifier));
    await tester.pumpAndSettle();
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('search-query-field')),
      '검색 오류',
    );
    await tester.tap(find.byKey(const Key('search-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('검색하지 못했어요. 원본 기록은 그대로 유지됩니다.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '다시 검색'), findsOneWidget);
  });

  testWidgets('오늘 화면은 현황과 원본 기록을 시간순으로 표시하고 상세에서만 수정한다', (tester) async {
    final now = DateTime.now();
    final diary = DiaryEntity(
      id: 41,
      recordId: 'today-hierarchy-record',
      date: now.subtract(const Duration(hours: 1)),
      title: '오늘 메모',
      summary: '오늘 하루 요약',
      content: '오후 상태를 기록했다.',
      lastModified: now,
    );
    diary.activities.addAll([
      ActivityEntity(
        id: 51,
        type: '투약',
        time: now,
        details: '해열제',
        lastModified: now,
      ),
      ActivityEntity(
        id: 52,
        type: '수유',
        time: now.subtract(const Duration(hours: 2)),
        timePrecision: ActivityEntity.timePrecisionUnknown,
        details: '여러 번',
        lastModified: now,
      ),
    ]);

    await tester.pumpWidget(_buildApp(diaries: [diary]));
    await tester.pumpAndSettle();

    expect(find.text('오늘 현황'), findsOneWidget);
    expect(find.text('수유 · 1'), findsOneWidget);
    expect(find.text('투약 · 1'), findsOneWidget);
    expect(find.text('발생 시각 미상'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('today-activity:51'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('today-memo:41'))).dy,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('today-activity:51')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('읽기 전용'), findsOneWidget);
    expect(find.text('해열제'), findsAtLeastNWidgets(1));
    expect(find.byType(DiaryFormPage), findsNothing);

    await tester.tap(find.byKey(const Key('today-record-edit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryFormPage), findsOneWidget);
  });

  testWidgets('날짜별 탭은 선택한 날짜의 기록만 표시한다', (tester) async {
    final now = DateTime.now();
    final todayDiary = DiaryEntity(
      id: 61,
      recordId: 'date-today-record',
      date: now,
      title: '오늘 날짜 기록',
      content: '오늘 내용',
      lastModified: now,
    );
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayDiary = DiaryEntity(
      id: 62,
      recordId: 'date-yesterday-record',
      date: yesterday,
      title: '어제 날짜 기록',
      content: '어제 내용',
      lastModified: yesterday,
    );

    await tester.pumpWidget(_buildApp(diaries: [todayDiary, yesterdayDiary]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('날짜별'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 날짜 기록'), findsOneWidget);
    expect(find.text('어제 날짜 기록'), findsNothing);

    await tester.tap(find.byKey(const Key('date-previous-button')));
    await tester.pumpAndSettle();

    expect(find.text('오늘 날짜 기록'), findsNothing);
    expect(find.text('어제 날짜 기록'), findsOneWidget);
  });

  testWidgets('날짜별 화면에서 원본 근거가 연결된 AI 일간 정리를 만든다', (tester) async {
    final now = DateTime.now();
    final diary = DiaryEntity(
      id: 71,
      recordId: 'daily-summary-source',
      date: now,
      title: '하루 기록',
      content: '오전에 산책했다.',
      lastModified: now,
    );
    diary.activities.add(
      ActivityEntity(
        id: 72,
        type: '수유',
        time: now.add(const Duration(minutes: 10)),
        details: '120mL',
        lastModified: now,
      ),
    );
    final summaryNotifier = _TestAiSummaryNotifier(
      candidateText: '오전에 산책했고 수유 기록이 남아 있어요.',
    );

    await tester.pumpWidget(
      _buildApp(diaries: [diary], summaryNotifier: summaryNotifier),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('날짜별'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '이날 정리하기'));
    await tester.pumpAndSettle();

    expect(find.text('오전에 산책했고 수유 기록이 남아 있어요.'), findsOneWidget);
    expect(find.textContaining('원본 기록 2개 기준'), findsOneWidget);

    await tester.tap(find.text('근거 기록 보기'));
    await tester.pumpAndSettle();
    expect(find.text('정리에 사용한 원본 기록'), findsOneWidget);
    expect(find.text('하루 기록'), findsAtLeastNWidgets(1));
    expect(find.text('수유'), findsOneWidget);
  });

  testWidgets('완료된 월요일-일요일 주간 정리를 조용히 자동 생성한다', (tester) async {
    final now = DateTime.now();
    final previousSunday = DateUtils.dateOnly(
      now,
    ).subtract(Duration(days: now.weekday));
    final diary = DiaryEntity(
      id: 81,
      recordId: 'weekly-summary-source',
      date: previousSunday.add(const Duration(hours: 12)),
      title: '지난주 기록',
      content: '완료된 주의 원본',
      lastModified: previousSunday,
    );
    final summaryNotifier = _TestAiSummaryNotifier(
      candidateText: '완료된 지난주 기록을 정리했어요.',
      automaticAvailable: true,
    );

    await tester.pumpWidget(
      _buildApp(
        diaries: [diary],
        summaryNotifier: summaryNotifier,
        weeklyAutoSummary: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('날짜별'));
    await tester.pumpAndSettle();
    for (var index = 0; index < now.weekday; index++) {
      await tester.tap(find.byKey(const Key('date-previous-button')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('완료된 지난주 기록을 정리했어요.'), findsOneWidget);
    expect(summaryNotifier.lastAutomatic, isTrue);
  });

  testWidgets('기록 수정 시 메모와 이벤트의 발생 시각을 보존한다', (tester) async {
    final today = DateTime.now();
    final recordTime = DateTime(today.year, today.month, today.day, 14, 30);
    final exactEventTime = DateTime(today.year, today.month, today.day, 13, 10);
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
    await tester.tap(find.byKey(const Key('today-record-edit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, '수정'));
    await tester.pumpAndSettle();

    expect(notifier.updatedOccurredAt, recordTime);
    expect(notifier.updatedActivities, hasLength(2));
    expect(notifier.updatedActivities![0].occurredAt, exactEventTime);
    expect(notifier.updatedActivities![1].occurredAt, isNull);
  });

  testWidgets('넓은 창에서도 오늘 본문은 읽기 가능한 최대 너비를 유지한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveContentFrame), findsWidgets);
    expect(
      tester.getSize(find.byKey(const Key('today-scroll-view'))).width,
      lessThanOrEqualTo(720),
    );
  });

  testWidgets('Ctrl+F는 검색 탭을 열고 검색어 입력에 포커스한다', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('search-query-field'));
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
  });

  testWidgets('Windows에서는 기록 상세를 중앙 대화상자로 연다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final now = DateTime.now();
    final diary = DiaryEntity(
      id: 91,
      recordId: 'windows-detail',
      date: now,
      title: 'Windows 상세',
      content: '같은 상세 내용',
      lastModified: now,
    );

    await tester.pumpWidget(_buildApp(diaries: [diary]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('today-memo:91')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('같은 상세 내용'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('today-record-edit-button')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('큰 글자와 좁은 화면에서도 작성 화면이 넘치지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final diary = DiaryEntity(
      id: 92,
      recordId: 'large-text-form',
      date: now,
      title: '큰 글자 기록',
      content: '큰 글자에서도 보존될 내용',
      lastModified: now,
    );
    diary.activities.add(
      ActivityEntity(
        id: 93,
        type: '투약',
        time: now,
        details: '해열제 복용 상세',
        lastModified: now,
      ),
    );

    await tester.pumpWidget(
      _buildApp(diaries: [diary], textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('today-memo:92')));
    await tester.drag(
      find.byKey(const Key('today-scroll-view')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('today-memo:92')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today-record-edit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryFormPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작성 화면의 Esc는 초안을 보존하는 뒤로 가기와 같은 결과다', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-entry-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('open-detailed-record')));
    await tester.tap(find.byKey(const Key('open-detailed-record')));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryFormPage), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(DiaryDemoPage), findsOneWidget);
    expect(find.byType(DiaryFormPage), findsNothing);
  });

  testWidgets('기록 카드는 읽기 전용 상세 동작을 의미 정보로 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();
    final now = DateTime.now();
    final diary = DiaryEntity(
      id: 94,
      recordId: 'semantic-record',
      date: now,
      title: '의미 있는 기록',
      content: '본문',
      lastModified: now,
    );

    await tester.pumpWidget(_buildApp(diaries: [diary]));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(
      find.byKey(const ValueKey('today-memo:94')),
    );
    expect(node.label, contains('의미 있는 기록'));
    expect(node.label, contains('읽기 전용'));
    expect(node.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });
}
