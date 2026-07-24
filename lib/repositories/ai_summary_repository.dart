import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/objectbox_helper.dart';
import '../features/summaries/domain/summary_source_snapshot.dart';
import '../models/ai_summary_entity.dart';

enum AiSummaryFreshness { fresh, newRecords, sourceChanged }

abstract interface class AiSummaryRepository {
  List<AiSummaryEntity> getAll();

  AiSummaryEntity? getForPeriod(
    SummaryPeriodType periodType,
    DateTime periodStart,
  );

  AiSummaryEntity saveGenerated(
    SummarySourceSnapshot snapshot,
    String text, {
    required bool automatic,
    required String modelVersion,
  });

  AiSummaryEntity edit(int id, String text);
  AiSummaryEntity setHidden(int id, bool hidden);

  AiSummaryFreshness freshness(
    AiSummaryEntity summary,
    SummarySourceSnapshot current,
  );

  List<SummaryEvidence> evidenceFor(AiSummaryEntity summary);
}

class AiSummaryRepositoryImpl implements AiSummaryRepository {
  AiSummaryRepositoryImpl(this._objectBox);

  final ObjectBoxHelper _objectBox;

  @override
  List<AiSummaryEntity> getAll() {
    final values = _objectBox.aiSummaryBox.getAll()
      ..sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return values;
  }

  @override
  AiSummaryEntity? getForPeriod(
    SummaryPeriodType periodType,
    DateTime periodStart,
  ) {
    final id = _summaryId(periodType, periodStart);
    for (final summary in _objectBox.aiSummaryBox.getAll()) {
      if (summary.summaryId == id) return summary;
    }
    return null;
  }

  @override
  AiSummaryEntity saveGenerated(
    SummarySourceSnapshot snapshot,
    String text, {
    required bool automatic,
    required String modelVersion,
  }) {
    final existing = getForPeriod(snapshot.periodType, snapshot.start);
    final now = DateTime.now();
    final entity = AiSummaryEntity(
      id: existing?.id ?? 0,
      summaryId: _summaryId(snapshot.periodType, snapshot.start),
      periodType: snapshot.periodType == SummaryPeriodType.daily
          ? AiSummaryEntity.periodDaily
          : AiSummaryEntity.periodWeekly,
      periodStart: snapshot.start,
      periodEndExclusive: snapshot.endExclusive,
      generatedText: text.trim(),
      generatedAt: now,
      cutoffAt: snapshot.cutoffAt!,
      sourceFingerprint: snapshot.sourceFingerprint,
      evidenceJson: jsonEncode(
        snapshot.evidence.map(_evidenceToJson).toList(growable: false),
      ),
      hidden: false,
      userEdited: false,
      automatic: automatic,
      modelVersion: modelVersion,
    );
    entity.id = _objectBox.aiSummaryBox.put(entity);
    return entity;
  }

  @override
  AiSummaryEntity edit(int id, String text) {
    final entity = _require(id)
      ..editedText = text.trim()
      ..userEdited = true
      ..hidden = false;
    _objectBox.aiSummaryBox.put(entity);
    return entity;
  }

  @override
  AiSummaryEntity setHidden(int id, bool hidden) {
    final entity = _require(id)..hidden = hidden;
    _objectBox.aiSummaryBox.put(entity);
    return entity;
  }

  @override
  AiSummaryFreshness freshness(
    AiSummaryEntity summary,
    SummarySourceSnapshot current,
  ) {
    if (summary.sourceFingerprint == current.sourceFingerprint) {
      return AiSummaryFreshness.fresh;
    }
    final saved = {
      for (final item in _decodeEvidence(summary.evidenceJson))
        item.key: jsonEncode(_evidenceToComparableJson(item)),
    };
    final latest = {
      for (final item in current.evidence)
        item.key: jsonEncode(_evidenceToComparableJson(item)),
    };
    final oldSourcesUnchanged = saved.entries.every(
      (entry) => latest[entry.key] == entry.value,
    );
    if (oldSourcesUnchanged && latest.length > saved.length) {
      return AiSummaryFreshness.newRecords;
    }
    return AiSummaryFreshness.sourceChanged;
  }

  @override
  List<SummaryEvidence> evidenceFor(AiSummaryEntity summary) =>
      _decodeEvidence(summary.evidenceJson);

  AiSummaryEntity _require(int id) {
    final entity = _objectBox.aiSummaryBox.get(id);
    if (entity == null) throw StateError('AI summary does not exist.');
    return entity;
  }

  String _summaryId(SummaryPeriodType type, DateTime start) {
    final date =
        '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    return '${type.name}:$date';
  }

  Map<String, Object?> _evidenceToJson(SummaryEvidence evidence) => {
    'key': evidence.key,
    if (evidence.recordId != null) 'recordId': evidence.recordId,
    'diaryId': evidence.diaryId,
    if (evidence.activityId != null) 'activityId': evidence.activityId,
    'occurredAt': evidence.occurredAt.toIso8601String(),
    'title': evidence.title,
    'text': evidence.text,
    if (evidence.modifiedAt != null)
      'modifiedAt': evidence.modifiedAt!.toIso8601String(),
    if (evidence.authorProfileId != null)
      'authorProfileId': evidence.authorProfileId,
  };

  Map<String, Object?> _evidenceToComparableJson(SummaryEvidence evidence) => {
    'key': evidence.key,
    'recordId': evidence.recordId,
    'diaryId': evidence.diaryId,
    'activityId': evidence.activityId,
    'occurredAt': evidence.occurredAt.toIso8601String(),
    'title': evidence.title,
    'text': evidence.text,
    'authorProfileId': evidence.authorProfileId,
  };

  List<SummaryEvidence> _decodeEvidence(String source) {
    try {
      final values = jsonDecode(source) as List<dynamic>;
      return values
          .map((value) {
            final json = value as Map<String, dynamic>;
            return SummaryEvidence(
              key: json['key'] as String,
              recordId: json['recordId'] as String?,
              diaryId: json['diaryId'] as int,
              activityId: json['activityId'] as int?,
              occurredAt: DateTime.parse(json['occurredAt'] as String),
              title: json['title'] as String,
              text: json['text'] as String,
              modifiedAt: json['modifiedAt'] == null
                  ? null
                  : DateTime.parse(json['modifiedAt'] as String),
              authorProfileId: json['authorProfileId'] as String?,
            );
          })
          .toList(growable: false);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }
}

final aiSummaryRepositoryProvider = Provider<AiSummaryRepository>(
  (ref) => AiSummaryRepositoryImpl(ref.watch(objectBoxProvider)),
  dependencies: [objectBoxProvider],
);
