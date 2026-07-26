import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/attachments/domain/event_attachment.dart';
import 'package:mlmd/features/events/presentation/bath_event_form.dart';
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

  testWidgets('BathEventForm renders one-touch hint and title correctly',
      (tester) async {
    final occurredAt = DateTime(2026, 7, 26, 19, 30);

    await tester.pumpWidget(
      localized(
        BathEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (_) {},
        ),
      ),
    );

    expect(find.text('목욕 기록'), findsOneWidget);
    expect(
      find.text('원터치 목욕 기록 · 세부 상태와 소요 시간 없이 현재 시각으로 저장합니다.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('save-bath-record')), findsOneWidget);
  });

  testWidgets('BathEventForm saves bath record instantly with current time',
      (tester) async {
    BathFormResult? result;
    final occurredAt = DateTime(2026, 7, 26, 19, 30);

    await tester.pumpWidget(
      localized(
        BathEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (val) => result = val,
        ),
      ),
    );

    // Tap save button directly (one-touch)
    await tester.tap(find.byKey(const Key('save-bath-record')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.record.occurredAt, occurredAt);
    expect(result?.record.isQuickBath, isTrue);
    expect(result?.record.note, isNull);
    expect(result?.details, isEmpty);
    expect(result?.attachments, isEmpty);
  });

  testWidgets('BathEventForm saves with note and attachments when added',
      (tester) async {
    BathFormResult? result;
    final occurredAt = DateTime(2026, 7, 26, 19, 30);

    await tester.pumpWidget(
      localized(
        BathEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (val) => result = val,
        ),
      ),
    );

    // Enter note
    await tester.enterText(
      find.byKey(const Key('bath-note-field')),
      '목욕 후 로션 바름',
    );
    await tester.pumpAndSettle();

    // Attach photo
    await tester.tap(find.byKey(const Key('attach-photo-btn')));
    await tester.pumpAndSettle();

    // Attach file
    await tester.tap(find.byKey(const Key('attach-file-btn')));
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.byKey(const Key('save-bath-record')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.record.note, '목욕 후 로션 바름');
    expect(result?.details, '목욕 후 로션 바름');
    expect(result?.attachments.length, 2);
    expect(result?.attachments[0].sourceKind, AttachmentSourceKind.inAppCamera);
    expect(result?.attachments[1].sourceKind, AttachmentSourceKind.filePicker);
  });

  testWidgets('BathEventForm triggers onBack and onChangeTime callbacks',
      (tester) async {
    bool backTapped = false;
    bool changeTimeTapped = false;

    await tester.pumpWidget(
      localized(
        BathEventForm(
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
}
