import 'dart:convert';

import '../../../l10n/app_localizations.dart';

enum SymptomKind { episodic, continuous }

enum SymptomEpisodeStatus { active, resolved }

enum SymptomOnsetPrecision { exactTime, dateOnly }

enum SymptomAmount { mild, moderate, severe }

enum SymptomContext { afterFeeding, afterMeal, afterCough, unknown }

enum SymptomSeverity { mild, moderate, severe }

enum SymptomTrend { improved, same, worsened }

class SymptomRecord {
  const SymptomRecord({
    required this.symptomId,
    required this.symptomName,
    required this.kind,
    required this.occurredAt,
    this.episodeId,
    this.status,
    this.onsetPrecision,
    this.resolvedAt,
    this.severity,
    this.trend,
    this.amount,
    this.context,
    this.note,
  });

  static const schema = 'mlmd.symptom';
  static const version = 1;

  final String symptomId;
  final String symptomName;
  final SymptomKind kind;
  final DateTime occurredAt;
  final String? episodeId;
  final SymptomEpisodeStatus? status;
  final SymptomOnsetPrecision? onsetPrecision;
  final DateTime? resolvedAt;
  final SymptomSeverity? severity;
  final SymptomTrend? trend;
  final SymptomAmount? amount;
  final SymptomContext? context;
  final String? note;

  String encode() => jsonEncode({
    'schema': schema,
    'version': version,
    'symptomId': symptomId,
    'symptomName': symptomName,
    'kind': kind.name,
    'occurredAt': occurredAt.toIso8601String(),
    if (episodeId != null) 'episodeId': episodeId,
    if (status != null) 'status': status!.name,
    if (onsetPrecision != null) 'onsetPrecision': onsetPrecision!.name,
    if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
    if (severity != null) 'severity': severity!.name,
    if (trend != null) 'trend': trend!.name,
    if (amount != null) 'amount': amount!.name,
    if (context != null) 'context': context!.name,
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
  });

  static SymptomRecord? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }
      final symptomId = decoded['symptomId'];
      final symptomName = decoded['symptomName'];
      final kindName = decoded['kind'];
      final occurredAtStr = decoded['occurredAt'];
      if (symptomId is! String ||
          symptomName is! String ||
          kindName is! String ||
          occurredAtStr is! String) {
        return null;
      }
      final kind = SymptomKind.values
          .where((e) => e.name == kindName)
          .firstOrNull;
      final occurredAt = DateTime.tryParse(occurredAtStr);
      if (kind == null || occurredAt == null) return null;

      final episodeId = decoded['episodeId'] as String?;
      final statusName = decoded['status'] as String?;
      final status = statusName == null
          ? null
          : SymptomEpisodeStatus.values
              .where((e) => e.name == statusName)
              .firstOrNull;
      if (statusName != null && status == null) return null;

      final onsetPrecisionName = decoded['onsetPrecision'] as String?;
      final onsetPrecision = onsetPrecisionName == null
          ? null
          : SymptomOnsetPrecision.values
              .where((e) => e.name == onsetPrecisionName)
              .firstOrNull;
      if (onsetPrecisionName != null && onsetPrecision == null) return null;

      final resolvedAtStr = decoded['resolvedAt'] as String?;
      final resolvedAt =
          resolvedAtStr == null ? null : DateTime.tryParse(resolvedAtStr);

      final severityName = decoded['severity'] as String?;
      final severity = severityName == null
          ? null
          : SymptomSeverity.values
              .where((e) => e.name == severityName)
              .firstOrNull;
      if (severityName != null && severity == null) return null;

      final trendName = decoded['trend'] as String?;
      final trend = trendName == null
          ? null
          : SymptomTrend.values.where((e) => e.name == trendName).firstOrNull;
      if (trendName != null && trend == null) return null;

      final amountName = decoded['amount'] as String?;
      final amount = amountName == null
          ? null
          : SymptomAmount.values
              .where((e) => e.name == amountName)
              .firstOrNull;
      if (amountName != null && amount == null) return null;

      final contextName = decoded['context'] as String?;
      final context = contextName == null
          ? null
          : SymptomContext.values
              .where((e) => e.name == contextName)
              .firstOrNull;
      if (contextName != null && context == null) return null;

      final note = decoded['note'] as String?;

      return SymptomRecord(
        symptomId: symptomId,
        symptomName: symptomName,
        kind: kind,
        occurredAt: occurredAt,
        episodeId: episodeId,
        status: status,
        onsetPrecision: onsetPrecision,
        resolvedAt: resolvedAt,
        severity: severity,
        trend: trend,
        amount: amount,
        context: context,
        note: note,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

String symptomAmountLabel(AppLocalizations loc, SymptomAmount amount) =>
    switch (amount) {
      SymptomAmount.mild => '조금',
      SymptomAmount.moderate => '보통',
      SymptomAmount.severe => '많이',
    };

String symptomContextLabel(AppLocalizations loc, SymptomContext context) =>
    switch (context) {
      SymptomContext.afterFeeding => '수유 후',
      SymptomContext.afterMeal => '식사 후',
      SymptomContext.afterCough => '기침 후',
      SymptomContext.unknown => '모름',
    };

String symptomSeverityLabel(
  AppLocalizations loc,
  SymptomSeverity severity,
) => switch (severity) {
  SymptomSeverity.mild => '약함',
  SymptomSeverity.moderate => '보통',
  SymptomSeverity.severe => '심함',
};

String symptomTrendLabel(AppLocalizations loc, SymptomTrend trend) =>
    switch (trend) {
      SymptomTrend.improved => '나아졌어요',
      SymptomTrend.same => '비슷해요',
      SymptomTrend.worsened => '심해졌어요',
    };

String symptomRecordDetails(AppLocalizations loc, SymptomRecord record) {
  final parts = <String>[];
  if (record.kind == SymptomKind.episodic) {
    if (record.amount case final amount?) {
      parts.add(symptomAmountLabel(loc, amount));
    }
    if (record.context case final ctx?) {
      parts.add(symptomContextLabel(loc, ctx));
    }
  } else {
    if (record.status == SymptomEpisodeStatus.resolved) {
      parts.add('끝났어요');
    } else if (record.trend case final trend?) {
      parts.add(symptomTrendLabel(loc, trend));
    } else {
      parts.add('시작');
      if (record.severity case final severity?) {
        parts.add(symptomSeverityLabel(loc, severity));
      }
    }
  }
  if (record.note?.trim().isNotEmpty == true) {
    parts.add(record.note!.trim());
  }
  return parts.join(' · ');
}
