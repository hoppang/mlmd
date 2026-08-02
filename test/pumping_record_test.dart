import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/pumping_record.dart';
import 'package:mlmd/l10n/app_localizations.dart';

void main() {
  group('PumpingRecord domain model tests', () {
    test('round-trips full PumpingRecord with JSON encode and decode', () {
      final now = DateTime(2026, 7, 26, 10, 0);
      final original = PumpingRecord(
        recordId: 'rec-101',
        childId: 'child-01',
        occurredAt: now,
        amountMl: 120,
        side: PumpingSide.both,
        note: '양쪽 유축 120mL 완료',
        createdByAuthorProfileId: 'author-1',
        createdByDeviceProfileId: 'device-1',
        createdAt: now,
        lastModified: now,
      );

      final encoded = original.encode();
      final restored = PumpingRecord.decode(encoded);

      expect(restored, isNotNull);
      expect(restored!.recordId, 'rec-101');
      expect(restored.childId, 'child-01');
      expect(restored.occurredAt, now);
      expect(restored.amountMl, 120);
      expect(restored.side, PumpingSide.both);
      expect(restored.note, '양쪽 유축 120mL 완료');
      expect(restored.createdByAuthorProfileId, 'author-1');
      expect(restored.createdByDeviceProfileId, 'device-1');
      expect(restored.createdAt, now);
      expect(restored.lastModified, now);
    });

    test('round-trips minimal PumpingRecord without optional fields', () {
      final now = DateTime(2026, 7, 26, 10, 0);
      final original = PumpingRecord(occurredAt: now);

      final encoded = original.encode();
      final restored = PumpingRecord.decode(encoded);

      expect(restored, isNotNull);
      expect(restored!.occurredAt, now);
      expect(restored.amountMl, isNull);
      expect(restored.side, PumpingSide.unknown);
      expect(restored.note, isNull);
    });

    test('returns null when decoding invalid JSON or wrong schema/version', () {
      expect(PumpingRecord.decode(''), isNull);
      expect(PumpingRecord.decode('invalid json'), isNull);
      expect(PumpingRecord.decode('{}'), isNull);
      expect(
        PumpingRecord.decode(
          '{"schema":"wrong.schema","version":1,"occurredAt":"2026-07-26T10:00:00.000"}',
        ),
        isNull,
      );
      expect(
        PumpingRecord.decode(
          '{"schema":"mlmd.pumping","version":2,"occurredAt":"2026-07-26T10:00:00.000"}',
        ),
        isNull,
      );
    });

    test('defaults unknown side string to PumpingSide.unknown', () {
      final json =
          '{"schema":"mlmd.pumping","version":1,"occurredAt":"2026-07-26T10:00:00.000","side":"invalid_side"}';
      final record = PumpingRecord.decode(json);
      expect(record, isNotNull);
      expect(record!.side, PumpingSide.unknown);
    });

    test(
      'buildDetails formats string correctly according to amount and side',
      () async {
        final locKo = await AppLocalizations.delegate.load(const Locale('ko'));
        final locEn = await AppLocalizations.delegate.load(const Locale('en'));

        final now = DateTime(2026, 7, 26, 10, 0);

        final recBoth = PumpingRecord(
          occurredAt: now,
          amountMl: 120,
          side: PumpingSide.both,
        );
        expect(recBoth.buildDetails(locKo), '120mL · 양쪽');
        expect(recBoth.buildDetails(locEn), '120mL · Both');

        final recLeft = PumpingRecord(
          occurredAt: now,
          amountMl: 90,
          side: PumpingSide.left,
        );
        expect(recLeft.buildDetails(locKo), '90mL · 왼쪽');
        expect(recLeft.buildDetails(locEn), '90mL · Left');

        final recAmountOnly = PumpingRecord(
          occurredAt: now,
          amountMl: 150,
          side: PumpingSide.unknown,
        );
        expect(recAmountOnly.buildDetails(locKo), '150mL');
        expect(recAmountOnly.buildDetails(locEn), '150mL');

        final recSideOnly = PumpingRecord(
          occurredAt: now,
          side: PumpingSide.right,
        );
        expect(recSideOnly.buildDetails(locKo), '오른쪽');
        expect(recSideOnly.buildDetails(locEn), 'Right');

        final recEmpty = PumpingRecord(occurredAt: now);
        expect(recEmpty.buildDetails(locKo), '');
        expect(recEmpty.buildDetails(locEn), '');
      },
    );

    test(
      'copyWith produces correct modified instance and can clear fields',
      () {
        final now = DateTime(2026, 7, 26, 10, 0);
        final record = PumpingRecord(
          occurredAt: now,
          amountMl: 120,
          side: PumpingSide.left,
          note: '기초 메모',
        );

        final updated = record.copyWith(amountMl: 160, side: PumpingSide.both);

        expect(updated.amountMl, 160);
        expect(updated.side, PumpingSide.both);
        expect(updated.note, '기초 메모');

        final cleared = updated.copyWith(clearAmountMl: true, clearNote: true);

        expect(cleared.amountMl, isNull);
        expect(cleared.note, isNull);
        expect(cleared.side, PumpingSide.both);
      },
    );
  });
}
