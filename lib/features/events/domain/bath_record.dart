import 'dart:convert';

import '../../../l10n/app_localizations.dart';

class BathRecord {
  const BathRecord({
    this.recordId,
    this.childId,
    required this.occurredAt,
    this.isQuickBath = true,
    this.note,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.createdAt,
    this.lastModified,
  });

  static const schema = 'mlmd.bath';
  static const version = 1;

  final String? recordId;
  final String? childId;
  final DateTime occurredAt;
  final bool isQuickBath;
  final String? note;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final DateTime? createdAt;
  final DateTime? lastModified;

  BathRecord copyWith({
    String? recordId,
    String? childId,
    DateTime? occurredAt,
    bool? isQuickBath,
    String? note,
    bool clearNote = false,
    String? createdByAuthorProfileId,
    String? createdByDeviceProfileId,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return BathRecord(
      recordId: recordId ?? this.recordId,
      childId: childId ?? this.childId,
      occurredAt: occurredAt ?? this.occurredAt,
      isQuickBath: isQuickBath ?? this.isQuickBath,
      note: clearNote ? null : note ?? this.note,
      createdByAuthorProfileId:
          createdByAuthorProfileId ?? this.createdByAuthorProfileId,
      createdByDeviceProfileId:
          createdByDeviceProfileId ?? this.createdByDeviceProfileId,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  String buildDetails(AppLocalizations loc) {
    return note?.trim() ?? '';
  }

  String encode() => jsonEncode({
        'schema': schema,
        'version': version,
        if (recordId != null) 'recordId': recordId,
        if (childId != null) 'childId': childId,
        'occurredAt': occurredAt.toIso8601String(),
        'isQuickBath': isQuickBath,
        if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
        if (createdByAuthorProfileId != null)
          'createdByAuthorProfileId': createdByAuthorProfileId,
        if (createdByDeviceProfileId != null)
          'createdByDeviceProfileId': createdByDeviceProfileId,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
      });

  static BathRecord? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }
      final occurredAtStr = decoded['occurredAt'] as String?;
      final occurredAt =
          occurredAtStr != null ? DateTime.tryParse(occurredAtStr) : null;
      if (occurredAt == null) return null;

      final isQuickBath = decoded['isQuickBath'] as bool? ?? true;
      final note = decoded['note'] as String?;
      final recordId = decoded['recordId'] as String?;
      final childId = decoded['childId'] as String?;
      final createdByAuthorProfileId =
          decoded['createdByAuthorProfileId'] as String?;
      final createdByDeviceProfileId =
          decoded['createdByDeviceProfileId'] as String?;
      final createdAtStr = decoded['createdAt'] as String?;
      final createdAt =
          createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      final lastModifiedStr = decoded['lastModified'] as String?;
      final lastModified =
          lastModifiedStr != null ? DateTime.tryParse(lastModifiedStr) : null;

      return BathRecord(
        recordId: recordId,
        childId: childId,
        occurredAt: occurredAt,
        isQuickBath: isQuickBath,
        note: note,
        createdByAuthorProfileId: createdByAuthorProfileId,
        createdByDeviceProfileId: createdByDeviceProfileId,
        createdAt: createdAt,
        lastModified: lastModified,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BathRecord &&
        other.recordId == recordId &&
        other.childId == childId &&
        other.occurredAt == occurredAt &&
        other.isQuickBath == isQuickBath &&
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
        isQuickBath,
        note,
        createdByAuthorProfileId,
        createdByDeviceProfileId,
        createdAt,
        lastModified,
      );
}
