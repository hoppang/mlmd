import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/sleep_record.dart';

void main() {
  group('SleepRecord', () {
    test('round-trips an active record with markers and note', () {
      final original = SleepRecord(
        status: SleepRecordStatus.active,
        kind: SleepRecordKind.unspecified,
        source: SleepRecordSource.suggested,
        startedAt: DateTime.parse('2026-07-24T01:15:00.000Z'),
        markers: const [SleepRecordMarker.restful, SleepRecordMarker.wokeUp],
        note: 'resting now',
      );

      final restored = SleepRecord.decode(original.encode());

      expect(restored, isNotNull);
      expect(restored!.status, SleepRecordStatus.active);
      expect(restored.kind, SleepRecordKind.unspecified);
      expect(restored.source, SleepRecordSource.suggested);
      expect(restored.startedAt, DateTime.parse('2026-07-24T01:15:00.000Z'));
      expect(restored.endedAt, isNull);
      expect(restored.markers, [
        SleepRecordMarker.restful,
        SleepRecordMarker.wokeUp,
      ]);
      expect(restored.note, 'resting now');
    });

    test('round-trips a completed record with end metadata', () {
      final original = SleepRecord(
        status: SleepRecordStatus.completed,
        kind: SleepRecordKind.nap,
        source: SleepRecordSource.user,
        startedAt: DateTime.parse('2026-07-24T08:10:00.000Z'),
        endedAt: DateTime.parse('2026-07-24T08:50:00.000Z'),
        markers: const [SleepRecordMarker.frequentWaking],
        endedByAuthorProfileId: 'author-1',
        endedByDeviceProfileId: 'device-1',
      );

      final restored = SleepRecord.decode(original.encode());

      expect(restored, isNotNull);
      expect(restored!.status, SleepRecordStatus.completed);
      expect(restored.endedAt, DateTime.parse('2026-07-24T08:50:00.000Z'));
      expect(restored.endedByAuthorProfileId, 'author-1');
      expect(restored.endedByDeviceProfileId, 'device-1');
      expect(restored.markers, [SleepRecordMarker.frequentWaking]);
    });

    test('returns null for malformed or unsupported json', () {
      expect(SleepRecord.decode('not json'), isNull);
      expect(SleepRecord.decode('[]'), isNull);
      expect(SleepRecord.decode('{"version":0}'), isNull);
      expect(
        SleepRecord.decode(
          '{"version":1,"status":"active","kind":"nap","source":"suggested","startedAt":"2026-07-24T01:15:00.000Z","endedAt":"2026-07-24T01:20:00.000Z"}',
        ),
        isNull,
      );
      expect(
        SleepRecord.decode(
          '{"version":1,"status":"completed","kind":"night","source":"user","startedAt":"2026-07-24T01:15:00.000Z"}',
        ),
        isNull,
      );
      expect(
        SleepRecord.decode(
          '{"version":1,"status":"completed","kind":"night","source":"user","startedAt":"2026-07-24T01:15:00.000Z","endedAt":"2026-07-24T01:10:00.000Z"}',
        ),
        isNull,
      );
      expect(
        SleepRecord.decode(
          '{"version":1,"status":"completed","kind":"night","source":"user","startedAt":"2026-07-24T01:15:00.000Z","markers":["restful","restful"]}',
        ),
        isNull,
      );
      expect(
        SleepRecord.decode(
          '{"version":1,"status":"completed","kind":"night","source":"user","startedAt":"2026-07-24T01:15:00.000Z","markers":["unknown"]}',
        ),
        isNull,
      );
    });

    test('copyWith produces a modified immutable record', () {
      final original = SleepRecord(
        status: SleepRecordStatus.active,
        kind: SleepRecordKind.night,
        source: SleepRecordSource.user,
        startedAt: DateTime.parse('2026-07-24T01:15:00.000Z'),
      );

      final updated = original.copyWith(
        status: SleepRecordStatus.completed,
        endedAt: DateTime.parse('2026-07-24T07:30:00.000Z'),
        markers: const [SleepRecordMarker.restless],
      );

      expect(original.status, SleepRecordStatus.active);
      expect(original.endedAt, isNull);
      expect(updated.status, SleepRecordStatus.completed);
      expect(updated.endedAt, DateTime.parse('2026-07-24T07:30:00.000Z'));
      expect(updated.markers, [SleepRecordMarker.restless]);
    });
  });
}
