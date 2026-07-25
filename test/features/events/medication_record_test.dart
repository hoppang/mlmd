import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/antipyretic_duplicate_check.dart';
import 'package:mlmd/features/events/domain/medical_guidance.dart';
import 'package:mlmd/features/events/domain/medication_record.dart';
import 'package:mlmd/l10n/app_localizations_ko.dart';
import 'package:mlmd/models/activity_entity.dart';

void main() {
  final loc = AppLocalizationsKo();

  group('MedicationRecord domain model tests', () {
    test('Encodes and decodes general medication record correctly', () {
      final now = DateTime.utc(2026, 7, 25, 10, 0);
      final original = MedicationRecord(
        medicationId: 'med-1',
        category: MedicationCategory.coughCold,
        medicationName: '기침약·감기약',
        route: MedicationRoute.oral,
        administeredAt: now,
        amount: 5.0,
        unit: 'mL',
        note: '식후 30분 복용',
      );

      final encoded = original.encode();
      final decoded = MedicationRecord.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.medicationId, 'med-1');
      expect(decoded.category, MedicationCategory.coughCold);
      expect(decoded.route, MedicationRoute.oral);
      expect(decoded.administeredAt, now);
      expect(decoded.amount, 5.0);
      expect(decoded.unit, 'mL');
      expect(decoded.note, '식후 30분 복용');
      expect(decoded.requiresIngredientCheck, isFalse);
    });

    test('Encodes and decodes antipyretic record with known ingredient', () {
      final now = DateTime.utc(2026, 7, 25, 12, 30);
      final original = MedicationRecord(
        medicationId: 'med-2',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: now,
        ingredient: AntipyreticIngredient.acetaminophen,
        amount: 2.5,
        unit: 'mL',
      );

      final encoded = original.encode();
      final decoded = MedicationRecord.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.isAntipyretic, isTrue);
      expect(decoded.ingredient, AntipyreticIngredient.acetaminophen);
      expect(decoded.requiresIngredientCheck, isFalse);

      final details = medicationRecordDetails(loc, decoded);
      expect(details, contains('아세트아미노펜'));
      expect(details, contains('2.5mL'));
    });

    test('Flags requiresIngredientCheck for antipyretic with unknown ingredient', () {
      final now = DateTime.utc(2026, 7, 25, 14, 0);
      final record = MedicationRecord(
        medicationId: 'med-3',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: now,
        ingredient: AntipyreticIngredient.unknown,
        amount: 3.0,
        unit: 'mL',
      );

      expect(record.isAntipyretic, isTrue);
      expect(record.requiresIngredientCheck, isTrue);

      final details = medicationRecordDetails(loc, record);
      expect(details, contains('모름'));
      expect(details, contains('3mL'));
    });

    test('Formats topical medication details with application site correctly', () {
      final now = DateTime.utc(2026, 7, 25, 15, 0);
      final record = MedicationRecord(
        medicationId: 'med-4',
        category: MedicationCategory.ointment,
        medicationName: '연고·크림',
        route: MedicationRoute.topical,
        administeredAt: now,
        administrationSite: '오른쪽 팔',
      );

      final details = medicationRecordDetails(loc, record);
      expect(details, contains('연고·크림'));
      expect(details, contains('오른쪽 팔'));
      expect(details, contains('바르는 약'));
    });
  });

  group('Antipyretic Duplicate Check tests', () {
    test('Detects same ingredient antipyretic duplicate within time window', () {
      final baseTime = DateTime.utc(2026, 7, 25, 18, 0);

      final existingRecord = MedicationRecord(
        medicationId: 'med-old',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: baseTime,
        ingredient: AntipyreticIngredient.acetaminophen,
        amount: 2.5,
      );

      final existingActivity = ActivityEntity(
        id: 1,
        recordId: 'rec-old',
        type: '투약',
        details: '해열제 · 아세트아미노펜 · 2.5mL',
        time: baseTime,
        lastModified: baseTime,
        structuredDataJson: existingRecord.encode(),
        createdByDeviceProfileId: 'device-A',
      );

      final newRecord = MedicationRecord(
        medicationId: 'med-new',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: baseTime.add(const Duration(hours: 1)),
        ingredient: AntipyreticIngredient.acetaminophen,
        amount: 2.5,
      );

      final candidate = findAntipyreticDuplicateCandidate(
        newRecord: newRecord,
        newRecordId: 'rec-new',
        existingActivities: [existingActivity],
      );

      expect(candidate, isNotNull);
      expect(candidate!.relation, AntipyreticDuplicateRelation.sameIngredient);
    });

    test('Detects different ingredient antipyretic cross-dosing within time window', () {
      final baseTime = DateTime.utc(2026, 7, 25, 18, 0);

      final existingRecord = MedicationRecord(
        medicationId: 'med-old',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: baseTime,
        ingredient: AntipyreticIngredient.acetaminophen,
        amount: 2.5,
      );

      final existingActivity = ActivityEntity(
        id: 1,
        recordId: 'rec-old',
        type: '투약',
        details: '해열제 · 아세트아미노펜 · 2.5mL',
        time: baseTime,
        lastModified: baseTime,
        structuredDataJson: existingRecord.encode(),
        createdByDeviceProfileId: 'device-A',
      );

      final newRecord = MedicationRecord(
        medicationId: 'med-new',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: baseTime.add(const Duration(hours: 2)),
        ingredient: AntipyreticIngredient.ibuprofen,
        amount: 3.0,
      );

      final candidate = findAntipyreticDuplicateCandidate(
        newRecord: newRecord,
        newRecordId: 'rec-new',
        existingActivities: [existingActivity],
      );

      expect(candidate, isNotNull);
      expect(candidate!.relation, AntipyreticDuplicateRelation.differentIngredient);
    });

    test('Detects unknown ingredient antipyretic relation within time window', () {
      final baseTime = DateTime.utc(2026, 7, 25, 18, 0);

      final existingRecord = MedicationRecord(
        medicationId: 'med-old',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: baseTime,
        ingredient: AntipyreticIngredient.unknown,
      );

      final existingActivity = ActivityEntity(
        id: 1,
        recordId: 'rec-old',
        type: '투약',
        details: '해열제 · 성분 모름',
        time: baseTime,
        lastModified: baseTime,
        structuredDataJson: existingRecord.encode(),
      );

      final newRecord = MedicationRecord(
        medicationId: 'med-new',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: baseTime.add(const Duration(hours: 1)),
        ingredient: AntipyreticIngredient.acetaminophen,
      );

      final candidate = findAntipyreticDuplicateCandidate(
        newRecord: newRecord,
        newRecordId: 'rec-new',
        existingActivities: [existingActivity],
      );

      expect(candidate, isNotNull);
      expect(candidate!.relation, AntipyreticDuplicateRelation.unknownIngredient);
    });

    test('Returns null when antipyretic records are outside 6-hour window', () {
      final baseTime = DateTime.utc(2026, 7, 25, 10, 0);

      final existingRecord = MedicationRecord(
        medicationId: 'med-old',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: baseTime,
        ingredient: AntipyreticIngredient.acetaminophen,
      );

      final existingActivity = ActivityEntity(
        id: 1,
        recordId: 'rec-old',
        type: '투약',
        details: '해열제 · 아세트아미노펜',
        time: baseTime,
        lastModified: baseTime,
        structuredDataJson: existingRecord.encode(),
      );

      final newRecord = MedicationRecord(
        medicationId: 'med-new',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: baseTime.add(const Duration(hours: 7)),
        ingredient: AntipyreticIngredient.acetaminophen,
      );

      final candidate = findAntipyreticDuplicateCandidate(
        newRecord: newRecord,
        newRecordId: 'rec-new',
        existingActivities: [existingActivity],
      );

      expect(candidate, isNull);
    });
  });

  group('Medical Guidance evaluation for MedicationRecord', () {
    test('Triggers medical attention warning for unknown ingredient antipyretic', () {
      final now = DateTime.now();
      final record = MedicationRecord(
        medicationId: 'med-unk',
        category: MedicationCategory.antipyretic,
        medicationName: '해열제',
        route: MedicationRoute.oral,
        administeredAt: now,
        ingredient: AntipyreticIngredient.unknown,
      );

      final activity = ActivityEntity(
        id: 1,
        recordId: 'rec-unk',
        type: '투약',
        details: '해열제 · 성분 모름',
        time: now,
        lastModified: now,
        structuredDataJson: record.encode(),
      );

      final evaluation = evaluateMedicalGuidance(activity);
      expect(evaluation.requiresAttention, isTrue);
      expect(evaluation.reason, '성분 확인 필요');
    });
  });
}
