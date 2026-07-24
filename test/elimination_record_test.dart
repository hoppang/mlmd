import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/elimination_record.dart';

void main() {
  group('EliminationRecord', () {
    test('round-trips urine, stool, and both kinds', () {
      final occurredAt = DateTime.parse('2026-07-24T10:15:00.000Z');
      final urine = EliminationRecord(
        kind: EliminationKind.urine,
        occurredAt: occurredAt,
      );
      final stool = EliminationRecord(
        kind: EliminationKind.stool,
        occurredAt: occurredAt,
        stoolAmount: EliminationAmount.normal,
        stoolConsistency: StoolConsistency.hard,
        stoolColor: StoolColor.brown,
        note: '관찰 메모',
      );
      final both = EliminationRecord(
        kind: EliminationKind.both,
        occurredAt: occurredAt,
        urineAmount: EliminationAmount.much,
        stoolAmount: EliminationAmount.little,
      );

      final restoredUrine = EliminationRecord.decode(urine.encode());
      final restoredStool = EliminationRecord.decode(stool.encode());
      final restoredBoth = EliminationRecord.decode(both.encode());

      expect(restoredUrine?.kind, EliminationKind.urine);
      expect(restoredUrine?.hasUrine, isTrue);
      expect(restoredUrine?.hasStool, isFalse);
      expect(restoredStool?.kind, EliminationKind.stool);
      expect(restoredStool?.stoolAmount, EliminationAmount.normal);
      expect(restoredStool?.stoolConsistency, StoolConsistency.hard);
      expect(restoredStool?.stoolColor, StoolColor.brown);
      expect(restoredStool?.note, '관찰 메모');
      expect(restoredBoth?.kind, EliminationKind.both);
      expect(restoredBoth?.urineAmount, EliminationAmount.much);
      expect(restoredBoth?.stoolAmount, EliminationAmount.little);
      expect(restoredBoth?.occurredAt, occurredAt);
    });

    test('rejects malformed and impossible payloads', () {
      expect(EliminationRecord.decode('not json'), isNull);
      expect(EliminationRecord.decode('[]'), isNull);
      expect(
        EliminationRecord.decode(
          '{"version":0,"occurredAt":"2026-07-24T10:15:00Z","urine":true,"stool":false}',
        ),
        isNull,
      );
      expect(
        EliminationRecord.decode(
          '{"version":1,"occurredAt":"2026-07-24T10:15:00Z","urine":false,"stool":false}',
        ),
        isNull,
      );
      expect(
        EliminationRecord.decode(
          '{"version":1,"occurredAt":"2026-07-24T10:15:00Z","urine":true,"stool":false,"stoolColor":"brown"}',
        ),
        isNull,
      );
      expect(
        EliminationRecord.decode(
          '{"version":1,"occurredAt":"2026-07-24T10:15:00Z","urine":false,"stool":true,"stoolConsistency":"unknown"}',
        ),
        isNull,
      );
      expect(
        EliminationRecord.decode(
          '{"version":1,"occurredAt":"invalid","urine":true,"stool":false}',
        ),
        isNull,
      );
    });

    test('changing to urine clears stool-only observations', () {
      final original = EliminationRecord(
        kind: EliminationKind.stool,
        occurredAt: DateTime(2026, 7, 24, 10),
        stoolAmount: EliminationAmount.much,
        stoolConsistency: StoolConsistency.loose,
        stoolColor: StoolColor.green,
      );

      final corrected = original.copyWith(kind: EliminationKind.urine);

      expect(corrected.kind, EliminationKind.urine);
      expect(corrected.stoolAmount, isNull);
      expect(corrected.stoolConsistency, isNull);
      expect(corrected.stoolColor, isNull);
    });
  });
}
