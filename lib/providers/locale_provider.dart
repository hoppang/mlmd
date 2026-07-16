import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLocaleMode { system, korean, english, japanese }

// SharedPreferences provider (initialized in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class LocaleNotifier extends Notifier<AppLocaleMode> {
  static const _prefsKey = 'app_locale_mode';

  @override
  AppLocaleMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final modeString = prefs.getString(_prefsKey);
    if (modeString != null) {
      if (modeString == AppLocaleMode.korean.name) {
        return AppLocaleMode.korean;
      } else if (modeString == AppLocaleMode.english.name) {
        return AppLocaleMode.english;
      } else if (modeString == AppLocaleMode.japanese.name) {
        return AppLocaleMode.japanese;
      }
    }
    return AppLocaleMode.system;
  }

  Future<void> setLocale(AppLocaleMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_prefsKey, mode.name);
  }

  Locale? get locale {
    switch (state) {
      case AppLocaleMode.korean:
        return const Locale('ko');
      case AppLocaleMode.english:
        return const Locale('en');
      case AppLocaleMode.japanese:
        return const Locale('ja');
      case AppLocaleMode.system:
        return null;
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLocaleMode>(() {
  return LocaleNotifier();
});
