import 'package:flutter_test/flutter_test.dart';

import 'package:mlmd/features/quick_launch/domain/quick_launch_models.dart';

void main() {
  group('QuickLaunchSlot', () {
    test('encodes and decodes JSON', () {
      final slot = QuickLaunchSlot(
        slotIndex: 2,
        eventTypeId: QuickLaunchEventTarget.diaper,
        executionMode: QuickLaunchExecutionMode.prefilledForm,
        structuredPresetJson: '{"kind":"stool"}',
        displayLabel: 'label-a',
        childId: 'child-a',
        deviceProfileId: 'device-b',
      );

      final decoded = QuickLaunchSlot.fromJsonString(slot.toJsonString());

      expect(decoded, equals(slot));
      expect(decoded.hashCode, equals(slot.hashCode));
    });

    test('copyWith preserves immutability and can clear fields', () {
      final slot = QuickLaunchSlot(
        slotIndex: 0,
        eventTypeId: QuickLaunchEventTarget.sleep,
      );

      final updated = slot.copyWith(
        clearEventType: true,
        executionMode: QuickLaunchExecutionMode.prefilledForm,
        displayLabel: 'edited',
      );

      expect(slot.eventTypeId, QuickLaunchEventTarget.sleep);
      expect(updated.eventTypeId, isNull);
      expect(updated.executionMode, QuickLaunchExecutionMode.prefilledForm);
      expect(updated.displayLabel, 'edited');
    });

    test('preserves new feeding variants in JSON', () {
      final slot = QuickLaunchSlot(
        slotIndex: 4,
        eventTypeId: QuickLaunchEventTarget.expressedMilkFeeding,
      );

      final decoded = QuickLaunchSlot.fromJsonString(slot.toJsonString());

      expect(decoded.eventTypeId, QuickLaunchEventTarget.expressedMilkFeeding);
    });
  });

  group('QuickLaunchLayout', () {
    test('always keeps eight slots', () {
      final layout = QuickLaunchLayout.empty(
        childId: 'child-a',
        deviceProfileId: 'device-b',
      );

      expect(layout.slots, hasLength(8));
      expect(layout.slots.every((slot) => slot.childId == 'child-a'), isTrue);
      expect(
        layout.slots.every((slot) => slot.deviceProfileId == 'device-b'),
        isTrue,
      );
    });

    test('encodes and decodes JSON', () {
      final layout = QuickLaunchLayout.empty().copyWithSlot(
        1,
        const QuickLaunchSlot(
          slotIndex: 1,
          eventTypeId: QuickLaunchEventTarget.memo,
          displayLabel: 'memo',
        ),
      );

      final decoded = QuickLaunchLayout.fromJsonString(layout.toJsonString());

      expect(decoded, equals(layout));
    });

    test('migrates a legacy five-slot layout without losing settings', () {
      final legacy =
          QuickLaunchLayout.empty(
            childId: 'child-a',
            deviceProfileId: 'device-b',
          ).copyWithSlot(
            4,
            const QuickLaunchSlot(
              slotIndex: 4,
              eventTypeId: QuickLaunchEventTarget.memo,
              displayLabel: 'legacy memo',
              childId: 'child-a',
              deviceProfileId: 'device-b',
            ),
          );
      final json = legacy.toJson();
      json['slots'] = (json['slots']! as List<dynamic>).take(5).toList();

      final migrated = QuickLaunchLayout.fromJson(json);

      expect(migrated.slots, hasLength(8));
      expect(migrated.slotAt(4).eventTypeId, QuickLaunchEventTarget.memo);
      expect(migrated.slotAt(4).displayLabel, 'legacy memo');
      for (var index = 5; index < 8; index++) {
        expect(migrated.slotAt(index).eventTypeId, isNull);
        expect(migrated.slotAt(index).slotIndex, index);
        expect(migrated.slotAt(index).childId, 'child-a');
        expect(migrated.slotAt(index).deviceProfileId, 'device-b');
      }
    });

    test('rejects unsupported slot counts', () {
      final json = QuickLaunchLayout.empty().toJson();
      json['slots'] = (json['slots']! as List<dynamic>).take(6).toList();

      expect(() => QuickLaunchLayout.fromJson(json), throwsFormatException);
    });
  });

  group('GrowthAgeCalculator', () {
    const calculator = GrowthAgeCalculator();

    test('handles leap day birthdays safely', () {
      final ageBand = calculator.ageBandOn(
        birthDate: DateTime(2024, 2, 29),
        asOf: DateTime(2025, 2, 28),
      );

      expect(ageBand.completedMonths, 12);
      expect(ageBand.daysIntoCurrentMonth, 0);
    });

    test('handles month-end birthdays safely', () {
      final ageBand = calculator.ageBandOn(
        birthDate: DateTime(2026, 1, 31),
        asOf: DateTime(2026, 2, 28),
      );

      expect(ageBand.completedMonths, 1);
      expect(ageBand.daysIntoCurrentMonth, 0);
    });

    test('returns milestone decision at monthly thresholds', () {
      final decision = calculator.decisionFor(
        birthDate: DateTime(2026, 1, 30),
        asOf: DateTime(2026, 4, 30),
      );

      expect(decision?.milestone, GrowthMilestone.month3);
      expect(decision?.status, GrowthRecommendationState.due);
    });

    test('recommends the newborn layout during the newborn age band', () {
      final decision = calculator.decisionFor(
        birthDate: DateTime(2026, 1, 30),
        asOf: DateTime(2026, 2, 1),
      );

      expect(decision?.milestone, GrowthMilestone.newborn);
      expect(decision?.status, GrowthRecommendationState.overdue);
    });
  });

  group('QuickLaunchRecommendationBuilder', () {
    const builder = QuickLaunchRecommendationBuilder();

    test('builds an eight slot template with five recommendation slots', () {
      final layout = builder.buildForMilestone(
        milestone: GrowthMilestone.newborn,
        childId: 'child-a',
        deviceProfileId: 'device-b',
      );

      expect(layout.slots, hasLength(8));
      expect(layout.slotAt(0).eventTypeId, QuickLaunchEventTarget.feeding);
      expect(layout.slotAt(0).executionMode, QuickLaunchExecutionMode.category);
      expect(layout.slotAt(0).childId, 'child-a');
      expect(layout.slotAt(1).eventTypeId, QuickLaunchEventTarget.diaper);
      expect(layout.slotAt(3).eventTypeId, QuickLaunchEventTarget.sleep);
      expect(layout.slotAt(4).eventTypeId, isNull);
      expect(layout.slotAt(5).eventTypeId, isNull);
      expect(layout.slotAt(7).eventTypeId, isNull);
    });

    test('builds a month6 template', () {
      final layout = builder.buildForMilestone(
        milestone: GrowthMilestone.month6,
      );

      expect(layout.slotAt(0).eventTypeId, QuickLaunchEventTarget.feeding);
      expect(layout.slotAt(0).executionMode, QuickLaunchExecutionMode.category);
      expect(layout.slotAt(1).eventTypeId, QuickLaunchEventTarget.meal);
      expect(layout.slotAt(2).eventTypeId, QuickLaunchEventTarget.water);
      expect(layout.slotAt(3).eventTypeId, QuickLaunchEventTarget.sleep);
    });
  });
}
