import 'dart:convert';

import '../../../l10n/app_localizations.dart';

/// Structured payload for a growth measurement activity (UX-032).
///
/// Records up to three body measurements taken at a single point in time:
/// [heightCm], [weightKg], and [headCm].  All three are optional but at
/// least one must be present for the record to be meaningful.
///
/// Values are stored as [double] to one or two decimal places.  Negative
/// or zero values are treated as absent when round-tripping.
///
/// The record is stored in [ActivityEntity.structuredDataJson] under schema
/// `mlmd.growth` version 1 and round-trips through backup v2 as raw JSON.
class GrowthMeasurementRecord {
  const GrowthMeasurementRecord({
    this.recordId,
    this.childId,
    required this.occurredAt,
    this.heightCm,
    this.weightKg,
    this.headCm,
    this.note,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.createdAt,
    this.lastModified,
  });

  static const schema = 'mlmd.growth';
  static const version = 1;

  final String? recordId;
  final String? childId;
  final DateTime occurredAt;

  /// Height in centimetres (positive, one decimal place). Null when not recorded.
  final double? heightCm;

  /// Weight in kilograms (positive, two decimal places). Null when not recorded.
  final double? weightKg;

  /// Head circumference in centimetres (positive, one decimal place). Null when not recorded.
  final double? headCm;

  final String? note;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final DateTime? createdAt;
  final DateTime? lastModified;

  /// Returns true when at least one measurement value is present.
  bool get hasAnyMeasurement =>
      (heightCm != null && heightCm! > 0) ||
      (weightKg != null && weightKg! > 0) ||
      (headCm != null && headCm! > 0);

  GrowthMeasurementRecord copyWith({
    String? recordId,
    String? childId,
    DateTime? occurredAt,
    double? heightCm,
    bool clearHeightCm = false,
    double? weightKg,
    bool clearWeightKg = false,
    double? headCm,
    bool clearHeadCm = false,
    String? note,
    bool clearNote = false,
    String? createdByAuthorProfileId,
    String? createdByDeviceProfileId,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return GrowthMeasurementRecord(
      recordId: recordId ?? this.recordId,
      childId: childId ?? this.childId,
      occurredAt: occurredAt ?? this.occurredAt,
      heightCm: clearHeightCm ? null : heightCm ?? this.heightCm,
      weightKg: clearWeightKg ? null : weightKg ?? this.weightKg,
      headCm: clearHeadCm ? null : headCm ?? this.headCm,
      note: clearNote ? null : note ?? this.note,
      createdByAuthorProfileId:
          createdByAuthorProfileId ?? this.createdByAuthorProfileId,
      createdByDeviceProfileId:
          createdByDeviceProfileId ?? this.createdByDeviceProfileId,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  /// Produces a human-readable summary for timeline and search display.
  ///
  /// Each present measurement is formatted with its unit and joined with
  /// ' · '.  Returns an empty string when no measurements are recorded.
  String buildDetails(AppLocalizations loc) {
    final parts = <String>[];
    if (heightCm != null && heightCm! > 0) {
      parts.add(loc.growthMeasurementHeightDisplay(heightCm!));
    }
    if (weightKg != null && weightKg! > 0) {
      parts.add(loc.growthMeasurementWeightDisplay(weightKg!));
    }
    if (headCm != null && headCm! > 0) {
      parts.add(loc.growthMeasurementHeadDisplay(headCm!));
    }
    return parts.join(' · ');
  }

  Map<String, Object?> toJson() => {
    'schema': schema,
    'version': version,
    if (recordId != null) 'recordId': recordId,
    if (childId != null) 'childId': childId,
    'occurredAt': occurredAt.toIso8601String(),
    if (heightCm != null && heightCm! > 0) 'heightCm': heightCm,
    if (weightKg != null && weightKg! > 0) 'weightKg': weightKg,
    if (headCm != null && headCm! > 0) 'headCm': headCm,
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
    if (createdByAuthorProfileId != null)
      'createdByAuthorProfileId': createdByAuthorProfileId,
    if (createdByDeviceProfileId != null)
      'createdByDeviceProfileId': createdByDeviceProfileId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  static GrowthMeasurementRecord? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }

      final occurredAtStr = decoded['occurredAt'] as String?;
      if (occurredAtStr == null) return null;
      final occurredAt = DateTime.tryParse(occurredAtStr);
      if (occurredAt == null) return null;

      final heightCm = _parsePositiveDouble(decoded['heightCm']);
      final weightKg = _parsePositiveDouble(decoded['weightKg']);
      final headCm = _parsePositiveDouble(decoded['headCm']);

      final createdAtStr = decoded['createdAt'] as String?;
      final lastModifiedStr = decoded['lastModified'] as String?;

      return GrowthMeasurementRecord(
        recordId: decoded['recordId'] as String?,
        childId: decoded['childId'] as String?,
        occurredAt: occurredAt,
        heightCm: heightCm,
        weightKg: weightKg,
        headCm: headCm,
        note: decoded['note'] as String?,
        createdByAuthorProfileId:
            decoded['createdByAuthorProfileId'] as String?,
        createdByDeviceProfileId:
            decoded['createdByDeviceProfileId'] as String?,
        createdAt:
            createdAtStr != null ? DateTime.tryParse(createdAtStr) : null,
        lastModified:
            lastModifiedStr != null ? DateTime.tryParse(lastModifiedStr) : null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GrowthMeasurementRecord &&
        other.recordId == recordId &&
        other.childId == childId &&
        other.occurredAt == occurredAt &&
        other.heightCm == heightCm &&
        other.weightKg == weightKg &&
        other.headCm == headCm &&
        other.note == note &&
        other.createdByAuthorProfileId == createdByAuthorProfileId &&
        other.createdByDeviceProfileId == createdByDeviceProfileId &&
        other.createdAt == createdAt &&
        other.lastModified == lastModified;
  }

  @override
  int get hashCode => Object.hash(
    recordId,
    childId,
    occurredAt,
    heightCm,
    weightKg,
    headCm,
    note,
    createdByAuthorProfileId,
    createdByDeviceProfileId,
    createdAt,
    lastModified,
  );

  /// Parses [raw] to a positive [double]; returns null when absent or ≤ 0.
  static double? _parsePositiveDouble(dynamic raw) {
    if (raw == null) return null;
    final d = raw is double ? raw : (raw is int ? raw.toDouble() : null);
    return (d != null && d > 0) ? d : null;
  }
}
