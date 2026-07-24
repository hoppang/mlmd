import '../../../models/diary_entity.dart';
import '../../events/domain/event_catalog.dart';

enum MedicalFactKind {
  temperature,
  medication,
  symptom,
  hospital,
  vaccination,
  accidentInjury,
}

class MedicalBriefingFact {
  const MedicalBriefingFact({
    required this.key,
    required this.kind,
    required this.diaryId,
    required this.activityId,
    required this.occurredAt,
    required this.hasExactTime,
    required this.storedType,
    required this.details,
    required this.authorProfileId,
  });

  final String key;
  final MedicalFactKind kind;
  final int diaryId;
  final int activityId;
  final DateTime occurredAt;
  final bool hasExactTime;
  final String storedType;
  final String details;
  final String? authorProfileId;
}

class MedicalBriefingSnapshot {
  const MedicalBriefingSnapshot({
    required this.start,
    required this.endExclusive,
    required this.facts,
    required this.countsByKind,
    required this.sourceFingerprint,
    required this.latestOccurredAt,
  });

  final DateTime start;
  final DateTime endExclusive;
  final List<MedicalBriefingFact> facts;
  final Map<MedicalFactKind, int> countsByKind;
  final String sourceFingerprint;
  final DateTime? latestOccurredAt;
}

class MedicalBriefingSnapshotBuilder {
  const MedicalBriefingSnapshotBuilder();

  MedicalBriefingSnapshot build(
    List<DiaryEntity> diaries, {
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final facts = <MedicalBriefingFact>[];
    final fingerprintSourceParts = <String>[];

    for (final diary in diaries) {
      for (final activity in diary.activities) {
        if (!_inRange(activity.time, start, endExclusive)) continue;
        final kind = _classify(activity.type);
        if (kind == null) continue;

        facts.add(
          MedicalBriefingFact(
            key: 'activity:${diary.recordId ?? diary.id}:${activity.id}',
            kind: kind,
            diaryId: diary.id,
            activityId: activity.id,
            occurredAt: activity.time,
            hasExactTime: activity.hasExactTime,
            storedType: activity.type,
            details: activity.details,
            authorProfileId:
                activity.lastModifiedByAuthorProfileId ??
                activity.createdByAuthorProfileId,
          ),
        );
        fingerprintSourceParts.add(
          [
            'activity:${diary.recordId ?? diary.id}:${activity.id}',
            diary.id.toString(),
            activity.id.toString(),
            activity.time.microsecondsSinceEpoch.toString(),
            activity.hasExactTime.toString(),
            activity.type,
            activity.details,
            activity.lastModified.microsecondsSinceEpoch.toString(),
            activity.lastModifiedByAuthorProfileId ??
                activity.createdByAuthorProfileId ??
                '',
          ].join('|'),
        );
      }
    }

    facts.sort((left, right) {
      final byTime = left.occurredAt.compareTo(right.occurredAt);
      if (byTime != 0) return byTime;
      return left.key.compareTo(right.key);
    });

    final countsByKind = <MedicalFactKind, int>{
      for (final kind in MedicalFactKind.values) kind: 0,
    };
    for (final fact in facts) {
      countsByKind[fact.kind] = countsByKind[fact.kind]! + 1;
    }

    fingerprintSourceParts.sort();
    final fingerprint = _hash([
      start.toIso8601String(),
      endExclusive.toIso8601String(),
      ...fingerprintSourceParts,
    ]);

    return MedicalBriefingSnapshot(
      start: start,
      endExclusive: endExclusive,
      facts: List.unmodifiable(facts),
      countsByKind: Map.unmodifiable(countsByKind),
      sourceFingerprint: fingerprint,
      latestOccurredAt: facts.isEmpty
          ? null
          : facts
                .map((fact) => fact.occurredAt)
                .reduce((left, right) => left.isAfter(right) ? left : right),
    );
  }

  MedicalFactKind? _classify(String storedType) {
    if (eventCatalogItem(EventTypeId.temperature).matches(storedType)) {
      return MedicalFactKind.temperature;
    }
    if (eventCatalogItem(EventTypeId.medication).matches(storedType)) {
      return MedicalFactKind.medication;
    }
    if (eventCatalogItem(EventTypeId.symptom).matches(storedType)) {
      return MedicalFactKind.symptom;
    }
    if (eventCatalogItem(EventTypeId.hospital).matches(storedType)) {
      return MedicalFactKind.hospital;
    }
    if (eventCatalogItem(EventTypeId.vaccination).matches(storedType)) {
      return MedicalFactKind.vaccination;
    }
    if (eventCatalogItem(EventTypeId.accidentInjury).matches(storedType)) {
      return MedicalFactKind.accidentInjury;
    }
    return null;
  }

  bool _inRange(DateTime value, DateTime start, DateTime endExclusive) =>
      !value.isBefore(start) && value.isBefore(endExclusive);

  String _hash(Iterable<String> parts) {
    const fnvOffset = 0xcbf29ce484222325;
    const fnvPrime = 0x100000001b3;
    var hash = fnvOffset;
    for (final part in parts) {
      for (final codeUnit in part.codeUnits) {
        hash ^= codeUnit;
        hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
      }
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
