import 'package:flutter/material.dart';
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
          onChangeTime: () {},
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
}
