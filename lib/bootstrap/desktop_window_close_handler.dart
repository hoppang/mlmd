import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../features/drafts/application/active_draft_registry.dart';

class DesktopWindowCloseHandler with WindowListener {
  DesktopWindowCloseHandler._();

  static final instance = DesktopWindowCloseHandler._();

  static const _mobilePreview = bool.fromEnvironment('MOBILE_PREVIEW');
  static const _mobilePreviewWidth = int.fromEnvironment(
    'MOBILE_PREVIEW_WIDTH',
    defaultValue: 412,
  );
  static const _mobilePreviewHeight = int.fromEnvironment(
    'MOBILE_PREVIEW_HEIGHT',
    defaultValue: 915,
  );

  Future<void> initialize() async {
    if (!Platform.isWindows) return;
    await windowManager.ensureInitialized();
    if (_mobilePreview) {
      await windowManager.setSize(
        Size(_mobilePreviewWidth.toDouble(), _mobilePreviewHeight.toDouble()),
      );
      await windowManager.center();
    }
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    final saved = ActiveDraftRegistry.instance.flushAll();
    if (saved) await windowManager.destroy();
  }
}
