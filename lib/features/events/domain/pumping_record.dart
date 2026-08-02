import 'dart:convert';

import '../../../l10n/app_localizations.dart';

enum PumpingSide { left, right, both, unknown }

class PumpingRecord {
  const PumpingRecord({
    this.recordId,
    this.childId,
    required this.occurredAt,
    this.amountMl,
    this.side = PumpingSide.unknown,
    this.note,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.createdAt,
    this.lastModified,
  });

  static const schema = 'mlmd.pumping';
  static const version = 1;

  final String? recordId;
  final String? childId;
  final DateTime occurredAt;
  final int? amountMl;
  final PumpingSide side;
  final String? note;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final DateTime? createdAt;
  final DateTime? lastModified;

  PumpingRecord copyWith({
    String? recordId,
    String? childId,
    DateTime? occurredAt,
    int? amountMl,
    bool clearAmountMl = false,
    PumpingSide? side,
    String? note,
    bool clearNote = false,
    String? createdByAuthorProfileId,
    String? createdByDeviceProfileId,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return PumpingRecord(
      recordId: recordId ?? this.recordId,
      childId: childId ?? this.childId,
      occurredAt: occurredAt ?? this.occurredAt,
      amountMl: clearAmountMl ? null : amountMl ?? this.amountMl,
      side: side ?? this.side,
      note: clearNote ? null : note ?? this.note,
      createdByAuthorProfileId:
          createdByAuthorProfileId ?? this.createdByAuthorProfileId,
      createdByDeviceProfileId:
          createdByDeviceProfileId ?? this.createdByDeviceProfileId,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, Object?> toJson() => {
    'schema': schema,
    'version': version,
    if (recordId != null) 'recordId': recordId,
    if (childId != null) 'childId': childId,
    'occurredAt': occurredAt.toIso8601String(),
    if (amountMl != null && amountMl! > 0) 'amountMl': amountMl,
    if (side != PumpingSide.unknown) 'side': side.name,
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
    if (createdByAuthorProfileId != null)
      'createdByAuthorProfileId': createdByAuthorProfileId,
    if (createdByDeviceProfileId != null)
      'createdByDeviceProfileId': createdByDeviceProfileId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  static PumpingRecord? decode(String value) {
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

      final amountMlVal = decoded['amountMl'];
      final amountMl = amountMlVal is int && amountMlVal > 0
          ? amountMlVal
          : null;

      final sideStr = decoded['side'] as String?;
      final side = PumpingSide.values.firstWhere(
        (e) => e.name == sideStr,
        orElse: () => PumpingSide.unknown,
      );

      final createdAtStr = decoded['createdAt'] as String?;
      final lastModifiedStr = decoded['lastModified'] as String?;

      return PumpingRecord(
        recordId: decoded['recordId'] as String?,
        childId: decoded['childId'] as String?,
        occurredAt: occurredAt,
        amountMl: amountMl,
        side: side,
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

  String buildDetails(AppLocalizations loc) {
    final parts = <String>[];
    if (amountMl != null && amountMl! > 0) {
      parts.add('${amountMl}mL');
    }
    final sideLabel = _sideLabel(side, loc);
    if (sideLabel != null) {
      parts.add(sideLabel);
    }
    return parts.join(' · ');
  }

  static String? _sideLabel(PumpingSide side, AppLocalizations loc) =>
      switch (side) {
        PumpingSide.left => loc.leftSideOption,
        PumpingSide.right => loc.rightSideOption,
        PumpingSide.both => loc.bothSidesOption,
        PumpingSide.unknown => null,
      };
}
