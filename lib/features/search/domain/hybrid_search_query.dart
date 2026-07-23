enum SearchEventKind {
  temperature,
  medication,
  feeding,
  diaper,
  sleep,
  hospital,
}

enum SearchDatePreset { all, today, last7Days, last30Days, custom }

enum NumericComparison { atLeast, above, atMost, below }

class TemperatureFilter {
  final double value;
  final NumericComparison comparison;

  const TemperatureFilter({required this.value, required this.comparison});
}

class HybridSearchQuery {
  static const Object _sentinel = Object();

  final String text;
  final DateTime? from;
  final DateTime? untilExclusive;
  final SearchEventKind? eventKind;
  final String? authorProfileId;
  final TemperatureFilter? temperature;

  const HybridSearchQuery({
    this.text = '',
    this.from,
    this.untilExclusive,
    this.eventKind,
    this.authorProfileId,
    this.temperature,
  });

  bool get hasCriteria =>
      text.trim().isNotEmpty ||
      from != null ||
      untilExclusive != null ||
      eventKind != null ||
      authorProfileId != null ||
      temperature != null;

  HybridSearchQuery copyWith({
    Object? text = _sentinel,
    Object? from = _sentinel,
    Object? untilExclusive = _sentinel,
    Object? eventKind = _sentinel,
    Object? authorProfileId = _sentinel,
    Object? temperature = _sentinel,
  }) {
    return HybridSearchQuery(
      text: identical(text, _sentinel) ? this.text : text as String,
      from: identical(from, _sentinel) ? this.from : from as DateTime?,
      untilExclusive: identical(untilExclusive, _sentinel)
          ? this.untilExclusive
          : untilExclusive as DateTime?,
      eventKind: identical(eventKind, _sentinel)
          ? this.eventKind
          : eventKind as SearchEventKind?,
      authorProfileId: identical(authorProfileId, _sentinel)
          ? this.authorProfileId
          : authorProfileId as String?,
      temperature: identical(temperature, _sentinel)
          ? this.temperature
          : temperature as TemperatureFilter?,
    );
  }

  HybridSearchQuery clear() => const HybridSearchQuery();
}

class InterpretedSearchQuery {
  final String originalText;
  final HybridSearchQuery query;
  final SearchDatePreset datePreset;
  final String? matchedAuthorNickname;

  const InterpretedSearchQuery({
    required this.originalText,
    required this.query,
    required this.datePreset,
    this.matchedAuthorNickname,
  });
}

class HybridSearchQueryParser {
  static final List<_EventKeywordRule> _eventRules = [
    _EventKeywordRule(SearchEventKind.temperature, [
      '체온',
      '열',
      '발열',
      'fever',
      'temperature',
      'temperatura',
      'temperatur',
      'temperatura corporal',
      '体温',
      '熱',
    ]),
    _EventKeywordRule(SearchEventKind.medication, [
      '투약',
      '약',
      '복용',
      'medication',
      'medicine',
      'drug',
      '投薬',
      '服薬',
    ]),
    _EventKeywordRule(SearchEventKind.feeding, [
      '수유',
      '분유',
      '식사',
      'feeding',
      'feed',
      '授乳',
      'ミルク',
      '哺乳',
    ]),
    _EventKeywordRule(SearchEventKind.diaper, ['기저귀', 'diaper', '尿布', 'おむつ']),
    _EventKeywordRule(SearchEventKind.sleep, [
      '수면',
      '잠',
      '낮잠',
      'sleep',
      'nap',
      '睡眠',
      '昼寝',
    ]),
    _EventKeywordRule(SearchEventKind.hospital, [
      '병원',
      '진료',
      '외래',
      'hospital',
      'clinic',
      'doctor',
      '病院',
      '診療',
    ]),
  ];

  static final RegExp _koreanAtLeast = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:도|℃|°C)?\s*(?:이상|넘(?:음|었다|었|어)?|초과)',
  );
  static final RegExp _englishAtLeast = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:°\s?c|c)?\s*(?:or\s+above|or\s+over|above|over|at\s+least)',
    caseSensitive: false,
  );
  static final RegExp _japaneseAtLeast = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:度|℃|°C)?\s*(?:以上|超)',
  );

  static const _todayKeywords = ['오늘', 'today', '今日'];
  static const _yesterdayKeywords = ['어제', 'yesterday', '昨日'];
  static const _last7Keywords = [
    '최근7일',
    '최근 7일',
    'last7days',
    'last 7 days',
    '過去7日',
    '最近7日',
  ];
  static const _last30Keywords = [
    '30일',
    '최근30일',
    '최근 30일',
    'last30days',
    'last 30 days',
    '過去30日',
    '最近30日',
  ];

  const HybridSearchQueryParser();

  InterpretedSearchQuery parse(
    String text, {
    DateTime? now,
    List<String> authorNicknames = const [],
    Map<String, String>? authorProfileIdsByNickname,
  }) {
    final originalText = text;
    final trimmed = text.trim();
    final normalized = _normalize(trimmed);
    final referenceNow = now ?? DateTime.now();
    final dateBounds = _parseDateBounds(normalized, referenceNow);
    final eventKind = _parseEventKind(normalized);
    final temperature = _parseTemperature(normalized);
    final authorMatch = _parseAuthor(
      normalized,
      authorNicknames,
      authorProfileIdsByNickname,
    );
    final cleanedText = _cleanupText(
      trimmed,
      eventKind: eventKind,
      authorNickname: authorMatch?.nickname,
      datePreset: dateBounds.preset,
    );

    return InterpretedSearchQuery(
      originalText: originalText,
      datePreset: dateBounds.preset,
      matchedAuthorNickname: authorMatch?.nickname,
      query: HybridSearchQuery(
        text: cleanedText,
        from: dateBounds.from,
        untilExclusive: dateBounds.untilExclusive,
        eventKind: eventKind,
        authorProfileId: authorMatch?.authorProfileId,
        temperature: temperature,
      ),
    );
  }

  SearchEventKind? _parseEventKind(String normalized) {
    SearchEventKind? result;
    var bestIndex = -1;
    for (final rule in _eventRules) {
      for (final keyword in rule.keywords) {
        final index = normalized.lastIndexOf(_normalize(keyword));
        if (index > bestIndex) {
          bestIndex = index;
          result = rule.kind;
        }
      }
    }
    return result;
  }

  TemperatureFilter? _parseTemperature(String normalized) {
    final match =
        _japaneseAtLeast.firstMatch(normalized) ??
        _englishAtLeast.firstMatch(normalized) ??
        _koreanAtLeast.firstMatch(normalized);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    return TemperatureFilter(
      value: value,
      comparison: NumericComparison.atLeast,
    );
  }

  _DateBounds _parseDateBounds(String normalized, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    if (_containsAny(normalized, _todayKeywords)) {
      return _DateBounds(
        SearchDatePreset.today,
        startOfToday,
        startOfToday.add(const Duration(days: 1)),
      );
    }
    if (_containsAny(normalized, _yesterdayKeywords)) {
      final from = startOfToday.subtract(const Duration(days: 1));
      return _DateBounds(SearchDatePreset.custom, from, startOfToday);
    }
    if (_containsAny(normalized, _last7Keywords)) {
      final from = startOfToday.subtract(const Duration(days: 6));
      return _DateBounds(
        SearchDatePreset.last7Days,
        from,
        startOfToday.add(const Duration(days: 1)),
      );
    }
    if (_containsAny(normalized, _last30Keywords)) {
      final from = startOfToday.subtract(const Duration(days: 29));
      return _DateBounds(
        SearchDatePreset.last30Days,
        from,
        startOfToday.add(const Duration(days: 1)),
      );
    }
    return const _DateBounds(SearchDatePreset.all, null, null);
  }

  _AuthorMatch? _parseAuthor(
    String normalized,
    List<String> authorNicknames,
    Map<String, String>? authorProfileIdsByNickname,
  ) {
    for (final nickname in authorNicknames) {
      if (nickname.isEmpty) continue;
      if (normalized.contains(_normalize(nickname))) {
        return _AuthorMatch(
          nickname: nickname,
          authorProfileId: authorProfileIdsByNickname?[nickname],
        );
      }
    }
    return null;
  }

  String _cleanupText(
    String original, {
    required SearchEventKind? eventKind,
    required String? authorNickname,
    required SearchDatePreset datePreset,
  }) {
    var result = original;
    result = result
        .replaceAll(_japaneseAtLeast, ' ')
        .replaceAll(_englishAtLeast, ' ')
        .replaceAll(_koreanAtLeast, ' ');
    for (final token in [
      if (eventKind != null) ..._eventRules.expand((rule) => rule.keywords),
      ?authorNickname,
      ..._dateTokensForPreset(datePreset),
      if (datePreset == SearchDatePreset.custom) ..._yesterdayKeywords,
    ]) {
      result = result.replaceAll(
        RegExp(RegExp.escape(token), caseSensitive: false),
        ' ',
      );
    }
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  List<String> _dateTokensForPreset(SearchDatePreset preset) {
    return switch (preset) {
      SearchDatePreset.today => _todayKeywords,
      SearchDatePreset.last7Days => _last7Keywords,
      SearchDatePreset.last30Days => _last30Keywords,
      _ => const [],
    };
  }

  bool _containsAny(String normalized, List<String> keywords) {
    for (final keyword in keywords) {
      if (normalized.contains(_normalize(keyword))) return true;
    }
    return false;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _EventKeywordRule {
  final SearchEventKind kind;
  final List<String> keywords;

  const _EventKeywordRule(this.kind, this.keywords);
}

class _DateBounds {
  final SearchDatePreset preset;
  final DateTime? from;
  final DateTime? untilExclusive;

  const _DateBounds(this.preset, this.from, this.untilExclusive);
}

class _AuthorMatch {
  final String nickname;
  final String? authorProfileId;

  const _AuthorMatch({required this.nickname, this.authorProfileId});
}
