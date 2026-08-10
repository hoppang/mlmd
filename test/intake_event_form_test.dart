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
    final expectedOccurredAt = occurredAt.subtract(const Duration(hours: 1));
    await tester.ensureVisible(
      find.byKey(const Key('feeding-hour-wheel-selected')),
    );
    await tester.tap(find.byKey(const Key('feeding-hour-wheel-selected')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('feeding-hour-wheel-input')),
      expectedOccurredAt.hour.toString().padLeft(2, '0'),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-quick-record')));
    await tester.tap(find.byKey(const Key('save-quick-record')));
    await tester.pump();

    expect(result?.record.method, FeedingMethod.bottle);
    expect(result?.record.bottleContents, BottleContents.expressedMilk);
    expect(result?.record.amountExpression?.exactValue, 110);
    expect(occurredAt, expectedOccurredAt);
    expect(find.byKey(const Key('cancel-quick-record')), findsOneWidget);
  });

  testWidgets('이유식 식사시간은 페이지 안에서 날짜와 시간을 변경한다', (tester) async {
    final now = DateTime.now();
    var occurredAt = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).subtract(const Duration(hours: 1));
    final initialOccurredAt = occurredAt;
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
                item: eventCatalogItem(EventTypeId.meal),
                occurredAt: occurredAt,
                saving: false,
                error: null,
                onBack: () {},
                onChangeTime: () => fail('별도 시간 페이지를 열면 안 됩니다.'),
                onOccurredAtChanged: (value) =>
                    setHarnessState(() => occurredAt = value),
                onSave: (value) => result = value,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('quick-record-time')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quick-record-time')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-date-time-editor')), findsOneWidget);
    expect(find.byKey(const Key('quick-record-time')), findsNothing);
    expect(find.byKey(const Key('meal-hour-wheel')), findsOneWidget);
    expect(find.byKey(const Key('meal-minute-wheel')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('meal-hour-wheel-viewport'))).height,
      180,
    );

    final yesterdayChip = find.byKey(const Key('meal-date-yesterday'));
    await tester.ensureVisible(yesterdayChip);
    await tester.tap(yesterdayChip);
    await tester.pumpAndSettle();

    final yesterday = DateUtils.dateOnly(now).subtract(const Duration(days: 1));
    final expectedOccurredAt = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
      initialOccurredAt.hour,
      initialOccurredAt.minute,
    );
    expect(occurredAt, expectedOccurredAt);
    expect(find.byKey(const Key('save-meal-date-time')), findsNothing);
    expect(find.byKey(const Key('meal-date-time-editor')), findsOneWidget);
    expect(find.byKey(const Key('quick-record-time')), findsNothing);

    final cancelDateTime = find.byKey(const Key('cancel-meal-date-time'));
    await tester.ensureVisible(cancelDateTime);
    await tester.tap(cancelDateTime);
    await tester.pumpAndSettle();
    expect(occurredAt, initialOccurredAt);
    expect(find.byKey(const Key('quick-record-time')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-record-time')));
    await tester.pumpAndSettle();
    final yesterdayAgain = find.byKey(const Key('meal-date-yesterday'));
    await tester.ensureVisible(yesterdayAgain);
    await tester.tap(yesterdayAgain);
    await tester.pumpAndSettle();
    expect(occurredAt, expectedOccurredAt);

    await tester.ensureVisible(find.byKey(const Key('save-quick-record')));
    await tester.tap(find.byKey(const Key('save-quick-record')));
    await tester.pump();
    expect(result?.record.kind, IntakeRecordKind.meal);
    expect(occurredAt, expectedOccurredAt);
  });
}
