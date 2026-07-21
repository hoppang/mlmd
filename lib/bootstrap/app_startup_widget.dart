import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../data/objectbox_helper.dart';
import '../providers/locale_provider.dart';
import '../services/embedding_service.dart';
import '../l10n/app_localizations.dart';
import 'app_bootstrap.dart';
import 'startup_error_screen.dart';

class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupState = ref.watch(appStartupProvider);

    return startupState.when(
      data: (dependencies) {
        return ProviderScope(
          overrides: [
            objectBoxProvider.overrideWithValue(dependencies.objectBox),
            embeddingServiceProvider.overrideWithValue(dependencies.embeddingService),
            sharedPreferencesProvider.overrideWithValue(dependencies.preferences),
          ],
          child: const MyApp(),
        );
      },
      error: (error, stackTrace) {
        return StartupErrorScreen(
          error: error,
          stackTrace: stackTrace,
          onRetry: () {
            ref.invalidate(appStartupProvider);
          },
          onResetData: () async {
            await ObjectBoxHelper.resetData();
            // Optional: reset SharedPreferences as well
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            
            if (context.mounted) {
              ref.invalidate(appStartupProvider);
            }
          },
        );
      },
      loading: () {
        return const _StartupLoadingScreen();
      },
    );
  }
}

class _StartupLoadingScreen extends ConsumerWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider.notifier).locale;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
      home: Builder(
        builder: (context) {
          final loc = AppLocalizations.of(context);
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  if (loc != null) Text(loc.startupLoading),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
