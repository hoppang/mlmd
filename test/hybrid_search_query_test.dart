import 'package:flutter_test/flutter_test.dart';

import 'package:mlmd/features/search/domain/hybrid_search_query.dart';

void main() {
  group('HybridSearchQuery', () {
    test('copyWith preserves values and supports explicit clearing', () {
      final original = HybridSearchQuery(
        text: '투약',
        from: DateTime(2026, 7, 1),
        untilExclusive: DateTime(2026, 7, 2),
        eventKind: SearchEventKind.medication,
        authorProfileId: 'author-1',
        temperature: const TemperatureFilter(
          value: 38,
          comparison: NumericComparison.atLeast,
        ),
      );

      final updated = original.copyWith(text: '열');
      expect(updated.text, '열');
      expect(updated.eventKind, SearchEventKind.medication);
      expect(updated.authorProfileId, 'author-1');

      final cleared = original.copyWith(
        text: '',
        from: null,
        untilExclusive: null,
        eventKind: null,
        authorProfileId: null,
        temperature: null,
      );
      expect(cleared.text, '');
      expect(cleared.from, isNull);
      expect(cleared.untilExclusive, isNull);
      expect(cleared.eventKind, isNull);
      expect(cleared.authorProfileId, isNull);
      expect(cleared.temperature, isNull);
      expect(cleared.hasCriteria, isFalse);
    });

    test('clear returns an empty query', () {
      const original = HybridSearchQuery(text: 'hello');
      expect(original.clear().hasCriteria, isFalse);
    });
  });

  group('HybridSearchQueryParser', () {
    const parser = HybridSearchQueryParser();
    final now = DateTime(2026, 7, 23, 15);

    test(
      'parses Korean keywords, date preset, temperature and author nickname',
      () {
        final interpreted = parser.parse(
          '엄마 오늘 38도 이상 열 수유',
          now: now,
          authorNicknames: const ['엄마', '아빠'],
          authorProfileIdsByNickname: const {'엄마': 'author-mom'},
        );

        expect(interpreted.datePreset, SearchDatePreset.today);
        expect(interpreted.matchedAuthorNickname, '엄마');
        expect(interpreted.query.authorProfileId, 'author-mom');
        expect(interpreted.query.eventKind, SearchEventKind.feeding);
        expect(interpreted.query.temperature, isNotNull);
        expect(interpreted.query.temperature!.value, 38);
        expect(
          interpreted.query.temperature!.comparison,
          NumericComparison.atLeast,
        );
        expect(interpreted.query.from, DateTime(2026, 7, 23));
        expect(interpreted.query.untilExclusive, DateTime(2026, 7, 24));
        expect(interpreted.query.text, isEmpty);
      },
    );

    test('parses English temperature wording and last 7 days', () {
      final interpreted = parser.parse(
        'mom 38C or above medication last 7 days',
        now: now,
        authorNicknames: const ['mom'],
        authorProfileIdsByNickname: const {'mom': 'author-mom'},
      );

      expect(interpreted.datePreset, SearchDatePreset.last7Days);
      expect(interpreted.query.eventKind, SearchEventKind.medication);
      expect(interpreted.query.temperature?.value, 38);
      expect(interpreted.query.from, DateTime(2026, 7, 17));
      expect(interpreted.query.untilExclusive, DateTime(2026, 7, 24));
    });

    test('parses Japanese keyword and last 30 days', () {
      final interpreted = parser.parse('病院 38度以上 最近30日', now: now);

      expect(interpreted.datePreset, SearchDatePreset.last30Days);
      expect(interpreted.query.eventKind, SearchEventKind.hospital);
      expect(interpreted.query.temperature?.value, 38);
      expect(interpreted.query.text, isEmpty);
    });

    test('parses yesterday as a custom one-day range and diaper keyword', () {
      final interpreted = parser.parse('어제 기저귀', now: now);

      expect(interpreted.datePreset, SearchDatePreset.custom);
      expect(interpreted.query.eventKind, SearchEventKind.diaper);
      expect(interpreted.query.from, DateTime(2026, 7, 22));
      expect(interpreted.query.untilExclusive, DateTime(2026, 7, 23));
    });

    test('leaves unrelated text as the free-text query', () {
      final interpreted = parser.parse('아침에 잘 먹지 않았던 때', now: now);

      expect(interpreted.query.text, '아침에 잘 먹지 않았던 때');
      expect(interpreted.query.hasCriteria, isTrue);
    });
  });
}
