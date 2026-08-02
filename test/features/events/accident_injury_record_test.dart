import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/accident_injury_record.dart';

void main() {
  group('AccidentInjuryRecord Domain Tests', () {
    test('encode and decode roundtrip with full fields', () {
      final now = DateTime(2026, 7, 25, 14, 20);
      final record = AccidentInjuryRecord(
        recordId: 'acc-101',
        childId: 'child-1',
        occurredAt: now,
        category: AccidentCategory.traumatic,
        injuryType: AccidentInjuryType.bumpBruise,
        customType: '미끄럼틀 충돌',
        note: '이마 오른쪽 콕 찍히며 살짝 멍듦',
        createdByAuthorProfileId: 'author-1',
        createdByDeviceProfileId: 'device-1',
        createdAt: now,
        lastModified: now,
      );

      final jsonString = record.encode();
      final decoded = AccidentInjuryRecord.decode(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.recordId, 'acc-101');
      expect(decoded.childId, 'child-1');
      expect(decoded.occurredAt, now);
      expect(decoded.category, AccidentCategory.traumatic);
      expect(decoded.injuryType, AccidentInjuryType.bumpBruise);
      expect(decoded.customType, '미끄럼틀 충돌');
      expect(decoded.note, '이마 오른쪽 콕 찍히며 살짝 멍듦');
      expect(decoded.createdByAuthorProfileId, 'author-1');
      expect(decoded.createdByDeviceProfileId, 'device-1');
    });

    test('encode and decode roundtrip for non-traumatic category', () {
      final now = DateTime(2026, 7, 25, 15, 0);
      final record = AccidentInjuryRecord(
        occurredAt: now,
        category: AccidentCategory.nonTraumatic,
        injuryType: AccidentInjuryType.foreignIngestion,
        note: '작은 스티커 조각 삼킴 관찰',
      );

      final jsonString = record.encode();
      final decoded = AccidentInjuryRecord.decode(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.category, AccidentCategory.nonTraumatic);
      expect(decoded.injuryType, AccidentInjuryType.foreignIngestion);
      expect(decoded.note, '작은 스티커 조각 삼킴 관찰');
    });

    test('category mapping and attention requirement check', () {
      expect(
        AccidentInjuryType.bumpBruise.category,
        AccidentCategory.traumatic,
      );
      expect(
        AccidentInjuryType.scratchWound.category,
        AccidentCategory.traumatic,
      );
      expect(AccidentInjuryType.fallTrip.category, AccidentCategory.traumatic);
      expect(
        AccidentInjuryType.foreignIngestion.category,
        AccidentCategory.nonTraumatic,
      );
      expect(
        AccidentInjuryType.chokingAspiration.category,
        AccidentCategory.nonTraumatic,
      );

      expect(AccidentInjuryType.fallTrip.requiresAttention, isTrue);
      expect(AccidentInjuryType.burn.requiresAttention, isTrue);
      expect(AccidentInjuryType.foreignIngestion.requiresAttention, isTrue);
      expect(AccidentInjuryType.chokingAspiration.requiresAttention, isTrue);
      expect(AccidentInjuryType.poisoningChemical.requiresAttention, isTrue);
      expect(AccidentInjuryType.bumpBruise.requiresAttention, isFalse);
    });

    test('copyWith updates specified fields', () {
      final now = DateTime(2026, 7, 25, 10, 0);
      final record = AccidentInjuryRecord(
        occurredAt: now,
        category: AccidentCategory.traumatic,
        injuryType: AccidentInjuryType.bumpBruise,
      );

      final updated = record.copyWith(
        category: AccidentCategory.nonTraumatic,
        injuryType: AccidentInjuryType.poisoningChemical,
        note: '약물 세제 접촉 의심',
      );

      expect(updated.category, AccidentCategory.nonTraumatic);
      expect(updated.injuryType, AccidentInjuryType.poisoningChemical);
      expect(updated.note, '약물 세제 접촉 의심');
      expect(updated.occurredAt, now);
    });

    test('decode invalid json returns null', () {
      expect(AccidentInjuryRecord.decode(''), isNull);
      expect(AccidentInjuryRecord.decode('invalid json'), isNull);
      expect(AccidentInjuryRecord.decode('{"schema": "other"}'), isNull);
    });
  });
}
