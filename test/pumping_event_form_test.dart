import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/pumping_record.dart';
import 'package:mlmd/features/events/presentation/pumping_event_form.dart';
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

  group('PumpingEventForm Widget Tests', () {
    testWidgets('renders pumping event form with default fields', (
      tester,
    ) async {
      final occurredAt = DateTime(2026, 7, 26, 14, 20);

      await tester.pumpWidget(
        localized(
          PumpingEventForm(
            occurredAt: occurredAt,
            saving: false,
            error: null,
            onBack: () {},
            onChangeTime: () {},
            onOccurredAtChanged: (_) {},
            onSave: (_) {},
          ),
        ),
      );

      expect(find.text('유축'), findsOneWidget);
      expect(find.byKey(const Key('pumping-amount-input')), findsOneWidget);
      expect(find.byKey(const Key('pumping-side-chip-left')), findsOneWidget);
      expect(find.byKey(const Key('pumping-side-chip-right')), findsOneWidget);
      expect(find.byKey(const Key('pumping-side-chip-both')), findsOneWidget);
      expect(
        find.byKey(const Key('save-pumping-event-button')),
        findsOneWidget,
      );
    });

    testWidgets(
      'selects side chip, enters amount and note, and triggers onSave with formatted details',
      (tester) async {
        PumpingFormResult? result;
        bool backPressed = false;
        final occurredAt = DateTime(2026, 7, 26, 14, 20);

        await tester.pumpWidget(
          localized(
            PumpingEventForm(
              occurredAt: occurredAt,
              saving: false,
              error: null,
              onBack: () => backPressed = true,
              onChangeTime: () {},
              onOccurredAtChanged: (_) {},
              onSave: (res) => result = res,
            ),
          ),
        );

        // Select '양쪽' side chip
        final bothChip = find.byKey(const Key('pumping-side-chip-both'));
        await tester.tap(bothChip);
        await tester.pumpAndSettle();

        // Enter amount: 120 mL
        await tester.enterText(
          find.byKey(const Key('pumping-amount-input')),
          '120',
        );
        await tester.pumpAndSettle();

        // Enter memo
        await tester.enterText(find.byType(TextField).last, '유축기 4단계로 유축');
        await tester.pumpAndSettle();

        // Save record
        final saveButton = find.byKey(const Key('save-pumping-event-button'));
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.record.amountMl, 120);
        expect(result!.record.side, PumpingSide.both);
        expect(result!.record.note, '유축기 4단계로 유축');
        expect(result!.details, '120mL · 양쪽');

        // Test explicit cancel and inline time controls.
        expect(
          find.byKey(const Key('pumping-date-time-controls')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('cancel-pumping-event-button')));
        expect(backPressed, isTrue);
      },
    );

    testWidgets(
      'restores initial record values and toggles side chip to deselect',
      (tester) async {
        PumpingFormResult? result;
        final occurredAt = DateTime(2026, 7, 26, 14, 20);
        final initial = PumpingRecord(
          occurredAt: occurredAt,
          amountMl: 90,
          side: PumpingSide.left,
          note: '기존 유축',
        );

        await tester.pumpWidget(
          localized(
            PumpingEventForm(
              occurredAt: occurredAt,
              saving: false,
              error: null,
              initialRecord: initial,
              onBack: () {},
              onChangeTime: () {},
              onOccurredAtChanged: (_) {},
              onSave: (res) => result = res,
            ),
          ),
        );

        expect(find.text('90'), findsOneWidget);
        expect(find.text('기존 유축'), findsOneWidget);

        // Tap left chip to deselect (reset to unknown)
        await tester.tap(find.byKey(const Key('pumping-side-chip-left')));
        await tester.pumpAndSettle();

        // Save
        final save = find.byKey(const Key('save-pumping-event-button'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.record.amountMl, 90);
        expect(result!.record.side, PumpingSide.unknown);
        expect(result!.details, '90mL');
      },
    );
  });
}
