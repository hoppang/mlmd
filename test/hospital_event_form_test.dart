import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/attachments/domain/event_attachment.dart';
import 'package:mlmd/features/events/presentation/hospital_event_form.dart';
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

  testWidgets(
    'HospitalEventForm saves hospital visit record with doctor notes and prescription bag photo',
    (tester) async {
      HospitalFormResult? result;
      final occurredAt = DateTime(2026, 7, 25, 14, 20);

      await tester.pumpWidget(
        localized(
          HospitalEventForm(
            occurredAt: occurredAt,
            saving: false,
            error: null,
            onBack: () {},
            onChangeTime: () {},
            onSave: (val) => result = val,
          ),
        ),
      );

      expect(find.text('병원·상담'), findsOneWidget);
      expect(find.text('의사에게 들은 내용 (선택)'), findsOneWidget);

      // Enter doctor's note
      await tester.enterText(find.byType(TextField), '중이염 처방. 3일 뒤 재진.');
      await tester.pumpAndSettle();

      // Tap prescription bag photo button
      await tester.tap(find.byKey(const Key('add-prescription-bag-btn')));
      await tester.pumpAndSettle();

      expect(find.text('약봉투'), findsOneWidget);

      // Tap general attachment button
      await tester.tap(find.byKey(const Key('attach-file-btn')));
      await tester.pumpAndSettle();

      expect(find.text('첨부파일'), findsOneWidget);

      // Tap save
      await tester.tap(find.byKey(const Key('save-hospital-event')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result?.record.visitedAt, occurredAt);
      expect(result?.record.note, '중이염 처방. 3일 뒤 재진.');
      expect(result?.attachments.length, 2);
      expect(
        result?.attachments[0].attachmentType,
        AttachmentType.prescriptionBag,
      );
      expect(result?.attachments[1].attachmentType, AttachmentType.general);
    },
  );
}
