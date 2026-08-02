import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/vaccination_record.dart';

void main() {
  group('VaccinationRecord Domain Tests', () {
    test('encode and decode roundtrip with note', () {
      final now = DateTime(2026, 7, 25, 10, 30);
      final record = VaccinationRecord(
        recordId: 'vac-123',
        childId: 'child-001',
        vaccinatedAt: now,
        note: 'BCG 피내용 접종 완료.',
        createdByAuthorProfileId: 'author-1',
        createdByDeviceProfileId: 'device-1',
        createdAt: now,
        lastModified: now,
      );

      final jsonString = record.encode();
      final decoded = VaccinationRecord.decode(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.recordId, 'vac-123');
      expect(decoded.childId, 'child-001');
      expect(decoded.vaccinatedAt, now);
      expect(decoded.note, 'BCG 피내용 접종 완료.');
      expect(decoded.createdByAuthorProfileId, 'author-1');
      expect(decoded.createdByDeviceProfileId, 'device-1');
    });

    test('encode and decode without note (minimal record)', () {
      final now = DateTime(2026, 7, 25, 10, 30);
      final record = VaccinationRecord(vaccinatedAt: now);

      final jsonString = record.encode();
      final decoded = VaccinationRecord.decode(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.vaccinatedAt, now);
      expect(decoded.note, isNull);
    });

    test('decode invalid json returns null', () {
      expect(VaccinationRecord.decode(''), isNull);
      expect(VaccinationRecord.decode('invalid json'), isNull);
      expect(VaccinationRecord.decode('{"schema": "other"}'), isNull);
    });
  });
}
