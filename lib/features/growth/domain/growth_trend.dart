import '../../../models/diary_entity.dart';
import '../../events/domain/growth_measurement_record.dart';

enum GrowthMetric { height, weight, headCircumference }

class GrowthTrendPoint {
  const GrowthTrendPoint({
    required this.recordId,
    required this.measuredAt,
    required this.value,
  });

  final String? recordId;
  final DateTime measuredAt;
  final double value;
}

List<GrowthTrendPoint> buildGrowthTrend(
  Iterable<DiaryEntity> diaries,
  GrowthMetric metric,
) {
  final points = <GrowthTrendPoint>[];
  for (final diary in diaries) {
    for (final activity in diary.activities) {
      final payload = activity.structuredDataJson;
      if (payload == null) continue;
      final record = GrowthMeasurementRecord.decode(payload);
      if (record == null) continue;
      final value = switch (metric) {
        GrowthMetric.height => record.heightCm,
        GrowthMetric.weight => record.weightKg,
        GrowthMetric.headCircumference => record.headCm,
      };
      if (value == null || value <= 0) continue;
      points.add(
        GrowthTrendPoint(
          recordId: activity.recordId ?? record.recordId,
          measuredAt: record.occurredAt,
          value: value,
        ),
      );
    }
  }
  points.sort((left, right) => left.measuredAt.compareTo(right.measuredAt));
  return List.unmodifiable(points);
}
