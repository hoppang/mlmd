import 'dart:convert';

class DiaryDraftActivity {
  const DiaryDraftActivity({
    required this.type,
    required this.detail,
    this.occurredAt,
  });

  final String type;
  final String detail;
  final DateTime? occurredAt;

  Map<String, Object?> toJson() => {
    'type': type,
    'detail': detail,
    if (occurredAt != null) 'occurredAt': occurredAt!.toIso8601String(),
  };

  factory DiaryDraftActivity.fromJson(Map<String, Object?> json) {
    return DiaryDraftActivity(
      type: json['type'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      occurredAt: _parseDateTime(json['occurredAt']),
    );
  }

  DiaryDraftActivity withFallbackTime(DateTime? fallback) => DiaryDraftActivity(
    type: type,
    detail: detail,
    occurredAt: occurredAt ?? fallback,
  );
}

class DiaryDraftPayload {
  const DiaryDraftPayload({
    required this.inputMode,
    required this.title,
    required this.rawText,
    required this.summary,
    required this.activities,
    this.occurredAt,
  });

  static const schemaVersion = 2;

  static bool supportsSchemaVersion(int version) =>
      version == 1 || version == 2;

  final String inputMode;
  final String title;
  final String rawText;
  final String summary;
  final List<DiaryDraftActivity> activities;
  final DateTime? occurredAt;

  bool get hasContent {
    if (title.trim().isNotEmpty ||
        rawText.trim().isNotEmpty ||
        summary.trim().isNotEmpty) {
      return true;
    }
    return activities.any(
      (activity) =>
          activity.type.trim().isNotEmpty || activity.detail.trim().isNotEmpty,
    );
  }

  bool hasSameRecordContent(DiaryDraftPayload other) {
    if (title != other.title ||
        rawText != other.rawText ||
        summary != other.summary ||
        !_sameInstant(occurredAt, other.occurredAt) ||
        activities.length != other.activities.length) {
      return false;
    }
    for (var index = 0; index < activities.length; index++) {
      final left = activities[index];
      final right = other.activities[index];
      if (left.type != right.type ||
          left.detail != right.detail ||
          !_sameInstant(left.occurredAt, right.occurredAt)) {
        return false;
      }
    }
    return true;
  }

  String encode() => jsonEncode({
    'inputMode': inputMode,
    'title': title,
    'rawText': rawText,
    'summary': summary,
    if (occurredAt != null) 'occurredAt': occurredAt!.toIso8601String(),
    'activities': activities.map((activity) => activity.toJson()).toList(),
  });

  /// v1 초안에는 시각 필드가 없으므로 원본 기록의 시각을 인덱스별로 보완한다.
  /// 새 기록의 AI 집계 이벤트는 fallback이 없어 정확한 시각 미상으로 유지된다.
  DiaryDraftPayload withFallbackTimes(DiaryDraftPayload fallback) {
    final mergedActivities = <DiaryDraftActivity>[];
    for (var index = 0; index < activities.length; index++) {
      final fallbackTime = index < fallback.activities.length
          ? fallback.activities[index].occurredAt
          : null;
      mergedActivities.add(activities[index].withFallbackTime(fallbackTime));
    }
    return DiaryDraftPayload(
      inputMode: inputMode,
      title: title,
      rawText: rawText,
      summary: summary,
      occurredAt: occurredAt ?? fallback.occurredAt,
      activities: List.unmodifiable(mergedActivities),
    );
  }

  DiaryDraftPayload withFallbackRecordTime(DateTime? fallback) =>
      DiaryDraftPayload(
        inputMode: inputMode,
        title: title,
        rawText: rawText,
        summary: summary,
        occurredAt: occurredAt ?? fallback,
        activities: activities,
      );

  DiaryDraftPayload withRecordTime(DateTime value) => DiaryDraftPayload(
    inputMode: inputMode,
    title: title,
    rawText: rawText,
    summary: summary,
    occurredAt: value,
    activities: activities,
  );

  factory DiaryDraftPayload.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Draft payload must be a JSON object.');
    }
    final rawActivities = decoded['activities'];
    return DiaryDraftPayload(
      inputMode: decoded['inputMode'] as String? ?? 'simple',
      title: decoded['title'] as String? ?? '',
      rawText: decoded['rawText'] as String? ?? '',
      summary: decoded['summary'] as String? ?? '',
      occurredAt: _parseDateTime(decoded['occurredAt']),
      activities: rawActivities is List
          ? rawActivities
                .whereType<Map>()
                .map(
                  (item) => DiaryDraftActivity.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}

bool _sameInstant(DateTime? left, DateTime? right) {
  if (left == null || right == null) return left == right;
  return left.isAtSameMomentAs(right);
}
