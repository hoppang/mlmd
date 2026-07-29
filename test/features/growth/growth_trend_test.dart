import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/growth_measurement_record.dart';
import 'package:mlmd/features/growth/domain/growth_trend.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/diary_entity.dart';

void main() {
  test('buildGrowthTrend keeps original values and sorts by measured time', () {
    final diary = DiaryEntity(
      date: DateTime(2026, 7, 29),
      title: '',
      summary: '',
      content: '',
      lastModified: DateTime(2026, 7, 29),
    );
    diary.activities.addAll([
      _growthActivity(
        recordId: 'later',
        occurredAt: DateTime(2026, 7, 20),
        heightCm: 65.1,
        weightKg: 8.2,
      ),
      _growthActivity(
        recordId: 'earlier',
        occurredAt: DateTime(2026, 6, 3),
        heightCm: 62,
      ),
      ActivityEntity(
        recordId: 'memo',
        type: '메모',
        time: DateTime(2026, 6, 10),
        details: 'not growth',
        lastModified: DateTime(2026, 6, 10),
      ),
    ]);

    final height = buildGrowthTrend([diary], GrowthMetric.height);
    final weight = buildGrowthTrend([diary], GrowthMetric.weight);

    expect(height.map((point) => point.recordId), ['earlier', 'later']);
    expect(height.map((point) => point.value), [62, 65.1]);
    expect(weight.map((point) => point.value), [8.2]);
  });

  test('buildGrowthTrend does not fill missing measurements', () {
    final diary = DiaryEntity(
      date: DateTime(2026, 7, 29),
      title: '',
      summary: '',
      content: '',
      lastModified: DateTime(2026, 7, 29),
    );
    diary.activities.add(
      _growthActivity(
        recordId: 'height-only',
        occurredAt: DateTime(2026, 7, 20),
        heightCm: 65.1,
      ),
    );

    expect(buildGrowthTrend([diary], GrowthMetric.weight), isEmpty);
    expect(buildGrowthTrend([diary], GrowthMetric.headCircumference), isEmpty);
  });
}

ActivityEntity _growthActivity({
  required String recordId,
  required DateTime occurredAt,
  double? heightCm,
  double? weightKg,
  double? headCm,
}) {
  return ActivityEntity(
    recordId: recordId,
    type: '성장 측정',
    time: occurredAt,
    details: '',
    structuredDataJson: GrowthMeasurementRecord(
      recordId: recordId,
      occurredAt: occurredAt,
      heightCm: heightCm,
      weightKg: weightKg,
      headCm: headCm,
    ).encode(),
    lastModified: occurredAt,
  );
}
