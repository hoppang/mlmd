import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/transfer/canonical_transfer_document.dart';
import 'package:mlmd/transfer/diary_transfer_codec_registry.dart';
import 'package:mlmd/transfer/diary_transfer_exception.dart';

void main() {
  final registry = DiaryTransferCodecRegistry.standard();

  Map<String, Object?> fixture(String name) =>
      (jsonDecode(File('test/fixtures/transfer/$name').readAsStringSync())
          as Map<String, Object?>);

  test('v1 fixture preserves multilingual text and time semantics', () {
    final decoded = registry.decode(fixture('v1_valid.mlmd.json'));

    expect(decoded.diaries, hasLength(1));
    final diary = decoded.diaries.single;
    expect(diary.content, '한국어 English 日本語 😊');
    expect(diary.summary, contains('\n'));
    expect(diary.date.isUtc, isFalse);
    expect(diary.lastModified.isUtc, isTrue);

    final encoded = registry.encode(decoded);
    expect(encoded['schemaVersion'], 1);
    final encodedDiary = (encoded['diaries'] as List).single as Map;
    expect(encodedDiary, isNot(contains('id')));
    expect(encodedDiary, isNot(contains('embedding')));
    expect((encodedDiary['date'] as String).endsWith('Z'), isFalse);
    expect((encodedDiary['lastModified'] as String).endsWith('Z'), isTrue);
    expect(encodedDiary['content'], diary.content);
  });

  test('empty fixture is valid and latest version is selected', () {
    final decoded = registry.decode(fixture('v1_minimal.mlmd.json'));
    expect(decoded.diaries, isEmpty);
    expect(registry.latestSchemaVersion, 1);
    expect(registry.encode(decoded)['schemaVersion'], 1);
  });

  test('future schema version is rejected', () {
    expect(
      () => registry.decode(fixture('v1_invalid_future.mlmd.json')),
      throwsA(
        isA<DiaryTransferException>().having(
          (error) => error.code,
          'code',
          'unsupported_schema_version',
        ),
      ),
    );
  });

  test('invalid UUID and timezone-bearing wall clock are rejected', () {
    final json = fixture('v1_valid.mlmd.json');
    final diaries = json['diaries'] as List;
    final diary = diaries.single as Map<String, Object?>;
    diary['recordId'] = 'not-a-uuid';
    diary['date'] = '2026-07-18T20:15:00.000Z';

    expect(() => registry.decode(json), throwsA(isA<DiaryTransferException>()));
  });

  test('export ordering is deterministic', () {
    CanonicalDiary diary(String id, DateTime date) => CanonicalDiary(
      recordId: id,
      date: date,
      title: '',
      summary: '',
      content: '',
      lastModified: DateTime.utc(2026),
      activities: const [],
    );
    final document = CanonicalExportDocument(
      exportedAt: DateTime.utc(2026),
      appVersion: 'test',
      diaries: [
        diary('550e8400-e29b-41d4-a716-446655440001', DateTime(2026, 2)),
        diary('550e8400-e29b-41d4-a716-446655440000', DateTime(2026, 1)),
      ],
    );

    final first = jsonEncode(registry.encode(document));
    final second = jsonEncode(registry.encode(document));
    expect(first, second);
    expect(
      first.indexOf('446655440000'),
      lessThan(first.indexOf('446655440001')),
    );
  });
}
