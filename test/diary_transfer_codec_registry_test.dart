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
    expect(diary.activities.single.timePrecision, 1);

    final encoded = registry.encode(decoded, targetSchemaVersion: 1);
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
    expect(registry.latestSchemaVersion, 2);
    expect(registry.encode(decoded)['schemaVersion'], 2);
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

    final first = jsonEncode(registry.encode(document, targetSchemaVersion: 1));
    final second = jsonEncode(
      registry.encode(document, targetSchemaVersion: 1),
    );
    expect(first, second);
    expect(
      first.indexOf('446655440000'),
      lessThan(first.indexOf('446655440001')),
    );
  });

  test('unknown activity occurrence time survives a v1 round trip', () {
    final document = CanonicalExportDocument(
      exportedAt: DateTime.utc(2026, 7, 21),
      appVersion: 'test',
      diaries: [
        CanonicalDiary(
          recordId: '550e8400-e29b-41d4-a716-446655440000',
          date: DateTime(2026, 7, 21, 12),
          title: '집계 이벤트',
          summary: '',
          content: '',
          lastModified: DateTime.utc(2026, 7, 21, 3),
          activities: [
            CanonicalActivity(
              type: '수유',
              time: DateTime(2026, 7, 21, 12),
              timePrecision: 0,
              details: '여러 번',
              lastModified: DateTime.utc(2026, 7, 21, 3),
            ),
          ],
        ),
      ],
    );

    final decoded = registry.decode(
      registry.encode(document, targetSchemaVersion: 1),
    );

    expect(decoded.diaries.single.activities.single.timePrecision, 0);
  });

  test('v2 round trip preserves author, device, and record provenance', () {
    const authorId = '550e8400-e29b-41d4-a716-446655440010';
    const deviceId = '550e8400-e29b-41d4-a716-446655440020';
    final createdAt = DateTime.utc(2026, 7, 24, 1);
    final document = CanonicalExportDocument(
      exportedAt: DateTime.utc(2026, 7, 24, 2),
      appVersion: 'test',
      authorProfiles: [
        CanonicalAuthorProfile(
          authorProfileId: authorId,
          nickname: '엄마',
          colorValue: 0xFF00796B,
          createdAt: createdAt,
        ),
      ],
      deviceProfiles: [
        CanonicalDeviceProfile(deviceProfileId: deviceId, createdAt: createdAt),
      ],
      diaries: [
        CanonicalDiary(
          recordId: '550e8400-e29b-41d4-a716-446655440000',
          date: DateTime(2026, 7, 24, 10),
          title: '기록',
          summary: '',
          content: '본문',
          createdAt: createdAt,
          createdByAuthorProfileId: authorId,
          createdByDeviceProfileId: deviceId,
          lastModifiedByAuthorProfileId: authorId,
          lastModifiedByDeviceProfileId: deviceId,
          lastModified: createdAt,
          activities: [
            CanonicalActivity(
              type: '수유',
              time: DateTime(2026, 7, 24, 10),
              details: '120mL',
              structuredDataJson:
                  '{"version":1,"kind":"feeding","method":"bottle","bottleContents":"formula","amountExpression":{"kind":"exact","exactValue":120,"unit":"ml"}}',
              createdAt: createdAt,
              createdByAuthorProfileId: authorId,
              createdByDeviceProfileId: deviceId,
              lastModifiedByAuthorProfileId: authorId,
              lastModifiedByDeviceProfileId: deviceId,
              lastModified: createdAt,
            ),
          ],
        ),
      ],
    );

    final encoded = registry.encode(document);
    final decoded = registry.decode(encoded);

    expect(encoded['schemaVersion'], 2);
    expect(decoded.authorProfiles.single.nickname, '엄마');
    expect(decoded.deviceProfiles.single.deviceProfileId, deviceId);
    expect(decoded.diaries.single.createdByAuthorProfileId, authorId);
    expect(
      decoded.diaries.single.activities.single.createdByDeviceProfileId,
      deviceId,
    );
    expect(
      decoded.diaries.single.activities.single.structuredDataJson,
      contains('"kind":"feeding"'),
    );
  });

  test('v2 rejects record provenance that references a missing profile', () {
    const authorId = '550e8400-e29b-41d4-a716-446655440010';
    const deviceId = '550e8400-e29b-41d4-a716-446655440020';
    final json = <String, Object?>{
      'format': 'mlmd-diary-export',
      'schemaVersion': 2,
      'exportedAt': '2026-07-24T02:00:00.000Z',
      'appVersion': 'test',
      'authorProfiles': [
        {
          'authorProfileId': authorId,
          'nickname': '엄마',
          'colorValue': 0xFF00796B,
          'createdAt': '2026-07-24T01:00:00.000Z',
        },
      ],
      'deviceProfiles': [
        {'deviceProfileId': deviceId, 'createdAt': '2026-07-24T01:00:00.000Z'},
      ],
      'diaries': [
        {
          'recordId': '550e8400-e29b-41d4-a716-446655440000',
          'date': '2026-07-24T10:00:00.000',
          'title': '기록',
          'summary': '',
          'content': '본문',
          'createdAt': '2026-07-24T01:00:00.000Z',
          'createdByAuthorProfileId': '550e8400-e29b-41d4-a716-446655440099',
          'createdByDeviceProfileId': deviceId,
          'lastModifiedByAuthorProfileId': authorId,
          'lastModifiedByDeviceProfileId': deviceId,
          'lastModified': '2026-07-24T01:00:00.000Z',
          'activities': <Object?>[],
        },
      ],
    };

    expect(
      () => registry.decode(json),
      throwsA(
        isA<DiaryTransferException>().having(
          (error) => error.code,
          'code',
          'invalid_document',
        ),
      ),
    );
  });
}
