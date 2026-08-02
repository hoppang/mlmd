import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/presentation/memo_event_form.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget localized(Widget child) => ProviderScope(
    child: MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets(
    'MemoEventForm renders header, text field, typo correction button, save button',
    (tester) async {
      await tester.pumpWidget(
        localized(
          MemoEventForm(
            occurredAt: DateTime(2026, 7, 28, 10, 0),
            saving: false,
            error: null,
            onBack: () {},
            onChangeTime: () {},
            onSave: (_) {},
          ),
        ),
      );

      expect(find.text('메모'), findsOneWidget);
      expect(find.byKey(const Key('stt_typo_correction_btn')), findsOneWidget);
      expect(find.byKey(const Key('save_memo_record_btn')), findsOneWidget);
    },
  );

  testWidgets('MemoEventForm saves MemoRecord when text is entered', (
    tester,
  ) async {
    MemoFormResult? result;
    final occurredAt = DateTime(2026, 7, 28, 10, 0);

    await tester.pumpWidget(
      localized(
        MemoEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (res) => result = res,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '아침에 터미타임을 5분 동안 진행함');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_memo_record_btn')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.record.content, equals('아침에 터미타임을 5분 동안 진행함'));
    expect(result!.record.occurredAt, equals(occurredAt));
    expect(result!.details, equals('아침에 터미타임을 5분 동안 진행함'));
  });

  testWidgets(
    'MemoEventForm handles STT typo correction, apply, and undo flow',
    (tester) async {
      await tester.pumpWidget(
        localized(
          MemoEventForm(
            occurredAt: DateTime(2026, 7, 28, 10, 0),
            saving: false,
            error: null,
            onBack: () {},
            onChangeTime: () {},
            onSave: (_) {},
          ),
        ),
      );

      // Enter text with typos
      await tester.enterText(find.byType(TextField), '어재 분유 180미리 먹었슴');
      await tester.pumpAndSettle();

      // Tap [맞춤법·오탈자만 정리]
      await tester.tap(find.byKey(const Key('stt_typo_correction_btn')));
      await tester.pumpAndSettle();

      // Verify correction preview sheet is shown
      expect(find.text('맞춤법·오탈자 교정 결과'), findsOneWidget);
      expect(find.text('어재 분유 180미리 먹었슴'), findsNWidgets(2));
      expect(find.text('어제 분유 180ml 먹었음'), findsOneWidget);

      // Tap [적용]
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();

      // Check text field updated to corrected text
      expect(find.text('어제 분유 180ml 먹었음'), findsOneWidget);

      // Verify Undo button appeared
      expect(find.byKey(const Key('stt_undo_correction_btn')), findsOneWidget);

      // Tap [되돌리기]
      await tester.tap(find.byKey(const Key('stt_undo_correction_btn')));
      await tester.pumpAndSettle();

      // Verify original text restored
      expect(find.text('어재 분유 180미리 먹었슴'), findsOneWidget);
    },
  );
}
