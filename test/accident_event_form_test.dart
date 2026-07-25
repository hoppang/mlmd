import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/accident_injury_record.dart';
import 'package:mlmd/features/events/presentation/accident_event_form.dart';
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

  testWidgets('AccidentEventForm toggles categories, selects injury type, shows attention warning, attaches photos and saves record', (tester) async {
    AccidentFormResult? result;
    final occurredAt = DateTime(2026, 7, 25, 14, 30);

    await tester.pumpWidget(
      localized(
        AccidentEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (val) => result = val,
        ),
      ),
    );

    expect(find.text('사고·다침'), findsOneWidget);
    expect(find.text('외상 (다침/상처)'), findsOneWidget);
    expect(find.text('비외상 (삼킴/이물/사레)'), findsOneWidget);

    // Initial default: traumatic category, bumpBruise chip (non-attention)
    expect(find.byKey(const Key('accident-type-chip-bumpBruise')), findsOneWidget);
    expect(find.byKey(const Key('accident-attention-card')), findsNothing);

    // Tap high-risk injury type: fallTrip (넘어짐·낙상)
    await tester.tap(find.byKey(const Key('accident-type-chip-fallTrip')));
    await tester.pumpAndSettle();

    // Attention card should be displayed
    expect(find.byKey(const Key('accident-attention-card')), findsOneWidget);
    expect(find.text('주의 필요 사고'), findsOneWidget);

    // Switch category to non-traumatic
    await tester.tap(find.text('비외상 (삼킴/이물/사레)'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('accident-type-chip-foreignIngestion')), findsOneWidget);
    expect(find.byKey(const Key('accident-attention-card')), findsOneWidget); // foreignIngestion is high risk

    // Enter note
    await tester.enterText(
      find.byType(TextField),
      '작은 완구 단추 삼킴 의심, 직후 얼컥거림',
    );
    await tester.pumpAndSettle();

    // Attach photo
    final attachBtn = find.byKey(const Key('attach-accident-photo-button'));
    await tester.ensureVisible(attachBtn);
    await tester.tap(attachBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('accident_photo_'), findsOneWidget);

    // Save
    final saveBtn = find.byKey(const Key('save-accident-event-button'));
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.record.category, AccidentCategory.nonTraumatic);
    expect(result?.record.injuryType, AccidentInjuryType.foreignIngestion);
    expect(result?.record.note, '작은 완구 단추 삼킴 의심, 직후 얼컥거림');
    expect(result?.details, contains('비외상 (삼킴/이물/사레) · 이물질 삼킴 · 작은 완구 단추 삼킴 의심, 직후 얼컥거림'));
    expect(result?.attachments.length, 1);
  });
}
