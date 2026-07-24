import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/summaries/domain/summary_source_snapshot.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/diary_entity.dart';

DiaryEntity _diary({
  required int id,
  String? recordId,
  required DateTime date,
  required String title,
  String summary = '',
  String content = '',
  List<ActivityEntity> activities = const [],
}) {
  final diary = DiaryEntity(
    id: id,
    recordId: recordId,
    date: date,
    title: title,
    summary: summary,
    content: content,
    lastModified: date,
  );
  diary.activities.addAll(activities);
  return diary;
}

ActivityEntity _activity({
  required int id,
  required String type,
  required DateTime time,
  required String details,
}) => ActivityEntity(
  id: id,
  type: type,
  time: time,
  details: details,
  lastModified: time,
);

void main() {
  const builder = SummarySourceSnapshotBuilder();

  test('filters evidence by range and sorts by occurredAt', () {
    final diaries = [
      _diary(
        id: 1,
        recordId: 'r1',
        date: DateTime(2026, 7, 20, 9),
        title: '밖에서 놀기',
        summary: '아침 산책',
        content: '공원에 다녀왔다.',
        activities: [
          _activity(
            id: 11,
            type: 'feeding',
            time: DateTime(2026, 7, 20, 8, 30),
            details: '120ml',
          ),
        ],
      ),
      _diary(
        id: 2,
        recordId: 'r2',
        date: DateTime(2026, 7, 23, 9),
        title: '범위 밖',
        content: '무시되어야 함',
      ),
    ];

    final snapshot = builder.build(
      diaries,
      periodType: SummaryPeriodType.daily,
      start: DateTime(2026, 7, 20),
      endExclusive: DateTime(2026, 7, 21),
    );

    expect(snapshot.recordCount, 2);
    expect(snapshot.evidence, hasLength(2));
    expect(snapshot.evidence.map((e) => e.key), ['activity:11', 'diary:r1']);
    expect(snapshot.cutoffAt, DateTime(2026, 7, 20, 9));
  });

  test(
    'counts non-empty activity types and builds deterministic fingerprint',
    () {
      final diaries = [
        _diary(
          id: 1,
          recordId: 'r1',
          date: DateTime(2026, 7, 20, 9),
          title: '기록',
          activities: [
            _activity(
              id: 11,
              type: 'feeding',
              time: DateTime(2026, 7, 20, 9, 10),
              details: '80ml',
            ),
            _activity(
              id: 12,
              type: 'feeding',
              time: DateTime(2026, 7, 20, 9, 40),
              details: '40ml',
            ),
            _activity(
              id: 13,
              type: ' ',
              time: DateTime(2026, 7, 20, 10),
              details: 'ignored for counting',
            ),
          ],
        ),
      ];

      final first = builder.build(
        diaries,
        periodType: SummaryPeriodType.weekly,
        start: DateTime(2026, 7, 19),
        endExclusive: DateTime(2026, 7, 26),
      );
      final second = builder.build(
        diaries,
        periodType: SummaryPeriodType.weekly,
        start: DateTime(2026, 7, 19),
        endExclusive: DateTime(2026, 7, 26),
      );

      expect(first.activityCounts['feeding'], 2);
      expect(first.activityCounts.containsKey(' '), isFalse);
      expect(first.sourceFingerprint, second.sourceFingerprint);
      expect(first.promptText, contains('코드 계산 활동 수치: feeding=2'));
      expect(first.promptText, contains('근거 activity:11'));
    },
  );

  test('changes fingerprint when source content changes', () {
    final base = [
      _diary(
        id: 1,
        recordId: 'r1',
        date: DateTime(2026, 7, 20, 9),
        title: '제목',
        content: '본문',
      ),
    ];
    final changed = [
      _diary(
        id: 1,
        recordId: 'r1',
        date: DateTime(2026, 7, 20, 9),
        title: '제목',
        content: '본문 변경',
      ),
    ];

    final before = builder.build(
      base,
      periodType: SummaryPeriodType.daily,
      start: DateTime(2026, 7, 20),
      endExclusive: DateTime(2026, 7, 21),
    );
    final after = builder.build(
      changed,
      periodType: SummaryPeriodType.daily,
      start: DateTime(2026, 7, 20),
      endExclusive: DateTime(2026, 7, 21),
    );

    expect(before.sourceFingerprint, isNot(equals(after.sourceFingerprint)));
  });

  test('builds an empty snapshot when nothing is in range', () {
    final snapshot = builder.build(
      [
        _diary(
          id: 1,
          recordId: 'r1',
          date: DateTime(2026, 7, 20, 9),
          title: '범위 밖',
          content: '내용',
        ),
      ],
      periodType: SummaryPeriodType.daily,
      start: DateTime(2026, 7, 21),
      endExclusive: DateTime(2026, 7, 22),
    );

    expect(snapshot.evidence, isEmpty);
    expect(snapshot.recordCount, 0);
    expect(snapshot.cutoffAt, isNull);
    expect(snapshot.promptText, contains('주의: 아래 근거를 바탕으로만 요약'));
  });
}
