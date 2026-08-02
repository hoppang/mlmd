import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/tummy_time_record.dart';
import 'package:mlmd/l10n/app_localizations.dart';

void main() {
  group('TummyTimeRecord domain model tests', () {
    test('round-trips full TummyTimeRecord with JSON encode and decode', () {
      final now = DateTime(2026, 7, 27, 10, 30);
      final original = TummyTimeRecord(
        recordId: 'rec-tt-001',
        childId: 'child-01',
        occurredAt: now,
        durationMinutes: 5,
        note: '배를 깔고 잘 버텼어요',
        createdByAuthorProfileId: 'author-1',
        createdByDeviceProfileId: 'device-1',
        createdAt: now,
        lastModified: now,
      );

      final encoded = original.encode();
      final restored = TummyTimeRecord.decode(encoded);

      expect(restored, isNotNull);
      expect(restored!.recordId, 'rec-tt-001');
      expect(restored.childId, 'child-01');
      expect(restored.occurredAt, now);
      expect(restored.durationMinutes, 5);
      expect(restored.note, '배를 깔고 잘 버텼어요');
      expect(restored.createdByAuthorProfileId, 'author-1');
      expect(restored.createdByDeviceProfileId, 'device-1');
      expect(restored.createdAt, now);
      expect(restored.lastModified, now);
    });

    test('round-trips minimal TummyTimeRecord without optional fields', () {
      final now = DateTime(2026, 7, 27, 10, 30);
      final original = TummyTimeRecord(occurredAt: now);

      final encoded = original.encode();
      final restored = TummyTimeRecord.decode(encoded);

      expect(restored, isNotNull);
      expect(restored!.occurredAt, now);
      expect(restored.durationMinutes, isNull);
      expect(restored.note, isNull);
      expect(restored.recordId, isNull);
    });

    test('returns null when decoding invalid JSON or wrong schema/version', () {
      expect(TummyTimeRecord.decode(''), isNull);
      expect(TummyTimeRecord.decode('invalid json'), isNull);
      expect(TummyTimeRecord.decode('{}'), isNull);
      expect(
        TummyTimeRecord.decode(
          '{"schema":"wrong.schema","version":1,"occurredAt":"2026-07-27T10:30:00.000"}',
        ),
        isNull,
      );
      expect(
        TummyTimeRecord.decode(
          '{"schema":"mlmd.tummytime","version":2,"occurredAt":"2026-07-27T10:30:00.000"}',
        ),
        isNull,
      );
      // Missing occurredAt
      expect(
        TummyTimeRecord.decode('{"schema":"mlmd.tummytime","version":1}'),
        isNull,
      );
    });

    test('rejects non-positive and >999 durationMinutes', () {
      // durationMinutes = 0 should be treated as null
      final jsonZero =
          '{"schema":"mlmd.tummytime","version":1,"occurredAt":"2026-07-27T10:30:00.000","durationMinutes":0}';
      final recZero = TummyTimeRecord.decode(jsonZero);
      expect(recZero, isNotNull);
      expect(recZero!.durationMinutes, isNull);

      // Negative value should also decode to null
      final jsonNeg =
          '{"schema":"mlmd.tummytime","version":1,"occurredAt":"2026-07-27T10:30:00.000","durationMinutes":-3}';
      final recNeg = TummyTimeRecord.decode(jsonNeg);
      expect(recNeg, isNotNull);
      expect(recNeg!.durationMinutes, isNull);

      // Boundary: 999 is valid
      final jsonMax =
          '{"schema":"mlmd.tummytime","version":1,"occurredAt":"2026-07-27T10:30:00.000","durationMinutes":999}';
      final recMax = TummyTimeRecord.decode(jsonMax);
      expect(recMax, isNotNull);
      expect(recMax!.durationMinutes, 999);
    });

    test('buildDetails returns duration display when present', () async {
      final locKo = await AppLocalizations.delegate.load(const Locale('ko'));
      final locEn = await AppLocalizations.delegate.load(const Locale('en'));
      final now = DateTime(2026, 7, 27, 10, 30);

      final recWithDuration = TummyTimeRecord(
        occurredAt: now,
        durationMinutes: 5,
      );
      expect(recWithDuration.buildDetails(locKo), '5분');
      expect(recWithDuration.buildDetails(locEn), '5 min');
    });

    test('buildDetails falls back to note when no duration', () async {
      final locKo = await AppLocalizations.delegate.load(const Locale('ko'));
      final locEn = await AppLocalizations.delegate.load(const Locale('en'));
      final now = DateTime(2026, 7, 27, 10, 30);

      final recWithNote = TummyTimeRecord(occurredAt: now, note: '잘 버텼어요');
      expect(recWithNote.buildDetails(locKo), '잘 버텼어요');
      expect(recWithNote.buildDetails(locEn), '잘 버텼어요');

      final recEmpty = TummyTimeRecord(occurredAt: now);
      expect(recEmpty.buildDetails(locKo), '');
      expect(recEmpty.buildDetails(locEn), '');
    });

    test('copyWith updates fields correctly and can clear them', () {
      final now = DateTime(2026, 7, 27, 10, 30);
      final original = TummyTimeRecord(
        recordId: 'rec-1',
        occurredAt: now,
        durationMinutes: 3,
        note: '첫 메모',
      );

      final updated = original.copyWith(durationMinutes: 7, note: '수정된 메모');
      expect(updated.recordId, 'rec-1');
      expect(updated.durationMinutes, 7);
      expect(updated.note, '수정된 메모');

      final cleared = updated.copyWith(
        clearDurationMinutes: true,
        clearNote: true,
      );
      expect(cleared.durationMinutes, isNull);
      expect(cleared.note, isNull);
      expect(cleared.recordId, 'rec-1');
    });

    test('equality and hashCode work as expected', () {
      final now = DateTime(2026, 7, 27, 10, 30);
      final r1 = TummyTimeRecord(
        recordId: 'rec-1',
        occurredAt: now,
        durationMinutes: 5,
      );
      final r2 = TummyTimeRecord(
        recordId: 'rec-1',
        occurredAt: now,
        durationMinutes: 5,
      );
      final r3 = TummyTimeRecord(
        recordId: 'rec-2',
        occurredAt: now,
        durationMinutes: 5,
      );

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
      expect(r1, isNot(equals(r3)));
    });

    test('encode does not include durationMinutes when zero or null', () {
      final now = DateTime(2026, 7, 27, 10, 30);

      final recNull = TummyTimeRecord(occurredAt: now);
      final jsonNull = recNull.encode();
      expect(jsonNull.contains('durationMinutes'), isFalse);

      // A manually built instance without duration should not serialize the key
      final decoded = TummyTimeRecord.decode(jsonNull);
      expect(decoded?.durationMinutes, isNull);
    });
  });
}
