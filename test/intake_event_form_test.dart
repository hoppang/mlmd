import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/event_catalog.dart';
import 'package:mlmd/features/events/domain/intake_record.dart';
import 'package:mlmd/features/events/presentation/intake_event_form.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('물의 컵 기준은 선택을 유지하고 안내를 기기별 한 번만 보여준다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    IntakeFormResult? result;

    Widget app() => ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: IntakeEventForm(
            item: eventCatalogItem(EventTypeId.water),
            occurredAt: DateTime(2026, 7, 24, 10),
            saving: false,
            error: null,
            onBack: () {},
            onChangeTime: () {},
            onOccurredAtChanged: (_) {},
            onSave: (value) => result = value,
          ),
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('amount-kind-fraction')));
    await tester.pumpAndSettle();

    expect(find.text('컵 단위 안내'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('amount-kind-fraction')))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('save-quick-record'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();

    expect(result?.record.kind, IntakeRecordKind.water);
    expect(
      result?.record.amountExpression?.kind,
      AmountExpressionKind.fraction,
    );
    expect(result?.record.amountExpression?.fraction, 0.5);
    expect(result?.details, '절반');

    result = null;
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('amount-kind-fraction')));
    await tester.pumpAndSettle();
    expect(find.text('컵 단위 안내'), findsNothing);
  });

  testWidgets('feeding requires amount and adjusts amount and time inline', (
    tester,
  ) async {
    final now = DateTime.now();
    var occurredAt = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).subtract(const Duration(minutes: 30));
    IntakeFormResult? result;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setHarnessState) => IntakeEventForm(
                item: eventCatalogItem(EventTypeId.feeding),
                occurredAt: occurredAt,
                saving: false,
                error: null,
                onBack: () {},
                onChangeTime: () {},
                onOccurredAtChanged: (value) =>
                    setHarnessState(() => occurredAt = value),
                onSave: (value) => result = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('feeding-type-expressedMilk')));
    final addHundred = find.byKey(const Key('adjust-feeding-amount-100'));
    await tester.ensureVisible(addHundred);
    await tester.tap(addHundred);
    final addTen = find.byKey(const Key('adjust-feeding-amount-10'));
    await tester.ensureVisible(addTen);
    await tester.tap(addTen);
    await tester.ensureVisible(find.byKey(const Key('adjust-feeding-hour--1')));
    await tester.tap(find.byKey(const Key('adjust-feeding-hour--1')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-quick-record')));
    await tester.tap(find.byKey(const Key('save-quick-record')));
    await tester.pump();

    expect(result?.record.method, FeedingMethod.bottle);
    expect(result?.record.bottleContents, BottleContents.expressedMilk);
    expect(result?.record.amountExpression?.exactValue, 110);
    expect(
      occurredAt,
      DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      ).subtract(const Duration(hours: 1, minutes: 30)),
    );
    expect(find.byKey(const Key('cancel-quick-record')), findsOneWidget);
  });
}
