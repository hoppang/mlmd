import 'dart:convert';

class HospitalVisitRecord {
  const HospitalVisitRecord({
    this.recordId,
    this.childId,
    required this.visitedAt,
    this.note,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.createdAt,
    this.lastModified,
  });

  static const schema = 'mlmd.hospital_visit';
  static const version = 1;

  final String? recordId;
  final String? childId;
  final DateTime visitedAt;
  final String? note;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final DateTime? createdAt;
  final DateTime? lastModified;

  HospitalVisitRecord copyWith({
    String? recordId,
    String? childId,
    DateTime? visitedAt,
    String? note,
    String? createdByAuthorProfileId,
    String? createdByDeviceProfileId,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return HospitalVisitRecord(
      recordId: recordId ?? this.recordId,
      childId: childId ?? this.childId,
      visitedAt: visitedAt ?? this.visitedAt,
      note: note ?? this.note,
      createdByAuthorProfileId:
          createdByAuthorProfileId ?? this.createdByAuthorProfileId,
      createdByDeviceProfileId:
          createdByDeviceProfileId ?? this.createdByDeviceProfileId,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  String encode() => jsonEncode({
    'schema': schema,
    'version': version,
    if (recordId != null) 'recordId': recordId,
    if (childId != null) 'childId': childId,
    'visitedAt': visitedAt.toIso8601String(),
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
    if (createdByAuthorProfileId != null)
      'createdByAuthorProfileId': createdByAuthorProfileId,
    if (createdByDeviceProfileId != null)
      'createdByDeviceProfileId': createdByDeviceProfileId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
  });

  static HospitalVisitRecord? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }

      final visitedAtStr = decoded['visitedAt'] as String?;
      if (visitedAtStr == null) return null;
      final visitedAt = DateTime.tryParse(visitedAtStr);
      if (visitedAt == null) return null;

      final createdAtStr = decoded['createdAt'] as String?;
      final lastModifiedStr = decoded['lastModified'] as String?;

      return HospitalVisitRecord(
        recordId: decoded['recordId'] as String?,
        childId: decoded['childId'] as String?,
        visitedAt: visitedAt,
        note: decoded['note'] as String?,
        createdByAuthorProfileId:
            decoded['createdByAuthorProfileId'] as String?,
        createdByDeviceProfileId:
            decoded['createdByDeviceProfileId'] as String?,
        createdAt: createdAtStr != null
            ? DateTime.tryParse(createdAtStr)
            : null,
        lastModified: lastModifiedStr != null
            ? DateTime.tryParse(lastModifiedStr)
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}
