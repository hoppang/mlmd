import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/hospital_visit_record.dart';

void main() {
  group('HospitalVisitRecord Domain Tests', () {
    test('encode and decode roundtrip with note', () {
      final now = DateTime(2026, 7, 25, 14, 30);
      final record = HospitalVisitRecord(
        recordId: 'hosp-123',
        childId: 'child-001',
        visitedAt: now,
        note: '감기 증상으로 진료. 3일간 경과 관찰 필요.',
        createdByAuthorProfileId: 'author-1',
        createdByDeviceProfileId: 'device-1',
        createdAt: now,
        lastModified: now,
      );

      final jsonString = record.encode();
      final decoded = HospitalVisitRecord.decode(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.recordId, 'hosp-123');
      expect(decoded.childId, 'child-001');
      expect(decoded.visitedAt, now);
      expect(decoded.note, '감기 증상으로 진료. 3일간 경과 관찰 필요.');
      expect(decoded.createdByAuthorProfileId, 'author-1');
      expect(decoded.createdByDeviceProfileId, 'device-1');
    });

    test('encode and decode without note (minimal record)', () {
      final now = DateTime(2026, 7, 25, 10, 0);
      final record = HospitalVisitRecord(
        visitedAt: now,
      );

      final jsonString = record.encode();
      final decoded = HospitalVisitRecord.decode(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.visitedAt, now);
      expect(decoded.note, isNull);
    });

    test('decode invalid json returns null', () {
      expect(HospitalVisitRecord.decode(''), isNull);
      expect(HospitalVisitRecord.decode('invalid json'), isNull);
      expect(HospitalVisitRecord.decode('{"schema": "other"}'), isNull);
    });
  });
}
