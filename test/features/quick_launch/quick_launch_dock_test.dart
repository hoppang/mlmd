import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mlmd/features/quick_launch/domain/quick_launch_models.dart';
import 'package:mlmd/features/quick_launch/presentation/quick_launch_dock.dart';
import 'package:mlmd/l10n/app_localizations.dart';

void main() {
  testWidgets('shows five fixed user slots and a fixed all button', (
    tester,
  ) async {
    QuickLaunchSlot? pressed;
    int? edited;
    var openedAll = false;
    final layout = QuickLaunchLayout(
      slots: [
        const QuickLaunchSlot(
          slotIndex: 0,
          eventTypeId: QuickLaunchEventTarget.feeding,
        ),
        const QuickLaunchSlot(
          slotIndex: 1,
          eventTypeId: QuickLaunchEventTarget.medication,
          executionMode: QuickLaunchExecutionMode.prefilledForm,
        ),
        const QuickLaunchSlot(slotIndex: 2),
        const QuickLaunchSlot(
          slotIndex: 3,
          eventTypeId: QuickLaunchEventTarget.sleep,
        ),
        const QuickLaunchSlot(slotIndex: 4),
      ],
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
    for (var index = 0; index < quickLaunchSlotCount; index++) {
      expect(find.byKey(Key('quick-launch-slot-$index')), findsOneWidget);
    }
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
    final layout = QuickLaunchLayout(
      slots: [
        const QuickLaunchSlot(
          slotIndex: 0,
          eventTypeId: QuickLaunchEventTarget.feeding,
        ),
        const QuickLaunchSlot(
          slotIndex: 1,
          eventTypeId: QuickLaunchEventTarget.medication,
          executionMode: QuickLaunchExecutionMode.prefilledForm,
        ),
        const QuickLaunchSlot(slotIndex: 2),
        const QuickLaunchSlot(slotIndex: 3),
        const QuickLaunchSlot(slotIndex: 4),
      ],
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

  testWidgets('fits all six buttons at 320 logical pixels', (tester) async {
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
    for (var index = 0; index < quickLaunchSlotCount; index++) {
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
}
