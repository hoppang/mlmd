import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mlmd/features/settings/presentation/past_notices_page.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/repositories/stt_notice_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget({required SttNoticeRepository noticeRepo}) {
    return ProviderScope(
      overrides: [
        sttNoticeRepositoryProvider.overrideWithValue(noticeRepo),
      ],
      child: const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PastNoticesPage(),
      ),
    );
  }

  group('PastNoticesPage Widget Tests', () {
    testWidgets('Displays unconfirmed status when consent is not granted',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final noticeRepo = SttNoticeRepository(prefs);

      await tester.pumpWidget(buildTestableWidget(noticeRepo: noticeRepo));
      await tester.pumpAndSettle();

      expect(find.text('이전에 본 안내'), findsOneWidget);
      expect(find.text('Android 음성 입력 및 개인정보 처리 고지'), findsOneWidget);
      expect(find.text('미확인'), findsOneWidget);
      expect(find.text('고지문 다시 보기'), findsOneWidget);
    });

    testWidgets('Displays confirmed status when consent is granted',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final noticeRepo = SttNoticeRepository(prefs);
      await noticeRepo.acceptNotice();

      await tester.pumpWidget(buildTestableWidget(noticeRepo: noticeRepo));
      await tester.pumpAndSettle();

      expect(find.text('이전에 본 안내'), findsOneWidget);
      expect(find.textContaining('확인함 ·'), findsOneWidget);
    });

    testWidgets('Tapping notice opens SttNoticeDialog', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final noticeRepo = SttNoticeRepository(prefs);

      await tester.pumpWidget(buildTestableWidget(noticeRepo: noticeRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('고지문 다시 보기'));
      await tester.pumpAndSettle();

      expect(find.text('음성 입력 전 확인'), findsOneWidget);
    });
  });
}
