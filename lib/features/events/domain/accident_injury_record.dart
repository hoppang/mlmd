import 'dart:convert';

import '../../../l10n/app_localizations.dart';

enum AccidentCategory {
  traumatic,
  nonTraumatic,
}

enum AccidentInjuryType {
  // Traumatic
  bumpBruise,
  scratchWound,
  fallTrip,
  burn,
  biteSting,
  otherTrauma,

  // Non-traumatic
  foreignIngestion,
  chokingAspiration,
  eyeEarForeignObject,
  poisoningChemical,
  heatColdInjury,
  otherNonTrauma,
}

extension AccidentCategoryX on AccidentCategory {
  String label(AppLocalizations loc) => switch (this) {
        AccidentCategory.traumatic => loc.accidentCategoryTraumatic,
        AccidentCategory.nonTraumatic => loc.accidentCategoryNonTraumatic,
      };
}

extension AccidentInjuryTypeX on AccidentInjuryType {
  AccidentCategory get category => switch (this) {
        AccidentInjuryType.bumpBruise ||
        AccidentInjuryType.scratchWound ||
        AccidentInjuryType.fallTrip ||
        AccidentInjuryType.burn ||
        AccidentInjuryType.biteSting ||
        AccidentInjuryType.otherTrauma =>
          AccidentCategory.traumatic,
        AccidentInjuryType.foreignIngestion ||
        AccidentInjuryType.chokingAspiration ||
        AccidentInjuryType.eyeEarForeignObject ||
        AccidentInjuryType.poisoningChemical ||
        AccidentInjuryType.heatColdInjury ||
        AccidentInjuryType.otherNonTrauma =>
          AccidentCategory.nonTraumatic,
      };

  bool get requiresAttention => switch (this) {
        AccidentInjuryType.fallTrip ||
        AccidentInjuryType.burn ||
        AccidentInjuryType.foreignIngestion ||
        AccidentInjuryType.chokingAspiration ||
        AccidentInjuryType.poisoningChemical =>
          true,
        _ => false,
      };

  String label(AppLocalizations loc) => switch (this) {
        AccidentInjuryType.bumpBruise => loc.injuryTypeBumpBruise,
        AccidentInjuryType.scratchWound => loc.injuryTypeScratchWound,
        AccidentInjuryType.fallTrip => loc.injuryTypeFallTrip,
        AccidentInjuryType.burn => loc.injuryTypeBurn,
        AccidentInjuryType.biteSting => loc.injuryTypeBiteSting,
        AccidentInjuryType.otherTrauma => loc.injuryTypeOtherTrauma,
        AccidentInjuryType.foreignIngestion => loc.injuryTypeForeignIngestion,
        AccidentInjuryType.chokingAspiration => loc.injuryTypeChokingAspiration,
        AccidentInjuryType.eyeEarForeignObject =>
          loc.injuryTypeEyeEarForeignObject,
        AccidentInjuryType.poisoningChemical => loc.injuryTypePoisoningChemical,
        AccidentInjuryType.heatColdInjury => loc.injuryTypeHeatColdInjury,
        AccidentInjuryType.otherNonTrauma => loc.injuryTypeOtherNonTrauma,
      };
}

class AccidentInjuryRecord {
  const AccidentInjuryRecord({
    this.recordId,
    this.childId,
    required this.occurredAt,
    required this.category,
    required this.injuryType,
    this.customType,
    this.note,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.createdAt,
    this.lastModified,
  });

  static const schema = 'mlmd.accident_injury';
  static const version = 1;

  final String? recordId;
  final String? childId;
  final DateTime occurredAt;
  final AccidentCategory category;
  final AccidentInjuryType injuryType;
  final String? customType;
  final String? note;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final DateTime? createdAt;
  final DateTime? lastModified;

  AccidentInjuryRecord copyWith({
    String? recordId,
    String? childId,
    DateTime? occurredAt,
    AccidentCategory? category,
    AccidentInjuryType? injuryType,
    String? customType,
    String? note,
    String? createdByAuthorProfileId,
    String? createdByDeviceProfileId,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return AccidentInjuryRecord(
      recordId: recordId ?? this.recordId,
      childId: childId ?? this.childId,
      occurredAt: occurredAt ?? this.occurredAt,
      category: category ?? this.category,
      injuryType: injuryType ?? this.injuryType,
      customType: customType ?? this.customType,
      note: note ?? this.note,
      createdByAuthorProfileId:
          createdByAuthorProfileId ?? this.createdByAuthorProfileId,
      createdByDeviceProfileId:
          createdByDeviceProfileId ?? this.createdByDeviceProfileId,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  String buildDetails(AppLocalizations loc) {
    final catLabel = category.label(loc);
    final typeLabel = customType?.trim().isNotEmpty == true
        ? customType!.trim()
        : injuryType.label(loc);
    final base = '$catLabel · $typeLabel';
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      return '$base · $trimmedNote';
    }
    return base;
  }

  String encode() => jsonEncode({
        'schema': schema,
        'version': version,
        if (recordId != null) 'recordId': recordId,
        if (childId != null) 'childId': childId,
        'occurredAt': occurredAt.toIso8601String(),
        'category': category.name,
        'injuryType': injuryType.name,
        if (customType?.trim().isNotEmpty == true) 'customType': customType!.trim(),
        if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
        if (createdByAuthorProfileId != null)
          'createdByAuthorProfileId': createdByAuthorProfileId,
        if (createdByDeviceProfileId != null)
          'createdByDeviceProfileId': createdByDeviceProfileId,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (lastModified != null)
          'lastModified': lastModified!.toIso8601String(),
      });

  static AccidentInjuryRecord? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }

      final occurredAtStr = decoded['occurredAt'] as String?;
      final categoryName = decoded['category'] as String?;
      final injuryTypeName = decoded['injuryType'] as String?;
      if (occurredAtStr == null || injuryTypeName == null) return null;

      final occurredAt = DateTime.tryParse(occurredAtStr);
      if (occurredAt == null) return null;

      final injuryType = AccidentInjuryType.values
          .where((e) => e.name == injuryTypeName)
          .firstOrNull;
      if (injuryType == null) return null;

      final category = categoryName != null
          ? AccidentCategory.values
                  .where((e) => e.name == categoryName)
                  .firstOrNull ??
              injuryType.category
          : injuryType.category;

      final createdAtStr = decoded['createdAt'] as String?;
      final lastModifiedStr = decoded['lastModified'] as String?;

      return AccidentInjuryRecord(
        recordId: decoded['recordId'] as String?,
        childId: decoded['childId'] as String?,
        occurredAt: occurredAt,
        category: category,
        injuryType: injuryType,
        customType: decoded['customType'] as String?,
        note: decoded['note'] as String?,
        createdByAuthorProfileId:
            decoded['createdByAuthorProfileId'] as String?,
        createdByDeviceProfileId:
            decoded['createdByDeviceProfileId'] as String?,
        createdAt:
            createdAtStr != null ? DateTime.tryParse(createdAtStr) : null,
        lastModified: lastModifiedStr != null
            ? DateTime.tryParse(lastModifiedStr)
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}
