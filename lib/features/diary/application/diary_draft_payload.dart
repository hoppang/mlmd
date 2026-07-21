import 'dart:convert';

class DiaryDraftActivity {
  const DiaryDraftActivity({required this.type, required this.detail});

  final String type;
  final String detail;

  Map<String, Object?> toJson() => {'type': type, 'detail': detail};

  factory DiaryDraftActivity.fromJson(Map<String, Object?> json) {
    return DiaryDraftActivity(
      type: json['type'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }
}

class DiaryDraftPayload {
  const DiaryDraftPayload({
    required this.inputMode,
    required this.title,
    required this.rawText,
    required this.summary,
    required this.activities,
  });

  static const schemaVersion = 1;

  final String inputMode;
  final String title;
  final String rawText;
  final String summary;
  final List<DiaryDraftActivity> activities;

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
        activities.length != other.activities.length) {
      return false;
    }
    for (var index = 0; index < activities.length; index++) {
      final left = activities[index];
      final right = other.activities[index];
      if (left.type != right.type || left.detail != right.detail) return false;
    }
    return true;
  }

  String encode() => jsonEncode({
    'inputMode': inputMode,
    'title': title,
    'rawText': rawText,
    'summary': summary,
    'activities': activities.map((activity) => activity.toJson()).toList(),
  });

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
