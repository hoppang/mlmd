import 'dart:convert';

import 'family_sync_models.dart';

enum FamilySyncConflictImportance { routine, caution, critical }

class MedicationConflictVersion {
  const MedicationConflictVersion({
    required this.medicationName,
    required this.amount,
    required this.unit,
    required this.administeredAt,
    required this.authorProfileId,
    required this.deviceProfileId,
    required this.modifiedAt,
  });

  final String? medicationName;
  final num? amount;
  final String? unit;
  final DateTime? administeredAt;
  final String? authorProfileId;
  final String? deviceProfileId;
  final DateTime? modifiedAt;

  String? get dose {
    if (amount == null) return null;
    final amountText = amount is int
        ? amount.toString()
        : (amount as num).toDouble().toString();
    return unit == null || unit!.trim().isEmpty
        ? amountText
        : '$amountText ${unit!.trim()}';
  }
}

abstract final class FamilySyncConflictPolicy {
  static const _medicationSchema = 'mlmd.medication';
  static const _temperatureSchema = 'mlmd.temperature';
  static const _medicationTypes = {'투약', 'medication', '投薬'};
  static const _cautionTypes = {
    '체온',
    'temperature',
    '体温',
    '수유',
    'feeding',
    '授乳',
    '식사',
    'meal',
    '食事',
    '물',
    'water',
    '水',
  };

  static FamilySyncConflictImportance importanceOf(
    FamilySyncConflict conflict,
  ) => importanceOfVersions(
    entityType: conflict.entityType,
    firstPayload: conflict.localPayload,
    secondPayload: conflict.incomingPayload,
  );

  static FamilySyncConflictImportance importanceOfVersions({
    required String entityType,
    required Map<String, Object?> firstPayload,
    required Map<String, Object?> secondPayload,
  }) {
    if (_isMedication(firstPayload) || _isMedication(secondPayload)) {
      return FamilySyncConflictImportance.critical;
    }
    if (entityType == 'careTaskOccurrence' ||
        _isCautionActivity(firstPayload) ||
        _isCautionActivity(secondPayload)) {
      return FamilySyncConflictImportance.caution;
    }
    return FamilySyncConflictImportance.routine;
  }

  static MedicationConflictVersion medicationVersion(
    Map<String, Object?> payload, {
    String? fallbackAuthorProfileId,
    String? fallbackDeviceProfileId,
    DateTime? fallbackModifiedAt,
  }) {
    final structured = _structuredData(payload);
    return MedicationConflictVersion(
      medicationName: _nonEmptyString(structured?['medicationName']),
      amount: structured?['amount'] is num
          ? structured!['amount']! as num
          : null,
      unit: _nonEmptyString(structured?['unit']),
      administeredAt:
          _dateTime(structured?['administeredAt']) ??
          _dateTime(payload['time']),
      authorProfileId:
          _nonEmptyString(payload['lastModifiedByAuthorProfileId']) ??
          _nonEmptyString(payload['createdByAuthorProfileId']) ??
          fallbackAuthorProfileId,
      deviceProfileId:
          _nonEmptyString(payload['lastModifiedByDeviceProfileId']) ??
          _nonEmptyString(payload['createdByDeviceProfileId']) ??
          fallbackDeviceProfileId,
      modifiedAt: _dateTime(payload['lastModified']) ?? fallbackModifiedAt,
    );
  }

  static bool _isMedication(Map<String, Object?> payload) {
    if (_structuredData(payload)?['schema'] == _medicationSchema) return true;
    final type = _nonEmptyString(payload['type']);
    if (type == null) return false;
    return _medicationTypes.contains(type) ||
        _medicationTypes.contains(type.toLowerCase());
  }

  static bool _isCautionActivity(Map<String, Object?> payload) {
    if (_structuredData(payload)?['schema'] == _temperatureSchema) return true;
    final type = _nonEmptyString(payload['type']);
    if (type == null) return false;
    return _cautionTypes.contains(type) ||
        _cautionTypes.contains(type.toLowerCase());
  }

  static Map<String, Object?>? _structuredData(Map<String, Object?> payload) {
    final raw = payload['structuredDataJson'];
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? decoded.map(
              (key, value) => MapEntry(key.toString(), value as Object?),
            )
          : null;
    } on FormatException {
      return null;
    }
  }

  static String? _nonEmptyString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static DateTime? _dateTime(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
