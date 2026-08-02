import 'dart:convert';

class VaccinationRecord {
  const VaccinationRecord({
    this.recordId,
    this.childId,
    required this.vaccinatedAt,
    this.note,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.createdAt,
    this.lastModified,
  });

  static const schema = 'mlmd.vaccination';
  static const version = 1;

  final String? recordId;
  final String? childId;
  final DateTime vaccinatedAt;
  final String? note;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final DateTime? createdAt;
  final DateTime? lastModified;

  VaccinationRecord copyWith({
    String? recordId,
    String? childId,
    DateTime? vaccinatedAt,
    String? note,
    String? createdByAuthorProfileId,
    String? createdByDeviceProfileId,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return VaccinationRecord(
      recordId: recordId ?? this.recordId,
      childId: childId ?? this.childId,
      vaccinatedAt: vaccinatedAt ?? this.vaccinatedAt,
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
    'vaccinatedAt': vaccinatedAt.toIso8601String(),
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
    if (createdByAuthorProfileId != null)
      'createdByAuthorProfileId': createdByAuthorProfileId,
    if (createdByDeviceProfileId != null)
      'createdByDeviceProfileId': createdByDeviceProfileId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
  });

  static VaccinationRecord? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }

      final vaccinatedAtStr = decoded['vaccinatedAt'] as String?;
      if (vaccinatedAtStr == null) return null;
      final vaccinatedAt = DateTime.tryParse(vaccinatedAtStr);
      if (vaccinatedAt == null) return null;

      final createdAtStr = decoded['createdAt'] as String?;
      final lastModifiedStr = decoded['lastModified'] as String?;

      return VaccinationRecord(
        recordId: decoded['recordId'] as String?,
        childId: decoded['childId'] as String?,
        vaccinatedAt: vaccinatedAt,
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
