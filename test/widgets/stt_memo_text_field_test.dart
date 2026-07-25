import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/repositories/stt_notice_repository.dart';
import 'package:mlmd/widgets/stt_memo_text_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget({
    required Widget child,
    required SttNoticeRepository noticeRepo,
  }) {
    return ProviderScope(
      overrides: [
        sttNoticeRepositoryProvider.overrideWithValue(noticeRepo),
      ],
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
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  group('SttMemoTextField Widget Tests', () {
    testWidgets('Shows mic icon when Android platform is specified',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final noticeRepo = SttNoticeRepository(prefs);

      await tester.pumpWidget(
        buildTestableWidget(
          noticeRepo: noticeRepo,
          child: const SttMemoTextField(
            labelText: 'Test Note',
            overrideIsAndroid: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('Hides mic icon when non-Android platform is specified',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final noticeRepo = SttNoticeRepository(prefs);

      await tester.pumpWidget(
        buildTestableWidget(
          noticeRepo: noticeRepo,
          child: const SttMemoTextField(
            labelText: 'Test Note',
            overrideIsAndroid: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsNothing);
    });

    testWidgets('Tapping mic shows SttNoticeDialog if consent not granted',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final noticeRepo = SttNoticeRepository(prefs);

      await tester.pumpWidget(
        buildTestableWidget(
          noticeRepo: noticeRepo,
          child: const SttMemoTextField(
            labelText: 'Test Note',
            overrideIsAndroid: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();

      expect(find.text('음성 입력 전 확인'), findsOneWidget);
      expect(find.text('확인했고 사용'), findsOneWidget);
      expect(find.text('키보드로 입력'), findsOneWidget);
    });

    testWidgets('Tapping [확인했고 사용] saves consent', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final noticeRepo = SttNoticeRepository(prefs);

      await tester.pumpWidget(
        buildTestableWidget(
          noticeRepo: noticeRepo,
          child: const SttMemoTextField(
            labelText: 'Test Note',
            overrideIsAndroid: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();

      await tester.tap(find.text('확인했고 사용'));
      await tester.pumpAndSettle();

      expect(noticeRepo.isAccepted, isTrue);
      expect(find.text('음성 입력 전 확인'), findsNothing);
    });
  });
}
