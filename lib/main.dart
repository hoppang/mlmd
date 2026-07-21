import 'package:flutter/material.dart';

import 'bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await bootstrapApplication());
}
