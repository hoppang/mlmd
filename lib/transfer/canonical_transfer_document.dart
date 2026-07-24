/// 데이터베이스와 전송 버전 DTO 사이에서 사용하는 불변 공통 모델입니다.
class CanonicalTransferDocument {
  final DateTime exportedAt;
  final String appVersion;
  final List<CanonicalAuthorProfile> authorProfiles;
  final List<CanonicalDeviceProfile> deviceProfiles;
  final List<CanonicalDiary> diaries;

  const CanonicalTransferDocument({
    required this.exportedAt,
    required this.appVersion,
    this.authorProfiles = const [],
    this.deviceProfiles = const [],
    required this.diaries,
  });
}

typedef CanonicalImportDocument = CanonicalTransferDocument;
typedef CanonicalExportDocument = CanonicalTransferDocument;

class CanonicalAuthorProfile {
  final String authorProfileId;
  final String nickname;
  final int colorValue;
  final DateTime createdAt;

  const CanonicalAuthorProfile({
    required this.authorProfileId,
    required this.nickname,
    required this.colorValue,
    required this.createdAt,
  });
}

class CanonicalDeviceProfile {
  final String deviceProfileId;
  final DateTime createdAt;

  const CanonicalDeviceProfile({
    required this.deviceProfileId,
    required this.createdAt,
  });
}

class CanonicalDiary {
  final String recordId;
  final DateTime date;
  final String title;
  final String summary;
  final String content;
  final DateTime? createdAt;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final String? lastModifiedByAuthorProfileId;
  final String? lastModifiedByDeviceProfileId;
  final DateTime lastModified;
  final List<CanonicalActivity> activities;

  const CanonicalDiary({
    required this.recordId,
    required this.date,
    required this.title,
    required this.summary,
    required this.content,
    this.createdAt,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.lastModifiedByAuthorProfileId,
    this.lastModifiedByDeviceProfileId,
    required this.lastModified,
    required this.activities,
  });
}

class CanonicalActivity {
  final String type;
  final DateTime time;
  final int timePrecision;
  final String details;
  final String? structuredDataJson;
  final DateTime? createdAt;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final String? lastModifiedByAuthorProfileId;
  final String? lastModifiedByDeviceProfileId;
  final DateTime lastModified;

  const CanonicalActivity({
    required this.type,
    required this.time,
    this.timePrecision = 1,
    required this.details,
    this.structuredDataJson,
    this.createdAt,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.lastModifiedByAuthorProfileId,
    this.lastModifiedByDeviceProfileId,
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
