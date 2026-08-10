import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/medication_record.dart';
import 'package:mlmd/features/events/presentation/medication_event_form.dart';
import 'package:mlmd/l10n/app_localizations.dart';

void main() {
  testWidgets('medication choices reflect the streamlined catalog', (
    tester,
  ) async {
    await _pumpForm(tester);

    expect(find.text('감기약'), findsOneWidget);
    expect(find.text('항바이러스제'), findsOneWidget);
    expect(find.text('연고·크림'), findsNothing);
    expect(find.text('안약·이비인후과 용제'), findsNothing);
  });

  testWidgets('all medication types use recent notes without a route', (
    tester,
  ) async {
    MedicationFormResult? saved;
    await _pumpForm(
      tester,
      recentMedicationNotes: const ['비타민D', '유산균'],
      onSave: (result) => saved = result,
    );

    expect(find.text('투여 방식'), findsNothing);
    expect(find.text('최근 입력 메모'), findsOneWidget);
    await tester.ensureVisible(find.text('비타민D'));
    await tester.tap(find.text('비타민D'));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('medication-note-input')))
          .controller!
          .text,
      '비타민D',
    );

    await tester.ensureVisible(find.byKey(const Key('save-medication-btn')));
    await tester.tap(find.byKey(const Key('save-medication-btn')));
    expect(saved, isNotNull);
    expect(saved!.record.category, MedicationCategory.antipyretic);
    expect(saved!.record.route, MedicationRoute.unknown);
    expect(saved!.record.note, '비타민D');
  });
}

Future<void> _pumpForm(
  WidgetTester tester, {
  List<String> recentMedicationNotes = const [],
  ValueChanged<MedicationFormResult>? onSave,
}) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MedicationEventForm(
        occurredAt: DateTime(2026, 8, 10, 9),
        saving: false,
        error: null,
        onBack: () {},
        onChangeTime: () {},
        onSave: onSave ?? (_) {},
        recentMedicationNotes: recentMedicationNotes,
      ),
    ),
  ),
);
