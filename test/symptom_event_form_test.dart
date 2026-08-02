import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/symptom_record.dart';
import 'package:mlmd/features/events/presentation/symptom_event_form.dart';
import 'package:mlmd/l10n/app_localizations.dart';

void main() {
  Widget localized(Widget child) => MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('지속형 콧물 증상을 선택하여 onset과 정도를 포함해 저장한다', (tester) async {
    SymptomFormResult? result;
    final occurredAt = DateTime(2026, 7, 24, 14, 40);

    await tester.pumpWidget(
      localized(
        SymptomEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (value) => result = value,
        ),
      ),
    );

    // Select 콧물 chip
    await tester.tap(find.byKey(const Key('symptom-chip-runnyNose')));
    await tester.pumpAndSettle();

    // Select onset option (오늘부터)
    await tester.tap(find.byKey(const Key('onset-today-chip')));
    await tester.pumpAndSettle();

    // Select severity (약함)
    await tester.tap(find.byKey(const Key('severity-mild-chip')));
    await tester.pumpAndSettle();

    // Enter note
    await tester.enterText(
      find.byKey(const Key('symptom-note-input')),
      '맑은 콧물',
    );
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.byKey(const Key('save-symptom-btn')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.symptomName, '콧물');
    expect(result?.record.kind, SymptomKind.continuous);
    expect(result?.record.severity, SymptomSeverity.mild);
    expect(result?.record.note, '맑은 콧물');
    expect(result?.details, '시작 · 약함 · 맑은 콧물');
  });

  testWidgets('발생형 구토 증상을 선택하여 양과 상황을 저장한다', (tester) async {
    SymptomFormResult? result;
    final occurredAt = DateTime(2026, 7, 24, 14, 40);

    await tester.pumpWidget(
      localized(
        SymptomEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (value) => result = value,
        ),
      ),
    );

    // Select 구토 chip
    await tester.tap(find.byKey(const Key('symptom-chip-vomiting')));
    await tester.pumpAndSettle();

    // Select amount (보통)
    await tester.tap(find.byKey(const Key('amount-moderate-chip')));
    await tester.pumpAndSettle();

    // Select context (식사 후)
    await tester.tap(find.byKey(const Key('context-after-meal-chip')));
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.byKey(const Key('save-symptom-btn')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.symptomName, '구토');
    expect(result?.record.kind, SymptomKind.episodic);
    expect(result?.record.amount, SymptomAmount.moderate);
    expect(result?.record.context, SymptomContext.afterMeal);
    expect(result?.details, '보통 · 식사 후');
  });

  testWidgets('진행 중인 콧물 에피소드의 상태 변화(나아졌어요)를 추가 저장한다', (tester) async {
    SymptomFormResult? result;
    final occurredAt = DateTime(2026, 7, 24, 14, 40);
    final activeEpisode = SymptomRecord(
      symptomId: 'runnyNose',
      symptomName: '콧물',
      kind: SymptomKind.continuous,
      episodeId: 'ep-active-1',
      status: SymptomEpisodeStatus.active,
      occurredAt: occurredAt.subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(
      localized(
        SymptomEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (value) => result = value,
          activeEpisodes: [activeEpisode],
        ),
      ),
    );

    // Select 콧물 chip
    await tester.tap(find.byKey(const Key('symptom-chip-runnyNose')));
    await tester.pumpAndSettle();

    // Select trend (나아졌어요)
    await tester.tap(find.byKey(const Key('trend-improved-chip')));
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.byKey(const Key('save-symptom-btn')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.record.episodeId, 'ep-active-1');
    expect(result?.record.trend, SymptomTrend.improved);
    expect(result?.details, '나아졌어요');
  });

  testWidgets('기타 직접 입력으로 사용자 정의 증상을 생성한다', (tester) async {
    SymptomFormResult? result;
    final occurredAt = DateTime(2026, 7, 24, 14, 40);

    await tester.pumpWidget(
      localized(
        SymptomEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (value) => result = value,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('custom-symptom-input')),
      '어지러움',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('custom-episodic-btn')));
    await tester.tap(find.byKey(const Key('custom-episodic-btn')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('save-symptom-btn')));
    await tester.tap(find.byKey(const Key('save-symptom-btn')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.symptomName, '어지러움');
    expect(result?.record.kind, SymptomKind.episodic);
    expect(result?.record.symptomId, 'custom:어지러움');
  });
}
