import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/care_procedure_record.dart';

void main() {
  test(
    'care procedure payload preserves the performed action and metadata',
    () {
      final record = CareProcedureRecord(
        recordId: 'procedure-1',
        childId: 'child-1',
        occurredAt: DateTime(2026, 7, 29, 14, 20),
        procedureType: CareProcedureType.woundCare,
        bodyArea: '왼쪽 무릎',
        note: '흐르는 물로 씻고 거즈 부착',
        createdByAuthorProfileId: 'author-1',
        createdByDeviceProfileId: 'device-1',
        createdAt: DateTime(2026, 7, 29, 14, 21),
        lastModified: DateTime(2026, 7, 29, 14, 22),
      );

      final decoded = CareProcedureRecord.decode(record.encode());

      expect(decoded, isNotNull);
      expect(decoded!.recordId, 'procedure-1');
      expect(decoded.childId, 'child-1');
      expect(decoded.occurredAt, DateTime(2026, 7, 29, 14, 20));
      expect(decoded.procedureType, CareProcedureType.woundCare);
      expect(decoded.bodyArea, '왼쪽 무릎');
      expect(decoded.note, '흐르는 물로 씻고 거즈 부착');
      expect(decoded.createdByAuthorProfileId, 'author-1');
      expect(decoded.createdByDeviceProfileId, 'device-1');
    },
  );

  test('other procedure without a description is rejected', () {
    final invalid = CareProcedureRecord(
      occurredAt: DateTime(2026, 7, 29),
      procedureType: CareProcedureType.other,
    );

    expect(invalid.isValid, isFalse);
    expect(CareProcedureRecord.decode(invalid.encode()), isNull);
  });

  test('malformed or unsupported payload is rejected', () {
    expect(CareProcedureRecord.decode(''), isNull);
    expect(
      CareProcedureRecord.decode(
        '{"schema":"mlmd.care_procedure","version":2}',
      ),
      isNull,
    );
    expect(
      CareProcedureRecord.decode(
        '{"schema":"mlmd.care_procedure","version":1,'
        '"occurredAt":"bad","procedureType":"nasalCare"}',
      ),
      isNull,
    );
  });
}
