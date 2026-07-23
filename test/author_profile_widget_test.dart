import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/profiles/presentation/author_profile_page.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/repositories/profile_repository.dart';

import 'support/test_profile_repository.dart';

void main() {
  testWidgets('first launch requires a name and then opens the app', (
    tester,
  ) async {
    final profiles = TestProfileRepository(withAuthor: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthorProfileGate(child: Text('HOME')),
        ),
      ),
    );

    expect(find.text('이 기기에서 누가 기록하나요?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-author-profile')));
    await tester.pump();
    expect(find.text('1~30자의 이름을 입력해 주세요.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('author-nickname-field')),
      '엄마',
    );
    await tester.tap(find.byKey(const Key('save-author-profile')));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(profiles.currentAuthor?.nickname, '엄마');
    expect(profiles.currentDevice.deviceProfileId, isNotEmpty);
  });
}
