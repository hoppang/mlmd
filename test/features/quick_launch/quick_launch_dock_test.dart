import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mlmd/features/quick_launch/domain/quick_launch_models.dart';
import 'package:mlmd/features/quick_launch/presentation/quick_launch_dock.dart';
import 'package:mlmd/l10n/app_localizations.dart';

void main() {
  testWidgets('mobile shows five fixed user slots and a fixed all button', (
    tester,
  ) async {
    QuickLaunchSlot? pressed;
    int? edited;
    var openedAll = false;
    final layout = QuickLaunchLayout.empty()
        .copyWithSlot(
          0,
          const QuickLaunchSlot(
            slotIndex: 0,
            eventTypeId: QuickLaunchEventTarget.feeding,
          ),
        )
        .copyWithSlot(
          1,
          const QuickLaunchSlot(
            slotIndex: 1,
            eventTypeId: QuickLaunchEventTarget.medication,
            executionMode: QuickLaunchExecutionMode.prefilledForm,
          ),
        )
        .copyWithSlot(
          3,
          const QuickLaunchSlot(
            slotIndex: 3,
            eventTypeId: QuickLaunchEventTarget.sleep,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuickLaunchDock(
            layout: layout,
            onSlotPressed: (slot, _) => pressed = slot,
            onEditSlot: (index) => edited = index,
            onOpenAll: () => openedAll = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('quick-launch-dock')), findsOneWidget);
    for (var index = 0; index < quickLaunchCoreSlotCount; index++) {
      expect(find.byKey(Key('quick-launch-slot-$index')), findsOneWidget);
    }
    expect(find.byKey(const Key('quick-launch-slot-5')), findsNothing);
    expect(find.byKey(const Key('quick-launch-more')), findsNothing);
    expect(find.byKey(const Key('quick-launch-all')), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-launch-slot-0')));
    expect(pressed?.eventTypeId, QuickLaunchEventTarget.feeding);

    await tester.tap(find.byKey(const Key('quick-launch-slot-2')));
    expect(edited, 2);

    await tester.tap(find.byKey(const Key('quick-launch-all')));
    expect(openedAll, isTrue);
  });

  testWidgets('distinguishes category and detail-required slots semantically', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final layout = QuickLaunchLayout.empty()
        .copyWithSlot(
          0,
          const QuickLaunchSlot(
            slotIndex: 0,
            eventTypeId: QuickLaunchEventTarget.feeding,
          ),
        )
        .copyWithSlot(
          1,
          const QuickLaunchSlot(
            slotIndex: 1,
            eventTypeId: QuickLaunchEventTarget.medication,
            executionMode: QuickLaunchExecutionMode.prefilledForm,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuickLaunchDock(
            layout: layout,
            onSlotPressed: (_, _) {},
            onEditSlot: (_) {},
            onOpenAll: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Feeding, tap to open choices'), findsOne);
    expect(find.bySemanticsLabel('Medication, tap to open details'), findsOne);
    semantics.dispose();
  });

  testWidgets('mobile fits all six buttons at 320 logical pixels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuickLaunchDock(
            layout: QuickLaunchLayout.empty(),
            onSlotPressed: (_, _) {},
            onEditSlot: (_) {},
            onOpenAll: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    for (var index = 0; index < quickLaunchCoreSlotCount; index++) {
      expect(
        tester.getSize(find.byKey(Key('quick-launch-slot-$index'))).width,
        greaterThanOrEqualTo(48),
      );
    }
    expect(
      tester.getSize(find.byKey(const Key('quick-launch-all'))).width,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('wide Windows dock shows eight slots without overflow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp(layout: QuickLaunchLayout.empty()));

    for (var index = 0; index < quickLaunchSlotCount; index++) {
      expect(find.byKey(Key('quick-launch-slot-$index')), findsOneWidget);
    }
    expect(find.byKey(const Key('quick-launch-more')), findsNothing);
    expect(find.byKey(const Key('quick-launch-all')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('quick-launch-dock'))).width,
      1080,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('medium Windows dock exposes hidden slots from More', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 800);
    addTearDown(tester.view.reset);
    QuickLaunchSlot? pressed;
    int? edited;
    final layout = QuickLaunchLayout.empty().copyWithSlot(
      6,
      const QuickLaunchSlot(
        slotIndex: 6,
        eventTypeId: QuickLaunchEventTarget.medication,
        executionMode: QuickLaunchExecutionMode.prefilledForm,
      ),
    );

    await tester.pumpWidget(
      _testApp(
        layout: layout,
        onSlotPressed: (slot, _) => pressed = slot,
        onEditSlot: (index) => edited = index,
      ),
    );

    for (var index = 0; index < quickLaunchCoreSlotCount; index++) {
      expect(find.byKey(Key('quick-launch-slot-$index')), findsOneWidget);
    }
    expect(find.byKey(const Key('quick-launch-slot-5')), findsNothing);
    expect(find.byKey(const Key('quick-launch-more')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-launch-more')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('quick-launch-overflow-slot-5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quick-launch-overflow-slot-7')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('quick-launch-overflow-slot-6')));
    await tester.pumpAndSettle();
    expect(pressed?.slotIndex, 6);

    await tester.tap(find.byKey(const Key('quick-launch-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-launch-overflow-slot-5')));
    await tester.pumpAndSettle();
    expect(edited, 5);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('narrow Windows dock keeps four slots plus More and All', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp(layout: QuickLaunchLayout.empty()));

    for (var index = 0; index < 4; index++) {
      expect(find.byKey(Key('quick-launch-slot-$index')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(Key('quick-launch-slot-$index'))).width,
        greaterThanOrEqualTo(48),
      );
    }
    expect(find.byKey(const Key('quick-launch-slot-4')), findsNothing);
    expect(find.byKey(const Key('quick-launch-more')), findsOneWidget);
    expect(find.byKey(const Key('quick-launch-all')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}

Widget _testApp({
  required QuickLaunchLayout layout,
  QuickLaunchSlotCallback? onSlotPressed,
  ValueChanged<int>? onEditSlot,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: QuickLaunchDock(
        layout: layout,
        onSlotPressed: onSlotPressed ?? (_, _) {},
        onEditSlot: onEditSlot ?? (_) {},
        onOpenAll: () {},
      ),
    ),
  );
}
