import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/objectbox_helper.dart';
import '../services/embedding_service.dart';
import 'local_model_bootstrap.dart';
import 'desktop_window_close_handler.dart';

class AppDependencies {
  final ObjectBoxHelper objectBox;
  final EmbeddingService embeddingService;
  final SharedPreferences preferences;

  AppDependencies({
    required this.objectBox,
    required this.embeddingService,
    required this.preferences,
  });
}

final appStartupProvider = FutureProvider<AppDependencies>((ref) async {
  await DesktopWindowCloseHandler.instance.initialize();
  await registerLocalModelIfNeeded();

  final objectBox = await ObjectBoxHelper.create();
  final embeddingService = EmbeddingService();
  await embeddingService.init();
  final preferences = await SharedPreferences.getInstance();

  return AppDependencies(
    objectBox: objectBox,
    embeddingService: embeddingService,
    preferences: preferences,
  );
});
