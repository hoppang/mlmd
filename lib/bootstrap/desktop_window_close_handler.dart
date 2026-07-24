import 'dart:io';

import 'package:window_manager/window_manager.dart';

import '../features/drafts/application/active_draft_registry.dart';

class DesktopWindowCloseHandler with WindowListener {
  DesktopWindowCloseHandler._();

  static final instance = DesktopWindowCloseHandler._();

  Future<void> initialize() async {
    if (!Platform.isWindows) return;
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    final saved = ActiveDraftRegistry.instance.flushAll();
    if (saved) await windowManager.destroy();
  }
}
