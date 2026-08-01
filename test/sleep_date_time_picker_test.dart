import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/presentation/sleep_date_time_picker.dart';
import 'package:mlmd/l10n/app_localizations.dart';

void main() {
  Widget launcher({
    required DateTime initialValue,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime?> onResult,
  }) => MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          onPressed: () async {
            onResult(
              await showSleepDateTimePicker(
                context: context,
                title: '시작 시각 수정',
                initialValue: initialValue,
                firstDate: firstDate,
                lastDate: lastDate,
              ),
            );
          },
          child: const Text('열기'),
        ),
      ),
    ),
  );

  testWidgets('Android에서는 바텀시트에서 분을 보정하고 적용한다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day, 12, 30);
    DateTime? result;

    await tester.pumpWidget(
      launcher(
        initialValue: initial,
        firstDate: initial.subtract(const Duration(days: 2)),
        lastDate: initial.add(const Duration(days: 1)),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('adjust-sleep-hour--1')), findsOneWidget);
    expect(find.byKey(const Key('adjust-sleep-hour-1')), findsOneWidget);
    expect(find.text('−10분'), findsOneWidget);
    expect(find.text('−1분'), findsOneWidget);
    expect(find.text('+1분'), findsOneWidget);
    expect(find.text('+10분'), findsOneWidget);
    await tester.tap(find.byKey(const Key('adjust-sleep-hour-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('adjust-sleep-time-10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('adjust-sleep-time--1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('apply-sleep-date-time')));
    await tester.pumpAndSettle();

    expect(result, initial.add(const Duration(hours: 1, minutes: 9)));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('분 보정이 자정을 넘으면 날짜도 함께 바뀐다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day, 0, 5);
    DateTime? result;

    await tester.pumpWidget(
      launcher(
        initialValue: initial,
        firstDate: initial.subtract(const Duration(days: 2)),
        lastDate: initial.add(const Duration(days: 1)),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adjust-sleep-time--10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('apply-sleep-date-time')));
    await tester.pumpAndSettle();

    expect(result, initial.subtract(const Duration(minutes: 10)));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows에서는 달력과 직접 입력을 중앙 대화상자에 표시한다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 760);
    addTearDown(tester.view.reset);
    final initial = DateTime(2026, 8, 1, 12, 30);

    await tester.pumpWidget(
      launcher(
        initialValue: initial,
        firstDate: DateTime(2026, 7, 1),
        lastDate: DateTime(2026, 8, 2, 23, 59),
        onResult: (_) {},
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-date-time-dialog')), findsOneWidget);
    expect(find.byKey(const Key('sleep-date-calendar')), findsOneWidget);
    expect(find.byKey(const Key('sleep-hour-input')), findsOneWidget);
    expect(find.byKey(const Key('sleep-minute-input')), findsOneWidget);
    expect(find.byKey(const Key('sleep-hour-wheel')), findsNothing);
    expect(find.byKey(const Key('sleep-minute-wheel')), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('adjustment clamps to the latest selectable minute', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final initial = DateTime(2026, 8, 1, 12, 47);
    final latest = DateTime(2026, 8, 1, 12, 52, 34);
    DateTime? result;

    await tester.pumpWidget(
      launcher(
        initialValue: initial,
        firstDate: DateTime(2026, 7, 1),
        lastDate: latest,
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    final addTen = find.byKey(const Key('adjust-sleep-time-10'));
    await tester.tap(addTen);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(addTen).onPressed, isNull);
    await tester.tap(find.byKey(const Key('apply-sleep-date-time')));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 8, 1, 12, 52));
    debugDefaultTargetPlatformOverride = null;
  });
}
