import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mlmd/features/quick_launch/application/quick_launch_preferences.dart';
import 'package:mlmd/features/quick_launch/domain/quick_launch_models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps layouts separate for each child and device', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = QuickLaunchPreferencesRepository(preferences);
    final first = QuickLaunchLayout.empty(
      childId: 'child-a',
      deviceProfileId: 'device-a',
    ).copyWithSlot(
      0,
      const QuickLaunchSlot(
        slotIndex: 0,
        eventTypeId: QuickLaunchEventTarget.medication,
        executionMode: QuickLaunchExecutionMode.prefilledForm,
        childId: 'child-a',
        deviceProfileId: 'device-a',
      ),
    );
    await repository.saveLayout(first);

    expect(
      repository
          .loadLayout(childId: 'child-a', deviceProfileId: 'device-a')
          .slotAt(0)
          .eventTypeId,
      QuickLaunchEventTarget.medication,
    );
    expect(
      repository
          .loadLayout(childId: 'child-b', deviceProfileId: 'device-a')
          .slotAt(0)
          .eventTypeId,
      QuickLaunchEventTarget.feeding,
    );
  });
}
