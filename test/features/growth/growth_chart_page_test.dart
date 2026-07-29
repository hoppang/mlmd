import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/growth_measurement_record.dart';
import 'package:mlmd/features/growth/presentation/growth_chart_page.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/diary_entity.dart';

void main() {
  Widget app(List<DiaryEntity> diaries) => MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: GrowthChartPage(diaries: diaries),
  );

  testWidgets('shows empty personal chart without inventing values', (
    tester,
  ) async {
    await tester.pumpWidget(app(const []));

    expect(find.byKey(const Key('growth-chart-empty')), findsOneWidget);
    expect(find.text('아직 이 그래프에 표시할 측정값이 없습니다.'), findsOneWidget);
  });

  testWidgets('switches metrics and explains unavailable reference data', (
    tester,
  ) async {
    final measuredAt = DateTime(2026, 7, 20);
    final diary = DiaryEntity(
      date: measuredAt,
      title: '',
      summary: '',
      content: '',
      lastModified: measuredAt,
    );
    diary.activities.add(
      ActivityEntity(
        recordId: 'growth-1',
        type: '성장 측정',
        time: measuredAt,
        details: '',
        structuredDataJson: GrowthMeasurementRecord(
          occurredAt: measuredAt,
          heightCm: 65.1,
          weightKg: 8.2,
        ).encode(),
        lastModified: measuredAt,
      ),
    );

    await tester.pumpWidget(app([diary]));

    expect(find.byKey(const Key('personal-growth-chart')), findsOneWidget);
    expect(find.textContaining('65.1cm'), findsOneWidget);

    await tester.tap(find.text('몸무게'));
    await tester.pump();
    expect(find.textContaining('8.2kg'), findsOneWidget);

    final referenceToggle = find.byKey(const Key('growth-reference-toggle'));
    await tester.ensureVisible(referenceToggle);
    await tester.tap(referenceToggle);
    await tester.pumpAndSettle();
    expect(find.textContaining('현재는 개인 추세만 표시합니다.'), findsOneWidget);
    expect(find.textContaining('약 42백분위'), findsNothing);
  });
}
