import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/accident_injury_record.dart';
import 'package:mlmd/features/events/domain/medical_guidance.dart';
import 'package:mlmd/models/activity_entity.dart';

void main() {
  group('MedicalGuidance Accident Tests', () {
    test('high risk accident injury requires attention and provides guidance link', () {
      final record = AccidentInjuryRecord(
        occurredAt: DateTime(2026, 7, 25, 14, 0),
        category: AccidentCategory.traumatic,
        injuryType: AccidentInjuryType.fallTrip,
        note: '침대 위에서 떨어짐',
      );

      final activity = ActivityEntity(
        type: '사고·다침',
        details: '외상 · 넘어짐·낙상',
        time: DateTime(2026, 7, 25, 14, 0),
        lastModified: DateTime(2026, 7, 25, 14, 0),
        structuredDataJson: record.encode(),
      );

      final result = evaluateMedicalGuidance(activity);

      expect(result.requiresAttention, isTrue);
      expect(result.reason, '사고·다침 주의 필요');
      expect(result.links, isNotEmpty);
      expect(result.links.first.ruleId, 'aap-accident-first-aid');
    });

    test('low risk accident injury does not trigger medical guidance attention', () {
      final record = AccidentInjuryRecord(
        occurredAt: DateTime(2026, 7, 25, 14, 0),
        category: AccidentCategory.traumatic,
        injuryType: AccidentInjuryType.bumpBruise,
        note: '이마에 살짝 콕 부딪힘',
      );

      final activity = ActivityEntity(
        type: '사고·다침',
        details: '외상 · 콕 찍힘·멍',
        time: DateTime(2026, 7, 25, 14, 0),
        lastModified: DateTime(2026, 7, 25, 14, 0),
        structuredDataJson: record.encode(),
      );

      final result = evaluateMedicalGuidance(activity);

      expect(result.requiresAttention, isFalse);
    });
  });
}
