import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/temperature_record.dart';
import 'package:mlmd/features/events/presentation/medical_guidance_widgets.dart';
import 'package:mlmd/features/events/presentation/temperature_event_form.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/models/activity_entity.dart';

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

  testWidgets('체온은 소수점 한 자리와 선택 측정 부위를 구조화해 저장한다', (tester) async {
    TemperatureFormResult? result;
    final occurredAt = DateTime(2026, 7, 24, 14, 40);
    await tester.pumpWidget(
      localized(
        TemperatureEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onOccurredAtChanged: (_) {},
          onSave: (value) => result = value,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('temperature-value')), '38.2');
    await tester.tap(find.byKey(const Key('temperature-site-forehead')));
    await tester.enterText(find.byKey(const Key('temperature-note')), '저녁 측정');
    await tester.ensureVisible(find.byKey(const Key('save-quick-record')));
    await tester.tap(find.byKey(const Key('save-quick-record')));

    expect(result?.record.celsius, 38.2);
    expect(result?.record.measurementSite, TemperatureMeasurementSite.forehead);
    expect(result?.record.occurredAt, occurredAt);
    expect(result?.details, '38.2°C · 이마 · 저녁 측정');
  });

  testWidgets('공식 자료 열기 실패를 안내하고 상세를 유지한다', (tester) async {
    final occurredAt = DateTime(2026, 7, 24, 14, 40);
    final activity = ActivityEntity(
      type: '체온',
      time: occurredAt,
      details: '38.2°C · 이마',
      structuredDataJson: TemperatureRecord(
        celsius: 38.2,
        occurredAt: occurredAt,
        measurementSite: TemperatureMeasurementSite.forehead,
      ).encode(),
      lastModified: occurredAt,
    );
    Uri? opened;

    await tester.pumpWidget(
      localized(
        SingleChildScrollView(
          child: MedicalGuidanceSection(
            activity: activity,
            launchExternal: (uri) async {
              opened = uri;
              return false;
            },
          ),
        ),
      ),
    );

    expect(find.text('관련 공식 자료'), findsOneWidget);
    expect(find.text('American Academy of Pediatrics (US)'), findsOneWidget);
    expect(find.text('주의 필요'), findsNothing);
    await tester.tap(find.byKey(const Key('open-guidance-aap-temperature-38')));
    await tester.pump();

    expect(opened?.scheme, 'https');
    expect(find.byKey(const Key('medical-guidance-section')), findsOneWidget);
    expect(find.textContaining('공식 자료를 열지 못했어요'), findsOneWidget);
  });

  testWidgets('temperature wheel and inline date time are saved together', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final now = DateTime.now();
    var occurredAt = DateTime(now.year, now.month, now.day, 14, 40);
    TemperatureFormResult? result;

    await tester.pumpWidget(
      localized(
        StatefulBuilder(
          builder: (context, setHarnessState) => TemperatureEventForm(
            occurredAt: occurredAt,
            saving: false,
            error: null,
            onBack: () {},
            onOccurredAtChanged: (value) =>
                setHarnessState(() => occurredAt = value),
            onSave: (value) => result = value,
            initialRecord: TemperatureRecord(
              celsius: 37.2,
              occurredAt: occurredAt,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('temperature-whole-wheel-selected')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('temperature-whole-wheel-input')),
      '38',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('temperature-tenth-wheel-input')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('temperature-tenth-wheel-input')),
      '3',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('quick-record-time')));
    await tester.tap(find.byKey(const Key('quick-record-time')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('temperature-date-time-editor')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('temperature-date-yesterday')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-temperature-date-time')), findsNothing);

    final save = find.byKey(const Key('save-quick-record'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();

    final yesterday = DateUtils.dateOnly(now).subtract(const Duration(days: 1));
    expect(result?.record.celsius, 38.3);
    expect(DateUtils.isSameDay(result?.record.occurredAt, yesterday), isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('temperature input is capped at 43 degrees Celsius', (
    tester,
  ) async {
    TemperatureFormResult? result;
    final occurredAt = DateTime(2026, 8, 10, 14, 40);
    await tester.pumpWidget(
      localized(
        TemperatureEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onOccurredAtChanged: (_) {},
          onSave: (value) => result = value,
        ),
      ),
    );

    final field = find.byKey(const Key('temperature-value'));
    final save = find.byKey(const Key('save-quick-record'));
    await tester.enterText(field, '43.1');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();

    expect(result, isNull);
    expect(find.text('체온은 43.0℃ 이하로 입력해 주세요.'), findsOneWidget);

    await tester.enterText(field, '43.0');
    await tester.tap(save);
    await tester.pump();
    expect(result?.record.celsius, 43.0);

    final wholeViewport = find.byKey(
      const Key('temperature-whole-wheel-viewport'),
    );
    expect(
      find.descendant(of: wholeViewport, matching: find.text('44')),
      findsNothing,
    );

    final tenthViewport = find.byKey(
      const Key('temperature-tenth-wheel-viewport'),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(tenthViewport),
        scrollDelta: const Offset(0, 20),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, '43.0');
  });
}
