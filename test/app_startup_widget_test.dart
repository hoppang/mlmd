import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/bootstrap/app_bootstrap.dart';
import 'package:mlmd/bootstrap/app_startup_widget.dart';
import 'package:mlmd/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('startup loading does not read dependencies before bootstrap', (
    tester,
  ) async {
    final pending = Completer<AppDependencies>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appStartupProvider.overrideWith((ref) => pending.future)],
        child: const AppStartupWidget(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup error renders before preferences are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartupProvider.overrideWith(
            (ref) => Future<AppDependencies>.error(StateError('bootstrap')),
          ),
        ],
        child: const AppStartupWidget(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('bootstrap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locale provider follows a nested preferences override', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app_locale_mode': AppLocaleMode.korean.name,
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        child: ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: Consumer(
            builder: (context, ref, child) {
              final locale = ref.watch(localeProvider.notifier).locale;
              ref.watch(localeProvider);
              return Text(
                locale?.languageCode ?? AppLocaleMode.system.name,
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('ko'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
