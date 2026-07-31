import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mlmd/core/layout/adaptive_content_frame.dart';

void main() {
  testWidgets('uses the full available width on Windows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveContentFrame(
            child: ColoredBox(key: Key('content'), color: Colors.blue),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('content'))).width, 1280);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keeps the readable width cap on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveContentFrame(
            child: ColoredBox(key: Key('content'), color: Colors.blue),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('content'))).width, 720);
    debugDefaultTargetPlatformOverride = null;
  });
}
