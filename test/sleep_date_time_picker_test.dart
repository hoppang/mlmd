import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('Android에서도 휠의 값을 직접 입력해 적용한다', (tester) async {
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

    expect(find.byKey(const Key('sleep-date-time-page')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.byKey(const Key('sleep-hour-wheel-selected')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('sleep-hour-wheel-input')),
      '13',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sleep-minute-wheel-selected')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('sleep-minute-wheel-input')),
      '39',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-sleep-date-time')));
    await tester.pumpAndSettle();

    expect(result, DateTime(now.year, now.month, now.day, 13, 39));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('시간과 분 보정 버튼을 표시하지 않는다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day, 0, 5);
    await tester.pumpWidget(
      launcher(
        initialValue: initial,
        firstDate: initial.subtract(const Duration(days: 2)),
        lastDate: initial.add(const Duration(days: 1)),
        onResult: (_) {},
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('adjust-sleep-hour--1')), findsNothing);
    expect(find.byKey(const Key('adjust-sleep-hour-1')), findsNothing);
    expect(find.byKey(const Key('adjust-sleep-time--10')), findsNothing);
    expect(find.byKey(const Key('adjust-sleep-time--1')), findsNothing);
    expect(find.byKey(const Key('adjust-sleep-time-1')), findsNothing);
    expect(find.byKey(const Key('adjust-sleep-time-10')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows 가로 화면에서도 달력과 시간 휠을 표시한다', (tester) async {
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

    expect(find.byKey(const Key('sleep-date-time-page')), findsOneWidget);
    expect(find.byKey(const Key('sleep-date-calendar')), findsOneWidget);
    expect(find.byKey(const Key('sleep-hour-input')), findsNothing);
    expect(find.byKey(const Key('sleep-minute-input')), findsNothing);
    expect(find.byKey(const Key('sleep-hour-wheel')), findsOneWidget);
    expect(find.byKey(const Key('sleep-minute-wheel')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows 세로 화면에서는 시간만 보이고 달력을 펼칠 수 있다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(760, 1000);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day - 10, 12, 30);

    await tester.pumpWidget(
      launcher(
        initialValue: initial,
        firstDate: initial.subtract(const Duration(days: 30)),
        lastDate: now.add(const Duration(days: 1)),
        onResult: (_) {},
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-date-calendar')), findsNothing);
    expect(find.byKey(const Key('sleep-hour-wheel')), findsOneWidget);
    expect(find.byKey(const Key('sleep-minute-wheel')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('sleep-hour-wheel-viewport'))).height,
      180,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('sleep-minute-wheel-viewport')))
          .height,
      180,
    );
    expect(find.byKey(const Key('sleep-hour-input')), findsNothing);
    expect(find.byKey(const Key('sleep-minute-input')), findsNothing);

    await tester.tap(find.byKey(const Key('sleep-date-other')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-date-calendar')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android 가로 화면에서는 달력과 시간 휠을 나란히 표시한다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 760);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day, 12, 30);

    await tester.pumpWidget(
      launcher(
        initialValue: initial,
        firstDate: initial.subtract(const Duration(days: 30)),
        lastDate: initial.add(const Duration(days: 1)),
        onResult: (_) {},
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-date-calendar')), findsOneWidget);
    expect(find.byKey(const Key('sleep-hour-input')), findsNothing);
    expect(find.byKey(const Key('sleep-minute-input')), findsNothing);
    expect(find.byKey(const Key('sleep-hour-wheel')), findsOneWidget);
    expect(find.byKey(const Key('sleep-minute-wheel')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('마우스 휠 한 번은 시간을 한 단계만 변경한다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(760, 1000);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day, 12, 10);
    DateTime? result;

    await tester.pumpWidget(
      launcher(
        initialValue: initial,
        firstDate: initial.subtract(const Duration(days: 1)),
        lastDate: initial.add(const Duration(days: 1)),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    final minuteWheel = find.byKey(const Key('sleep-minute-wheel-viewport'));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(minuteWheel),
        scrollDelta: const Offset(0, 240),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-sleep-date-time')));
    await tester.pumpAndSettle();

    expect(result, initial.add(const Duration(minutes: 1)));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('PC 휠 입력에서 Tab으로 시를 확정하고 분으로 이동한다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(760, 1000);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day, 12, 10);
    DateTime? result;

    await tester.pumpWidget(
      launcher(
        initialValue: initial,
        firstDate: initial.subtract(const Duration(days: 1)),
        lastDate: initial.add(const Duration(days: 1)),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sleep-hour-wheel-selected')));
    await tester.pump();
    final hourInput = find.byKey(const Key('sleep-hour-wheel-input'));
    expect(hourInput, findsOneWidget);
    await tester.enterText(hourInput, '14');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-hour-wheel-input')), findsNothing);
    final minuteInput = find.byKey(const Key('sleep-minute-wheel-input'));
    expect(minuteInput, findsOneWidget);
    await tester.enterText(minuteInput, '07');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sleep-minute-wheel-input')), findsNothing);

    await tester.tap(find.byKey(const Key('apply-sleep-date-time')));
    await tester.pumpAndSettle();

    expect(result, DateTime(now.year, now.month, now.day, 14, 7));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('시 입력 중 분을 직접 누르면 시를 확정하고 분 입력을 연다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(760, 1000);
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day, 12, 10);
    DateTime? result;

    await tester.pumpWidget(
      launcher(
        initialValue: initial,
        firstDate: initial.subtract(const Duration(days: 1)),
        lastDate: initial.add(const Duration(days: 1)),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sleep-hour-wheel-selected')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('sleep-hour-wheel-input')),
      '14',
    );
    await tester.tap(find.byKey(const Key('sleep-minute-wheel-selected')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-hour-wheel-input')), findsNothing);
    expect(find.byKey(const Key('sleep-minute-wheel-input')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-sleep-date-time')));
    await tester.pumpAndSettle();

    expect(result, DateTime(now.year, now.month, now.day, 14, 10));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('휠 입력이 선택 가능 시각을 넘으면 적용할 수 없다', (tester) async {
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

    await tester.tap(find.byKey(const Key('sleep-minute-wheel-selected')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('sleep-minute-wheel-input')),
      '57',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('apply-sleep-date-time')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('sleep-minute-wheel-selected')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('sleep-minute-wheel-input')),
      '52',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-sleep-date-time')));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 8, 1, 12, 52));
    debugDefaultTargetPlatformOverride = null;
  });
}
