/// 데이터베이스와 전송 버전 DTO 사이에서 사용하는 불변 공통 모델입니다.
class CanonicalTransferDocument {
  final DateTime exportedAt;
  final String appVersion;
  final List<CanonicalDiary> diaries;

  const CanonicalTransferDocument({
    required this.exportedAt,
    required this.appVersion,
    required this.diaries,
  });
}

typedef CanonicalImportDocument = CanonicalTransferDocument;
typedef CanonicalExportDocument = CanonicalTransferDocument;

class CanonicalDiary {
  final String recordId;
  final DateTime date;
  final String title;
  final String summary;
  final String content;
  final DateTime lastModified;
  final List<CanonicalActivity> activities;

  const CanonicalDiary({
    required this.recordId,
    required this.date,
    required this.title,
    required this.summary,
    required this.content,
    required this.lastModified,
    required this.activities,
  });
}

class CanonicalActivity {
  final String type;
  final DateTime time;
  final int timePrecision;
  final String details;
  final DateTime lastModified;

  const CanonicalActivity({
    required this.type,
    required this.time,
    this.timePrecision = 1,
    required this.details,
    required this.lastModified,
  });
}

enum ImportConflictPolicy { skipExisting, overwriteIfNewer }

class ImportPreview {
  final int total;
  final int newCount;
  final int duplicateCount;
  final int newerCount;
  final int skippedCount;
  final int activityCount;
  final int identicalCount;
  final int conflictCount;

  const ImportPreview({
    required this.total,
    required this.newCount,
    required this.duplicateCount,
    required this.newerCount,
    required this.skippedCount,
    required this.activityCount,
    this.identicalCount = 0,
    this.conflictCount = 0,
  });

  int get appliedCount => newCount + newerCount;
}

class ImportResult {
  final int inserted;
  final int updated;
  final int skipped;
  final int embeddingPending;
  final List<String> affectedRecordIds;

  const ImportResult({
    required this.inserted,
    required this.updated,
    required this.skipped,
    required this.embeddingPending,
    this.affectedRecordIds = const [],
  });
}
