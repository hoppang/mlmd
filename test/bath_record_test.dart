import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/bath_record.dart';
import 'package:mlmd/l10n/app_localizations.dart';

void main() {
  group('BathRecord domain model tests', () {
    test('round-trips full BathRecord with JSON encode and decode', () {
      final now = DateTime(2026, 7, 26, 19, 30);
      final original = BathRecord(
        recordId: 'rec-bath-001',
        childId: 'child-01',
        occurredAt: now,
        isQuickBath: true,
        note: '따뜻한 물로 목욕 완료',
        createdByAuthorProfileId: 'author-1',
        createdByDeviceProfileId: 'device-1',
        createdAt: now,
        lastModified: now,
      );

      final encoded = original.encode();
      final restored = BathRecord.decode(encoded);

      expect(restored, isNotNull);
      expect(restored!.recordId, 'rec-bath-001');
      expect(restored.childId, 'child-01');
      expect(restored.occurredAt, now);
      expect(restored.isQuickBath, isTrue);
      expect(restored.note, '따뜻한 물로 목욕 완료');
      expect(restored.createdByAuthorProfileId, 'author-1');
      expect(restored.createdByDeviceProfileId, 'device-1');
      expect(restored.createdAt, now);
      expect(restored.lastModified, now);
    });

    test('round-trips minimal BathRecord without optional fields', () {
      final now = DateTime(2026, 7, 26, 19, 30);
      final original = BathRecord(occurredAt: now);

      final encoded = original.encode();
      final restored = BathRecord.decode(encoded);

      expect(restored, isNotNull);
      expect(restored!.occurredAt, now);
      expect(restored.isQuickBath, isTrue);
      expect(restored.note, isNull);
    });

    test('returns null when decoding invalid JSON or wrong schema/version', () {
      expect(BathRecord.decode(''), isNull);
      expect(BathRecord.decode('invalid json'), isNull);
      expect(BathRecord.decode('{}'), isNull);
      expect(
        BathRecord.decode(
          '{"schema":"wrong.schema","version":1,"occurredAt":"2026-07-26T19:30:00.000"}',
        ),
        isNull,
      );
      expect(
        BathRecord.decode(
          '{"schema":"mlmd.bath","version":2,"occurredAt":"2026-07-26T19:30:00.000"}',
        ),
        isNull,
      );
    });

    test('buildDetails formats string correctly according to note', () async {
      final locKo = await AppLocalizations.delegate.load(const Locale('ko'));
      final locEn = await AppLocalizations.delegate.load(const Locale('en'));

      final now = DateTime(2026, 7, 26, 19, 30);

      final recWithNote = BathRecord(occurredAt: now, note: '기분 좋게 목욕함');
      expect(recWithNote.buildDetails(locKo), '기분 좋게 목욕함');
      expect(recWithNote.buildDetails(locEn), '기분 좋게 목욕함');

      final recNoNote = BathRecord(occurredAt: now);
      expect(recNoNote.buildDetails(locKo), '');
      expect(recNoNote.buildDetails(locEn), '');
    });

    test('copyWith updates fields correctly', () {
      final now = DateTime(2026, 7, 26, 19, 30);
      final original = BathRecord(
        recordId: 'rec-1',
        occurredAt: now,
        note: '첫 메모',
      );

      final updated = original.copyWith(note: '수정된 메모', isQuickBath: false);

      expect(updated.recordId, 'rec-1');
      expect(updated.note, '수정된 메모');
      expect(updated.isQuickBath, isFalse);

      final cleared = updated.copyWith(clearNote: true);
      expect(cleared.note, isNull);
    });

    test('equality and hashCode work as expected', () {
      final now = DateTime(2026, 7, 26, 19, 30);
      final r1 = BathRecord(recordId: 'rec-1', occurredAt: now, note: '목욕');
      final r2 = BathRecord(recordId: 'rec-1', occurredAt: now, note: '목욕');
      final r3 = BathRecord(recordId: 'rec-2', occurredAt: now, note: '목욕');

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
      expect(r1, isNot(equals(r3)));
    });
  });
}
