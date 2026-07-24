import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/intake_record.dart';

void main() {
  group('AmountExpression', () {
    test('round-trips qualitative, fraction, and exact values', () {
      const qualitative = AmountExpression.qualitative(QualitativeLevel.little);
      const fraction = AmountExpression.fraction(0.75);
      const exact = AmountExpression.exact(exactValue: 120, unit: 'ml');

      final restoredQualitative = AmountExpression.fromJson(
        qualitative.toJson(),
      );
      final restoredFraction = AmountExpression.fromJson(fraction.toJson());
      final restoredExact = AmountExpression.fromJson(exact.toJson());

      expect(restoredQualitative, isNotNull);
      expect(restoredQualitative!.qualitativeLevel, QualitativeLevel.little);

      expect(restoredFraction, isNotNull);
      expect(restoredFraction!.fraction, 0.75);

      expect(restoredExact, isNotNull);
      expect(restoredExact!.exactValue, 120);
      expect(restoredExact.unit, 'ml');
    });

    test('rejects invalid exact values and units', () {
      expect(
        AmountExpression.fromJson({
          'kind': 'exact',
          'exactValue': 0,
          'unit': 'ml',
        }),
        isNull,
      );
      expect(
        AmountExpression.fromJson({
          'kind': 'exact',
          'exactValue': 120,
          'unit': 'l',
        }),
        isNull,
      );
    });
  });

  group('IntakeRecord', () {
    test('round-trips feeding with breast details', () {
      final original = IntakeRecord(
        kind: IntakeRecordKind.feeding,
        method: FeedingMethod.breast,
        side: BreastSide.left,
        startedAt: DateTime.parse('2026-07-24T08:10:00.000Z'),
        endedAt: DateTime.parse('2026-07-24T08:18:00.000Z'),
        memo: '아침 수유',
      );

      final restored = IntakeRecord.decode(original.encode());

      expect(restored, isNotNull);
      expect(restored!.kind, IntakeRecordKind.feeding);
      expect(restored.method, FeedingMethod.breast);
      expect(restored.side, BreastSide.left);
      expect(restored.amountExpression, isNull);
      expect(restored.startedAt, DateTime.parse('2026-07-24T08:10:00.000Z'));
      expect(restored.endedAt, DateTime.parse('2026-07-24T08:18:00.000Z'));
      expect(restored.memo, '아침 수유');
    });

    test('round-trips feeding with bottle details', () {
      final original = IntakeRecord(
        kind: IntakeRecordKind.feeding,
        method: FeedingMethod.bottle,
        bottleContents: BottleContents.formula,
        amountExpression: const AmountExpression.exact(
          exactValue: 120,
          unit: 'ml',
        ),
      );

      final restored = IntakeRecord.decode(original.encode());

      expect(restored, isNotNull);
      expect(restored!.method, FeedingMethod.bottle);
      expect(restored.bottleContents, BottleContents.formula);
      expect(restored.amountExpression!.exactValue, 120);
      expect(restored.amountExpression!.unit, 'ml');
    });

    test('round-trips feeding time-only records without amount', () {
      final original = IntakeRecord(
        kind: IntakeRecordKind.feeding,
        method: FeedingMethod.timeOnly,
        memo: '짧은 수유',
      );

      final restored = IntakeRecord.decode(original.encode());

      expect(restored, isNotNull);
      expect(restored!.method, FeedingMethod.timeOnly);
      expect(restored.amountExpression, isNull);
      expect(restored.memo, '짧은 수유');
    });

    test('round-trips meal, water, and snack records', () {
      final meal = IntakeRecord(
        kind: IntakeRecordKind.meal,
        mealType: MealType.lunch,
        foodName: '죽',
        reaction: IntakeReaction.ateWell,
        amountExpression: const AmountExpression.exact(
          exactValue: 180,
          unit: 'g',
        ),
        memo: '잘 먹음',
      );
      final water = IntakeRecord(
        kind: IntakeRecordKind.water,
        amountExpression: const AmountExpression.exact(
          exactValue: 90,
          unit: 'ml',
        ),
      );
      final snack = IntakeRecord(
        kind: IntakeRecordKind.snack,
        foodName: '과일',
        reaction: IntakeReaction.average,
        amountExpression: const AmountExpression.qualitative(
          QualitativeLevel.little,
        ),
      );

      final restoredMeal = IntakeRecord.decode(meal.encode());
      final restoredWater = IntakeRecord.decode(water.encode());
      final restoredSnack = IntakeRecord.decode(snack.encode());

      expect(restoredMeal, isNotNull);
      expect(restoredMeal!.mealType, MealType.lunch);
      expect(restoredMeal.foodName, '죽');
      expect(restoredMeal.reaction, IntakeReaction.ateWell);

      expect(restoredWater, isNotNull);
      expect(restoredWater!.kind, IntakeRecordKind.water);
      expect(restoredWater.amountExpression!.exactValue, 90);

      expect(restoredSnack, isNotNull);
      expect(restoredSnack!.foodName, '과일');
      expect(restoredSnack.reaction, IntakeReaction.average);
    });

    test('returns null for malformed json and invalid combinations', () {
      expect(IntakeRecord.decode('not json'), isNull);
      expect(IntakeRecord.decode('[]'), isNull);
      expect(
        IntakeRecord.decode('{"version":0,"kind":"feeding","method":"bottle"}'),
        isNull,
      );
      expect(
        IntakeRecord.decode(
          '{"version":1,"kind":"feeding","method":"bottle","amountExpression":{"kind":"exact","exactValue":120,"unit":"ml"}}',
        ),
        isNull,
      );
      expect(
        IntakeRecord.decode(
          '{"version":1,"kind":"feeding","method":"breast","amountExpression":{"kind":"exact","exactValue":120,"unit":"ml"},"startedAt":"2026-07-24T08:10:00.000Z"}',
        ),
        isNull,
      );
      expect(
        IntakeRecord.decode('{"version":1,"kind":"meal","mealType":"lunch"}'),
        isNull,
      );
      expect(
        IntakeRecord.decode(
          '{"version":1,"kind":"water","foodName":"물","amountExpression":{"kind":"exact","exactValue":90,"unit":"ml"}}',
        ),
        isNull,
      );
      expect(
        IntakeRecord.decode(
          '{"version":1,"kind":"snack","foodName":"과일","reaction":"average"}',
        ),
        isNull,
      );
    });
  });
}
