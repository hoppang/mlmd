import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/medical_guidance.dart';
import 'package:mlmd/features/events/domain/symptom_record.dart';
import 'package:mlmd/l10n/app_localizations_ko.dart';
import 'package:mlmd/models/activity_entity.dart';

void main() {
  final occurredAt = DateTime(2026, 7, 24, 14, 40);

  test('발생형 증상 구조화 payload를 양과 상황과 함께 왕복한다', () {
    final record = SymptomRecord(
      symptomId: 'vomiting',
      symptomName: '구토',
      kind: SymptomKind.episodic,
      occurredAt: occurredAt,
      amount: SymptomAmount.moderate,
      context: SymptomContext.afterMeal,
      note: '식사 후 즉시',
    );

    final encoded = record.encode();
    final decoded = SymptomRecord.decode(encoded);

    expect(decoded?.symptomId, 'vomiting');
    expect(decoded?.symptomName, '구토');
    expect(decoded?.kind, SymptomKind.episodic);
    expect(decoded?.amount, SymptomAmount.moderate);
    expect(decoded?.context, SymptomContext.afterMeal);
    expect(decoded?.note, '식사 후 즉시');
    expect(
      symptomRecordDetails(AppLocalizationsKo(), record),
      '보통 · 식사 후 · 식사 후 즉시',
    );
  });

  test('지속형 증상 시작 및 상태 변화 payload를 왕복한다', () {
    final startRecord = SymptomRecord(
      symptomId: 'runny_nose',
      symptomName: '콧물',
      kind: SymptomKind.continuous,
      episodeId: 'ep-12345',
      status: SymptomEpisodeStatus.active,
      occurredAt: occurredAt,
      severity: SymptomSeverity.mild,
    );

    final startDecoded = SymptomRecord.decode(startRecord.encode());
    expect(startDecoded?.symptomId, 'runny_nose');
    expect(startDecoded?.kind, SymptomKind.continuous);
    expect(startDecoded?.episodeId, 'ep-12345');
    expect(startDecoded?.status, SymptomEpisodeStatus.active);
    expect(
      symptomRecordDetails(AppLocalizationsKo(), startRecord),
      '시작 · 약함',
    );

    final updateRecord = SymptomRecord(
      symptomId: 'runny_nose',
      symptomName: '콧물',
      kind: SymptomKind.continuous,
      episodeId: 'ep-12345',
      status: SymptomEpisodeStatus.active,
      occurredAt: occurredAt.add(const Duration(hours: 3)),
      trend: SymptomTrend.improved,
      note: '많이 줄어듦',
    );

    final updateDecoded = SymptomRecord.decode(updateRecord.encode());
    expect(updateDecoded?.trend, SymptomTrend.improved);
    expect(
      symptomRecordDetails(AppLocalizationsKo(), updateRecord),
      '나아졌어요 · 많이 줄어듦',
    );

    final resolvedRecord = SymptomRecord(
      symptomId: 'runny_nose',
      symptomName: '콧물',
      kind: SymptomKind.continuous,
      episodeId: 'ep-12345',
      status: SymptomEpisodeStatus.resolved,
      occurredAt: occurredAt.add(const Duration(days: 1)),
      resolvedAt: occurredAt.add(const Duration(days: 1)),
    );

    final resolvedDecoded = SymptomRecord.decode(resolvedRecord.encode());
    expect(resolvedDecoded?.status, SymptomEpisodeStatus.resolved);
    expect(
      symptomRecordDetails(AppLocalizationsKo(), resolvedRecord),
      '끝났어요',
    );
  });

  test('알 수 없는 schema/버전 및 유효하지 않은 JSON을 거부한다', () {
    expect(
      SymptomRecord.decode(
        '{"schema":"mlmd.symptom","version":2,"symptomId":"cough",'
        '"symptomName":"기침","kind":"continuous","occurredAt":"2026-07-24T14:40:00"}',
      ),
      isNull,
    );
    expect(
      SymptomRecord.decode(
        '{"schema":"mlmd.symptom","version":1,"symptomId":"cough",'
        '"symptomName":"기침","kind":"invalid_kind","occurredAt":"2026-07-24T14:40:00"}',
      ),
      isNull,
    );
  });

  test('심각한 구토 및 처짐 증상은 주의 필요를 반환한다', () {
    final severeVomiting = ActivityEntity(
      type: '구토',
      time: occurredAt,
      details: '많이 · 수유 후',
      structuredDataJson: SymptomRecord(
        symptomId: 'vomiting',
        symptomName: '구토',
        kind: SymptomKind.episodic,
        occurredAt: occurredAt,
        amount: SymptomAmount.severe,
      ).encode(),
      lastModified: occurredAt,
    );

    final eval = evaluateMedicalGuidance(severeVomiting);
    expect(eval.requiresAttention, isTrue);
    expect(eval.links, hasLength(1));
    expect(eval.links.single.ruleId, 'aap-symptom-severe-vomiting-lethargy');
  });
}
