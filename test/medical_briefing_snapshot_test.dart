import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/medical_briefing/domain/medical_briefing_snapshot.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/diary_entity.dart';

DiaryEntity _diary({
  required int id,
  String? recordId,
  required DateTime date,
  required DateTime lastModified,
  List<ActivityEntity> activities = const [],
}) {
  final diary = DiaryEntity(
    id: id,
    recordId: recordId,
    date: date,
    title: 'title',
    content: 'content',
    lastModified: lastModified,
  );
  diary.activities.addAll(activities);
  return diary;
}

ActivityEntity _activity({
  required int id,
  required String type,
  required DateTime time,
  required DateTime lastModified,
  String details = '',
  bool exact = true,
  String? authorProfileId,
}) => ActivityEntity(
  id: id,
  type: type,
  time: time,
  timePrecision: exact
      ? ActivityEntity.timePrecisionExact
      : ActivityEntity.timePrecisionUnknown,
  details: details,
  lastModified: lastModified,
  createdByAuthorProfileId: authorProfileId,
  lastModifiedByAuthorProfileId: authorProfileId,
);

void main() {
  const builder = MedicalBriefingSnapshotBuilder();
  final start = DateTime(2026, 7, 20);
  final endExclusive = DateTime(2026, 7, 23);

  test('classifies multilingual aliases and filters by range', () {
    final snapshot = builder.build(
      [
        _diary(
          id: 1,
          recordId: 'r1',
          date: DateTime(2026, 7, 20),
          lastModified: DateTime(2026, 7, 20, 10),
          activities: [
            _activity(
              id: 11,
              type: '체온',
              time: DateTime(2026, 7, 20, 9),
              lastModified: DateTime(2026, 7, 20, 9, 1),
              details: '38.1°C',
            ),
            _activity(
              id: 12,
              type: 'Medication',
              time: DateTime(2026, 7, 20, 10),
              lastModified: DateTime(2026, 7, 20, 10, 1),
              details: '3mL',
            ),
            _activity(
              id: 13,
              type: 'memo',
              time: DateTime(2026, 7, 20, 11),
              lastModified: DateTime(2026, 7, 20, 11, 1),
              details: 'should be excluded',
            ),
          ],
        ),
        _diary(
          id: 2,
          recordId: 'r2',
          date: DateTime(2026, 7, 23),
          lastModified: DateTime(2026, 7, 23, 9),
          activities: [
            _activity(
              id: 21,
              type: '질병',
              time: DateTime(2026, 7, 23, 9),
              lastModified: DateTime(2026, 7, 23, 9, 1),
              details: 'outside range',
            ),
          ],
        ),
      ],
      start: start,
      endExclusive: endExclusive,
    );

    expect(snapshot.facts.map((fact) => fact.kind), [
      MedicalFactKind.temperature,
      MedicalFactKind.medication,
    ]);
    expect(snapshot.facts.every((fact) => fact.activityId != 13), isTrue);
    expect(
      snapshot.facts.every((fact) => fact.occurredAt.isBefore(endExclusive)),
      isTrue,
    );
    expect(
      snapshot.facts.every((fact) => !fact.occurredAt.isBefore(start)),
      isTrue,
    );
  });

  test('keeps repeated temperature facts and sorts by occurredAt', () {
    final snapshot = builder.build(
      [
        _diary(
          id: 1,
          recordId: 'r1',
          date: DateTime(2026, 7, 20),
          lastModified: DateTime(2026, 7, 20, 8),
          activities: [
            _activity(
              id: 1,
              type: 'temperature',
              time: DateTime(2026, 7, 20, 12),
              lastModified: DateTime(2026, 7, 20, 12, 5),
              details: '37.8',
            ),
            _activity(
              id: 2,
              type: 'temperature',
              time: DateTime(2026, 7, 20, 9),
              lastModified: DateTime(2026, 7, 20, 9, 5),
              details: '38.2',
            ),
          ],
        ),
      ],
      start: start,
      endExclusive: endExclusive,
    );

    expect(snapshot.facts.map((fact) => fact.activityId), [2, 1]);
    expect(snapshot.countsByKind[MedicalFactKind.temperature], 2);
  });

  test('keeps raw details and counts only exact medical kinds', () {
    final snapshot = builder.build(
      [
        _diary(
          id: 1,
          recordId: 'r1',
          date: DateTime(2026, 7, 20),
          lastModified: DateTime(2026, 7, 20, 8),
          activities: [
            _activity(
              id: 1,
              type: '症状・体調',
              time: DateTime(2026, 7, 20, 9),
              lastModified: DateTime(2026, 7, 20, 9, 5),
              details: 'raw\nline2',
            ),
            _activity(
              id: 2,
              type: 'Hospital · consultation',
              time: DateTime(2026, 7, 20, 10),
              lastModified: DateTime(2026, 7, 20, 10, 5),
              details: 'ER visit',
            ),
            _activity(
              id: 3,
              type: 'feeding',
              time: DateTime(2026, 7, 20, 11),
              lastModified: DateTime(2026, 7, 20, 11, 5),
              details: 'not medical',
            ),
          ],
        ),
      ],
      start: start,
      endExclusive: endExclusive,
    );

    expect(
      snapshot.facts
          .firstWhere((fact) => fact.kind == MedicalFactKind.symptom)
          .details,
      'raw\nline2',
    );
    expect(snapshot.countsByKind[MedicalFactKind.symptom], 1);
    expect(snapshot.countsByKind[MedicalFactKind.hospital], 1);
    expect(snapshot.facts.any((fact) => fact.storedType == 'feeding'), isFalse);
  });

  test('changes fingerprint when source metadata changes', () {
    final first = builder.build(
      [
        _diary(
          id: 1,
          recordId: 'r1',
          date: DateTime(2026, 7, 20),
          lastModified: DateTime(2026, 7, 20, 8),
          activities: [
            _activity(
              id: 1,
              type: 'vaccination',
              time: DateTime(2026, 7, 20, 9),
              lastModified: DateTime(2026, 7, 20, 9, 5),
              details: 'A',
              authorProfileId: 'a1',
            ),
          ],
        ),
      ],
      start: start,
      endExclusive: endExclusive,
    );

    final second = builder.build(
      [
        _diary(
          id: 1,
          recordId: 'r1',
          date: DateTime(2026, 7, 20),
          lastModified: DateTime(2026, 7, 20, 8),
          activities: [
            _activity(
              id: 1,
              type: 'vaccination',
              time: DateTime(2026, 7, 20, 9),
              lastModified: DateTime(2026, 7, 20, 9, 6),
              details: 'A',
              authorProfileId: 'a1',
            ),
          ],
        ),
      ],
      start: start,
      endExclusive: endExclusive,
    );

    expect(first.sourceFingerprint, isNot(equals(second.sourceFingerprint)));
  });

  test('keeps fingerprint stable when diary input order changes', () {
    final first = _diary(
      id: 1,
      recordId: 'r1',
      date: DateTime(2026, 7, 20),
      lastModified: DateTime(2026, 7, 20, 8),
      activities: [
        _activity(
          id: 11,
          type: '체온',
          time: DateTime(2026, 7, 20, 9),
          details: '37.2°C',
          lastModified: DateTime(2026, 7, 20, 9),
        ),
      ],
    );
    final second = _diary(
      id: 2,
      recordId: 'r2',
      date: DateTime(2026, 7, 20),
      lastModified: DateTime(2026, 7, 20, 8),
      activities: [
        _activity(
          id: 22,
          type: '투약',
          time: DateTime(2026, 7, 20, 10),
          details: '1회',
          lastModified: DateTime(2026, 7, 20, 10),
        ),
      ],
    );

    final forward = builder.build(
      [first, second],
      start: start,
      endExclusive: endExclusive,
    );
    final reversed = builder.build(
      [second, first],
      start: start,
      endExclusive: endExclusive,
    );

    expect(reversed.sourceFingerprint, forward.sourceFingerprint);
  });

  test('returns empty snapshot when no medical facts exist', () {
    final snapshot = builder.build(
      [
        _diary(
          id: 1,
          recordId: 'r1',
          date: DateTime(2026, 7, 20),
          lastModified: DateTime(2026, 7, 20, 8),
          activities: [
            _activity(
              id: 1,
              type: 'memo',
              time: DateTime(2026, 7, 20, 9),
              lastModified: DateTime(2026, 7, 20, 9, 5),
              details: 'x',
            ),
          ],
        ),
      ],
      start: start,
      endExclusive: endExclusive,
    );

    expect(snapshot.facts, isEmpty);
    expect(snapshot.latestOccurredAt, isNull);
    expect(snapshot.countsByKind.values.every((count) => count == 0), isTrue);
  });
}
