import '../../../models/diary_entity.dart';

enum SummaryPeriodType { daily, weekly }

class SummaryEvidence {
  const SummaryEvidence({
    required this.key,
    required this.recordId,
    required this.diaryId,
    this.activityId,
    required this.occurredAt,
    required this.title,
    required this.text,
    this.modifiedAt,
    this.authorProfileId,
  });

  final String key;
  final String? recordId;
  final int diaryId;
  final int? activityId;
  final DateTime occurredAt;
  final String title;
  final String text;
  final DateTime? modifiedAt;
  final String? authorProfileId;
}

class SummarySourceSnapshot {
  const SummarySourceSnapshot({
    required this.periodType,
    required this.start,
    required this.endExclusive,
    required this.evidence,
    required this.activityCounts,
    required this.sourceFingerprint,
    required this.cutoffAt,
    required this.recordCount,
    required this.promptText,
  });

  final SummaryPeriodType periodType;
  final DateTime start;
  final DateTime endExclusive;
  final List<SummaryEvidence> evidence;
  final Map<String, int> activityCounts;
  final String sourceFingerprint;
  final DateTime? cutoffAt;
  final int recordCount;
  final String promptText;
}

class SummarySourceSnapshotBuilder {
  const SummarySourceSnapshotBuilder();

  SummarySourceSnapshot build(
    List<DiaryEntity> diaries, {
    required SummaryPeriodType periodType,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final evidence = <SummaryEvidence>[];
    final activityCounts = <String, int>{};

    for (final diary in diaries) {
      if (_inRange(diary.date, start, endExclusive) &&
          (_hasText(diary.title) ||
              _hasText(diary.summary) ||
              _hasText(diary.content))) {
        evidence.add(
          SummaryEvidence(
            key: 'diary:${diary.recordId ?? diary.id}',
            recordId: diary.recordId,
            diaryId: diary.id,
            occurredAt: diary.date,
            title: diary.title.trim(),
            text: _compactText([diary.summary, diary.content]),
            modifiedAt: diary.lastModified,
            authorProfileId: diary.createdByAuthorProfileId,
          ),
        );
      }

      for (final activity in diary.activities) {
        if (!_inRange(activity.time, start, endExclusive)) continue;
        final type = activity.type.trim();
        if (type.isNotEmpty) {
          activityCounts[type] = (activityCounts[type] ?? 0) + 1;
        }
        evidence.add(
          SummaryEvidence(
            key: 'activity:${activity.id}',
            recordId: diary.recordId,
            diaryId: diary.id,
            activityId: activity.id,
            occurredAt: activity.time,
            title: type,
            text: activity.details.trim(),
            modifiedAt: activity.lastModified,
            authorProfileId: activity.createdByAuthorProfileId,
          ),
        );
      }
    }

    evidence.sort((a, b) {
      final byTime = a.occurredAt.compareTo(b.occurredAt);
      if (byTime != 0) return byTime;
      return a.key.compareTo(b.key);
    });

    final fingerprint = _hash([
      periodType.name,
      start.toIso8601String(),
      endExclusive.toIso8601String(),
      for (final item in evidence)
        [
          item.key,
          item.recordId ?? '',
          item.diaryId.toString(),
          item.activityId?.toString() ?? '',
          item.occurredAt.toIso8601String(),
          item.title,
          item.text,
          item.modifiedAt?.toIso8601String() ?? '',
          item.authorProfileId ?? '',
        ].join('|'),
    ]);
    final cutoffAt = evidence.isEmpty
        ? null
        : evidence
              .map((item) => item.occurredAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    return SummarySourceSnapshot(
      periodType: periodType,
      start: start,
      endExclusive: endExclusive,
      evidence: List.unmodifiable(evidence),
      activityCounts: Map.unmodifiable(activityCounts),
      sourceFingerprint: fingerprint,
      cutoffAt: cutoffAt,
      recordCount: evidence.length,
      promptText: _buildPromptText(
        periodType: periodType,
        start: start,
        endExclusive: endExclusive,
        evidence: evidence,
        activityCounts: activityCounts,
      ),
    );
  }

  bool _inRange(DateTime value, DateTime start, DateTime endExclusive) =>
      !value.isBefore(start) && value.isBefore(endExclusive);

  bool _hasText(String value) => value.trim().isNotEmpty;

  String _compactText(List<String> parts) => parts
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join('\n');

  String _buildPromptText({
    required SummaryPeriodType periodType,
    required DateTime start,
    required DateTime endExclusive,
    required List<SummaryEvidence> evidence,
    required Map<String, int> activityCounts,
  }) {
    final buffer = StringBuffer()
      ..writeln('기간: ${periodType.name}')
      ..writeln('시작: ${start.toIso8601String()}')
      ..writeln('종료: ${endExclusive.toIso8601String()}')
      ..writeln(
        '코드 계산 활동 수치: ${activityCounts.entries.map((entry) => '${entry.key}=${entry.value}').join(', ')}',
      )
      ..writeln('주의: 아래 근거를 바탕으로만 요약하고, 숫자 계산이나 사실 추정을 하지 마세요.');

    for (final item in evidence) {
      buffer
        ..writeln('근거 ${item.key}')
        ..writeln('시간: ${item.occurredAt.toIso8601String()}')
        ..writeln('제목: ${item.title}')
        ..writeln('본문: ${item.text}');
    }

    return buffer.toString().trimRight();
  }

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
