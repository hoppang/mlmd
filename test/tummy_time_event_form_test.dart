import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/tummy_time_record.dart';
import 'package:mlmd/features/events/presentation/tummy_time_event_form.dart';
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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets(
    'TummyTimeEventForm renders title, recommendation card, and save button',
    (tester) async {
      await tester.pumpWidget(
        localized(
          TummyTimeEventForm(
            occurredAt: DateTime(2026, 7, 27, 10, 0),
            saving: false,
            error: null,
            onBack: () {},
            onChangeTime: () {},
            onSave: (_) {},
          ),
        ),
      );

      expect(find.text('터미타임 기록'), findsOneWidget);
      expect(
        find.byKey(const Key('tummy-time-recommendation-card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('save-tummy-time-button')), findsOneWidget);
    },
  );

  testWidgets('TummyTimeEventForm saves record with duration and note', (
    tester,
  ) async {
    TummyTimeFormResult? result;
    final occurredAt = DateTime(2026, 7, 27, 10, 0);

    await tester.pumpWidget(
      localized(
        TummyTimeEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (val) => result = val,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('tummy-time-duration-input')),
      '5',
    );
    await tester.enterText(
      find.byKey(const Key('tummy-time-note-field')),
      '잘 버텼어요',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-tummy-time-button')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.record.durationMinutes, 5);
    expect(result!.record.note, '잘 버텼어요');
    expect(result!.record.occurredAt, occurredAt);
    expect(result!.details, '5분');
  });

  testWidgets('TummyTimeEventForm saves record with no duration (time-only)', (
    tester,
  ) async {
    TummyTimeFormResult? result;
    final occurredAt = DateTime(2026, 7, 27, 10, 0);

    await tester.pumpWidget(
      localized(
        TummyTimeEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (val) => result = val,
        ),
      ),
    );

    // Leave duration empty, just save
    await tester.tap(find.byKey(const Key('save-tummy-time-button')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.record.durationMinutes, isNull);
    expect(result!.record.note, isNull);
    expect(result!.details, '');
  });

  testWidgets(
    'TummyTimeEventForm shows validation error for invalid duration (0)',
    (tester) async {
      TummyTimeFormResult? result;

      await tester.pumpWidget(
        localized(
          TummyTimeEventForm(
            occurredAt: DateTime(2026, 7, 27, 10, 0),
            saving: false,
            error: null,
            onBack: () {},
            onChangeTime: () {},
            onSave: (val) => result = val,
          ),
        ),
      );

      // Enter "0" which is invalid
      await tester.enterText(
        find.byKey(const Key('tummy-time-duration-input')),
        '0',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-tummy-time-button')));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.text('1~999 사이의 숫자를 입력해 주세요.'), findsOneWidget);
    },
  );

  testWidgets('TummyTimeEventForm triggers onBack and onChangeTime callbacks', (
    tester,
  ) async {
    bool backTapped = false;
    bool changeTimeTapped = false;

    await tester.pumpWidget(
      localized(
        TummyTimeEventForm(
          occurredAt: DateTime.now(),
          saving: false,
          error: null,
          onBack: () => backTapped = true,
          onChangeTime: () => changeTimeTapped = true,
          onSave: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('back-to-record-types')));
    await tester.pumpAndSettle();
    expect(backTapped, isTrue);

    await tester.tap(find.byKey(const Key('quick-record-time')));
    await tester.pumpAndSettle();
    expect(changeTimeTapped, isTrue);
  });

  testWidgets('TummyTimeEventForm restores initialRecord fields', (
    tester,
  ) async {
    TummyTimeFormResult? result;
    final occurredAt = DateTime(2026, 7, 27, 10, 0);
    final initialRecord = TummyTimeRecord(
      occurredAt: occurredAt,
      durationMinutes: 8,
      note: '이미 기록된 메모',
    );

    await tester.pumpWidget(
      localized(
        TummyTimeEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (val) => result = val,
          initialRecord: initialRecord,
        ),
      ),
    );

    // Duration and note should be pre-populated
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('tummy-time-duration-input')))
          .controller!
          .text,
      '8',
    );

    await tester.tap(find.byKey(const Key('save-tummy-time-button')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.record.durationMinutes, 8);
    expect(result!.record.note, '이미 기록된 메모');
  });

  testWidgets(
    'TummyTimeEventForm shows error message from parent when error is set',
    (tester) async {
      await tester.pumpWidget(
        localized(
          TummyTimeEventForm(
            occurredAt: DateTime.now(),
            saving: false,
            error: '기록을 저장하지 못했어요. 입력 내용은 그대로 유지됩니다.',
            onBack: () {},
            onChangeTime: () {},
            onSave: (_) {},
          ),
        ),
      );

      expect(find.byKey(const Key('quick-record-error')), findsOneWidget);
      expect(find.text('기록을 저장하지 못했어요. 입력 내용은 그대로 유지됩니다.'), findsOneWidget);
    },
  );

  testWidgets('TummyTimeEventForm in English locale shows correct strings', (
    tester,
  ) async {
    TummyTimeFormResult? result;
    final occurredAt = DateTime(2026, 7, 27, 10, 0);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TummyTimeEventForm(
              occurredAt: occurredAt,
              saving: false,
              error: null,
              onBack: () {},
              onChangeTime: () {},
              onSave: (val) => result = val,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tummy Time'), findsOneWidget);
    expect(find.byKey(const Key('save-tummy-time-button')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('tummy-time-duration-input')),
      '3',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-tummy-time-button')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.record.durationMinutes, 3);
    expect(result!.details, '3 min');
  });
}
