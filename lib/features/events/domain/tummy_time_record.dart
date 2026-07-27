import 'dart:convert';

import '../../../l10n/app_localizations.dart';

/// Structured payload for a tummy time activity (UX-031).
///
/// [durationMinutes] is optional (1–999). When absent the record preserves
/// the occurrence time only.
/// [note] is a free-text observation, also optional.
///
/// The record is stored in [ActivityEntity.structuredDataJson] under schema
/// `mlmd.tummytime` version 1 and round-trips through backup v2 as raw JSON.
class TummyTimeRecord {
  const TummyTimeRecord({
    this.recordId,
    this.childId,
    required this.occurredAt,
    this.durationMinutes,
    this.note,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.createdAt,
    this.lastModified,
  });

  static const schema = 'mlmd.tummytime';
  static const version = 1;

  final String? recordId;
  final String? childId;
  final DateTime occurredAt;

  /// Elapsed time in whole minutes; 1–999. Null when not recorded.
  final int? durationMinutes;

  final String? note;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final DateTime? createdAt;
  final DateTime? lastModified;

  TummyTimeRecord copyWith({
    String? recordId,
    String? childId,
    DateTime? occurredAt,
    int? durationMinutes,
    bool clearDurationMinutes = false,
    String? note,
    bool clearNote = false,
    String? createdByAuthorProfileId,
    String? createdByDeviceProfileId,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return TummyTimeRecord(
      recordId: recordId ?? this.recordId,
      childId: childId ?? this.childId,
      occurredAt: occurredAt ?? this.occurredAt,
      durationMinutes: clearDurationMinutes
          ? null
          : durationMinutes ?? this.durationMinutes,
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
  String buildDetails(AppLocalizations loc) {
    if (durationMinutes != null && durationMinutes! > 0) {
      return loc.tummyTimeDurationDisplay(durationMinutes!);
    }
    return note?.trim() ?? '';
  }

  Map<String, Object?> toJson() => {
    'schema': schema,
    'version': version,
    if (recordId != null) 'recordId': recordId,
    if (childId != null) 'childId': childId,
    'occurredAt': occurredAt.toIso8601String(),
    if (durationMinutes != null && durationMinutes! > 0)
      'durationMinutes': durationMinutes,
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
    if (createdByAuthorProfileId != null)
      'createdByAuthorProfileId': createdByAuthorProfileId,
    if (createdByDeviceProfileId != null)
      'createdByDeviceProfileId': createdByDeviceProfileId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  static TummyTimeRecord? decode(String value) {
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

      final durationVal = decoded['durationMinutes'];
      final durationMinutes =
          durationVal is int && durationVal > 0 ? durationVal : null;

      final createdAtStr = decoded['createdAt'] as String?;
      final lastModifiedStr = decoded['lastModified'] as String?;

      return TummyTimeRecord(
        recordId: decoded['recordId'] as String?,
        childId: decoded['childId'] as String?,
        occurredAt: occurredAt,
        durationMinutes: durationMinutes,
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TummyTimeRecord &&
        other.recordId == recordId &&
        other.childId == childId &&
        other.occurredAt == occurredAt &&
        other.durationMinutes == durationMinutes &&
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
        durationMinutes,
        note,
        createdByAuthorProfileId,
        createdByDeviceProfileId,
        createdAt,
        lastModified,
      );
}
