import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../data/objectbox_helper.dart';
import '../providers/locale_provider.dart';
import '../services/embedding_service.dart';
import 'local_model_bootstrap.dart';
import 'desktop_window_close_handler.dart';

Future<Widget> bootstrapApplication() async {
  await DesktopWindowCloseHandler.instance.initialize();
  await registerLocalModelIfNeeded();

  final objectBox = await ObjectBoxHelper.create();
  final embeddingService = EmbeddingService();
  await embeddingService.init();
  final preferences = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      objectBoxProvider.overrideWithValue(objectBox),
      embeddingServiceProvider.overrideWithValue(embeddingService),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
    child: const MyApp(),
  );
}
