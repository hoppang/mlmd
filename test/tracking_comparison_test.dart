import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/tracking/domain/tracking_models.dart';

void main() {
  const engine = TrackingComparisonEngine();

  TrackingDayValue day(
    int day,
    double value, {
    TrackingMode mode = TrackingMode.detailed,
    TrackingCoverage coverage = TrackingCoverage.mostlyComplete,
  }) => TrackingDayValue(
    localDate: DateTime(2026, 7, day),
    value: value,
    mode: mode,
    coverage: coverage,
  );

  test('누락 날짜를 0으로 만들지 않고 최근 완료 날짜의 중앙값과 비교한다', () {
    final result = engine.compareDaily(
      target: day(20, 7),
      previousDays: [
        day(19, 5),
        day(18, 100, coverage: TrackingCoverage.partial),
        day(17, 5),
        day(16, 6),
        day(15, 5),
      ],
    );

    expect(result.status, TrackingComparisonStatus.comparable);
    expect(result.baseline, 5);
    expect(result.relativeState, TrackingRelativeState.more);
    expect(result.excludedDates, [DateTime(2026, 7, 18)]);
  });

  test('기록 방식 변경 전 날짜는 직접 비교하지 않는다', () {
    final result = engine.compareDaily(
      target: day(20, 3, mode: TrackingMode.dailyCheckIn),
      previousDays: [day(19, 3), day(18, 3), day(17, 3), day(16, 3)],
    );

    expect(result.status, TrackingComparisonStatus.modeChanged);
    expect(result.isComparable, isFalse);
  });

  test('이전에 같은 방식을 썼더라도 중간 변경 경계를 넘어가지 않는다', () {
    final result = engine.compareDaily(
      target: day(20, 6),
      previousDays: [
        day(19, 6),
        day(18, 6, mode: TrackingMode.dailyCheckIn),
        day(17, 6),
        day(16, 6),
        day(15, 6),
        day(14, 6),
      ],
    );

    expect(result.status, TrackingComparisonStatus.modeChanged);
    expect(result.comparedDates, isEmpty);
  });

  test('부분 기록인 대상 날짜는 감소로 판정하지 않는다', () {
    final result = engine.compareDaily(
      target: day(20, 1, coverage: TrackingCoverage.partial),
      previousDays: [day(19, 6), day(18, 6), day(17, 6), day(16, 6)],
    );

    expect(result.status, TrackingComparisonStatus.incompleteTarget);
    expect(result.relativeState, TrackingRelativeState.unspecified);
  });

  test('특이할 때만 기록은 기록 부재 기반 수치 비교를 지원하지 않는다', () {
    final result = engine.compareDaily(
      target: day(20, 0, mode: TrackingMode.notableOnly),
      previousDays: const [],
    );

    expect(result.status, TrackingComparisonStatus.unsupportedMode);
  });
}
