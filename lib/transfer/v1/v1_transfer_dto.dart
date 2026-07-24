class V1TransferDocument {
  final String format;
  final int schemaVersion;
  final String exportedAt;
  final String appVersion;
  final List<V1DiaryItem> diaries;

  const V1TransferDocument({
    required this.format,
    required this.schemaVersion,
    required this.exportedAt,
    required this.appVersion,
    required this.diaries,
  });

  Map<String, Object?> toJson() => {
    'format': format,
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt,
    'appVersion': appVersion,
    'diaries': diaries.map((item) => item.toJson()).toList(growable: false),
  };
}

class V1DiaryItem {
  final String recordId;
  final String date;
  final String title;
  final String summary;
  final String content;
  final String lastModified;
  final List<V1ActivityItem> activities;

  const V1DiaryItem({
    required this.recordId,
    required this.date,
    required this.title,
    required this.summary,
    required this.content,
    required this.lastModified,
    required this.activities,
  });

  Map<String, Object?> toJson() => {
    'recordId': recordId,
    'date': date,
    'title': title,
    'summary': summary,
    'content': content,
    'lastModified': lastModified,
    'activities': activities
        .map((item) => item.toJson())
        .toList(growable: false),
  };
}

class V1ActivityItem {
  final String type;
  final String time;
  final int timePrecision;
  final String details;
  final String lastModified;

  const V1ActivityItem({
    required this.type,
    required this.time,
    required this.timePrecision,
    required this.details,
    required this.lastModified,
  });

  Map<String, Object?> toJson() => {
    'type': type,
    'time': time,
    'timePrecision': timePrecision,
    'details': details,
    'lastModified': lastModified,
  };
}
