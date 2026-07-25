import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/attachments/domain/event_attachment.dart';
import 'package:mlmd/features/events/presentation/vaccination_event_form.dart';
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

  testWidgets('VaccinationEventForm saves vaccination record with notes, vaccination book photo, and tests KDCA link', (tester) async {
    VaccinationFormResult? result;
    Uri? launchedUri;
    final occurredAt = DateTime(2026, 7, 25, 10, 30);

    await tester.pumpWidget(
      localized(
        VaccinationEventForm(
          occurredAt: occurredAt,
          saving: false,
          error: null,
          onBack: () {},
          onChangeTime: () {},
          onSave: (val) => result = val,
          launchExternal: (uri) async {
            launchedUri = uri;
            return true;
          },
        ),
      ),
    );

    expect(find.text('예방접종'), findsOneWidget);
    expect(find.text('접종 메모 (선택)'), findsOneWidget);
    expect(find.text('질병관리청에서 접종 내역 확인'), findsOneWidget);

    // Enter note
    await tester.enterText(
      find.byType(TextField),
      'B형간염 2차 접종. 특이사항 없음.',
    );
    await tester.pumpAndSettle();

    // Tap vaccination book photo button
    await tester.tap(find.byKey(const Key('add-vaccination-book-btn')));
    await tester.pumpAndSettle();

    expect(find.text('예방접종 수첩'), findsOneWidget);

    // Tap general attachment button
    await tester.tap(find.byKey(const Key('attach-file-btn')));
    await tester.pumpAndSettle();

    expect(find.text('첨부파일'), findsOneWidget);

    // Tap KDCA link button
    await tester.tap(find.byKey(const Key('open-kdca-vaccination-link')));
    await tester.pumpAndSettle();

    expect(launchedUri, isNotNull);
    expect(launchedUri?.host, 'nip.kdca.go.kr');

    // Tap save
    await tester.tap(find.byKey(const Key('save-vaccination-event')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.record.vaccinatedAt, occurredAt);
    expect(result?.record.note, 'B형간염 2차 접종. 특이사항 없음.');
    expect(result?.attachments.length, 2);
    expect(result?.attachments[0].attachmentType, AttachmentType.vaccinationRecord);
    expect(result?.attachments[1].attachmentType, AttachmentType.general);
  });
}
