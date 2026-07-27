import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/memo_record.dart';

void main() {
  group('MemoRecord Unit Tests', () {
    test('encode and decode round-trip preserves all fields', () {
      final now = DateTime.parse('2026-07-28T09:30:00.000Z');
      final record = MemoRecord(
        recordId: 'memo-uuid-1234',
        childId: 'child-01',
        occurredAt: now,
        content: '아기가 오늘은 기분이 좋아서 방긋 웃었다.',
        inputSource: 'stt',
        legacyTitle: '기분 좋은 아침',
        rawSttText: '아기가 오늘은 기분이 좋아서 방괏 웃었다',
        createdByAuthorProfileId: 'author-01',
        createdByDeviceProfileId: 'device-01',
        createdAt: now,
        lastModified: now,
      );

      final encoded = record.encode();
      final decoded = MemoRecord.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.recordId, equals('memo-uuid-1234'));
      expect(decoded.childId, equals('child-01'));
      expect(decoded.occurredAt, equals(now));
      expect(decoded.content, equals('아기가 오늘은 기분이 좋아서 방긋 웃었다.'));
      expect(decoded.inputSource, equals('stt'));
      expect(decoded.legacyTitle, equals('기분 좋은 아침'));
      expect(decoded.rawSttText, equals('아기가 오늘은 기분이 좋아서 방괏 웃었다'));
      expect(decoded.createdByAuthorProfileId, equals('author-01'));
    });

    test('decode invalid or empty string returns null', () {
      expect(MemoRecord.decode(''), isNull);
      expect(MemoRecord.decode('   '), isNull);
      expect(MemoRecord.decode('{"schema": "invalid"}'), isNull);
      expect(MemoRecord.decode('not a json'), isNull);
    });

    test('copyWith updates specified fields and supports clearing optionals', () {
      final now = DateTime.now();
      final original = MemoRecord(
        occurredAt: now,
        content: '원본 내용',
        legacyTitle: '기존 제목',
        rawSttText: 'STT 원문',
      );

      final updated = original.copyWith(
        content: '수정된 내용',
        clearLegacyTitle: true,
        clearRawSttText: true,
      );

      expect(updated.content, equals('수정된 내용'));
      expect(updated.legacyTitle, isNull);
      expect(updated.rawSttText, isNull);
      expect(updated.occurredAt, equals(now));
    });
  });
}
