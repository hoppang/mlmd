import 'dart:convert';

import '../../../l10n/app_localizations.dart';

enum CareProcedureType {
  nasalCare,
  woundCare,
  hotColdPack,
  respiratoryCare,
  other,
}

extension CareProcedureTypeX on CareProcedureType {
  String label(AppLocalizations loc) => switch (this) {
    CareProcedureType.nasalCare => loc.procedureTypeNasalCare,
    CareProcedureType.woundCare => loc.procedureTypeWoundCare,
    CareProcedureType.hotColdPack => loc.procedureTypeHotColdPack,
    CareProcedureType.respiratoryCare => loc.procedureTypeRespiratoryCare,
    CareProcedureType.other => loc.procedureTypeOther,
  };
}

class CareProcedureRecord {
  const CareProcedureRecord({
    this.recordId,
    this.childId,
    required this.occurredAt,
    required this.procedureType,
    this.bodyArea,
    this.note,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.createdAt,
    this.lastModified,
  });

  static const schema = 'mlmd.care_procedure';
  static const version = 1;

  final String? recordId;
  final String? childId;
  final DateTime occurredAt;
  final CareProcedureType procedureType;
  final String? bodyArea;
  final String? note;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final DateTime? createdAt;
  final DateTime? lastModified;

  bool get isValid =>
      procedureType != CareProcedureType.other ||
      (note != null && note!.trim().isNotEmpty);

  String buildDetails(AppLocalizations loc) {
    final parts = <String>[procedureType.label(loc)];
    parts.addAll(_supportingDetailParts);
    return parts.join(' · ');
  }

  String buildSupportingDetails() {
    return _supportingDetailParts.join(' · ');
  }

  List<String> get _supportingDetailParts {
    final parts = <String>[];
    final trimmedArea = bodyArea?.trim();
    final trimmedNote = note?.trim();
    if (trimmedArea != null && trimmedArea.isNotEmpty) {
      parts.add(trimmedArea);
    }
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      parts.add(trimmedNote);
    }
    return parts;
  }

  String encode() => jsonEncode({
    'schema': schema,
    'version': version,
    if (recordId != null) 'recordId': recordId,
    if (childId != null) 'childId': childId,
    'occurredAt': occurredAt.toIso8601String(),
    'procedureType': procedureType.name,
    if (bodyArea?.trim().isNotEmpty == true) 'bodyArea': bodyArea!.trim(),
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
    if (createdByAuthorProfileId != null)
      'createdByAuthorProfileId': createdByAuthorProfileId,
    if (createdByDeviceProfileId != null)
      'createdByDeviceProfileId': createdByDeviceProfileId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
  });

  static CareProcedureRecord? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }

      final occurredAt = DateTime.tryParse(
        decoded['occurredAt'] as String? ?? '',
      );
      final procedureTypeName = decoded['procedureType'] as String?;
      final procedureType = CareProcedureType.values
          .where((type) => type.name == procedureTypeName)
          .firstOrNull;
      if (occurredAt == null || procedureType == null) return null;

      final record = CareProcedureRecord(
        recordId: decoded['recordId'] as String?,
        childId: decoded['childId'] as String?,
        occurredAt: occurredAt,
        procedureType: procedureType,
        bodyArea: decoded['bodyArea'] as String?,
        note: decoded['note'] as String?,
        createdByAuthorProfileId:
            decoded['createdByAuthorProfileId'] as String?,
        createdByDeviceProfileId:
            decoded['createdByDeviceProfileId'] as String?,
        createdAt: DateTime.tryParse(decoded['createdAt'] as String? ?? ''),
        lastModified: DateTime.tryParse(
          decoded['lastModified'] as String? ?? '',
        ),
      );
      return record.isValid ? record : null;
    } catch (_) {
      return null;
    }
  }
}
