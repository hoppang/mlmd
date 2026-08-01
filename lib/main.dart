import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap/app_startup_widget.dart';
import 'bootstrap/desktop_window_close_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopWindowCloseHandler.instance.initialize();
  runApp(const ProviderScope(child: AppStartupWidget()));
}
