import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/care_procedure_record.dart';
import 'package:mlmd/features/events/presentation/care_procedure_event_form.dart';
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

  testWidgets('requires a type and a description for other procedures', (
    tester,
  ) async {
    CareProcedureFormResult? result;
    await tester.pumpWidget(
      localized(
        CareProcedureEventForm(
          occurredAt: DateTime(2026, 7, 29, 10),
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (value) => result = value,
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const Key('save-care-procedure-event')),
    );
    await tester.tap(find.byKey(const Key('save-care-procedure-event')));
    await tester.pump();
    expect(find.text('처치 종류를 선택해 주세요.'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('care-procedure-type-other')),
    );
    await tester.tap(find.byKey(const Key('care-procedure-type-other')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('save-care-procedure-event')),
    );
    await tester.tap(find.byKey(const Key('save-care-procedure-event')));
    await tester.pump();

    expect(find.text('기타 처치로 무엇을 했는지 입력해 주세요.'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('saves wound care with an optional area, note, photo and file', (
    tester,
  ) async {
    CareProcedureFormResult? result;
    final occurredAt = DateTime(2026, 7, 29, 14, 20);
    await tester.pumpWidget(
      localized(
        CareProcedureEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('care-procedure-type-woundCare')));
    await tester.pump();
    expect(find.byKey(const Key('care-procedure-body-area')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('care-procedure-body-area')),
      '왼쪽 무릎',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('care-procedure-note')),
        matching: find.byType(TextField),
      ),
      '흐르는 물로 씻고 거즈 부착',
    );

    await tester.ensureVisible(
      find.byKey(const Key('care-procedure-photo-button')),
    );
    await tester.tap(find.byKey(const Key('care-procedure-photo-button')));
    await tester.tap(find.byKey(const Key('care-procedure-file-button')));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const Key('save-care-procedure-event')),
    );
    await tester.tap(find.byKey(const Key('save-care-procedure-event')));
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.record.occurredAt, occurredAt);
    expect(result!.record.procedureType, CareProcedureType.woundCare);
    expect(result!.record.bodyArea, '왼쪽 무릎');
    expect(result!.record.note, '흐르는 물로 씻고 거즈 부착');
    expect(result!.procedureName, '상처 세척·드레싱');
    expect(result!.details, '왼쪽 무릎 · 흐르는 물로 씻고 거즈 부착');
    expect(result!.attachments, hasLength(2));
  });
}
