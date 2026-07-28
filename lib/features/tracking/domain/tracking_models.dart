enum TrackingMode { detailed, dailyCheckIn, notableOnly, hidden }

enum TrackingCoverage { unknown, mostlyComplete, partial }

enum TrackingRelativeState { usual, less, more, unspecified }

enum TrackingComparisonStatus {
  comparable,
  insufficientHistory,
  incompleteTarget,
  modeChanged,
  unsupportedMode,
}

class TrackingDayValue {
  const TrackingDayValue({
    required this.localDate,
    required this.value,
    required this.mode,
    required this.coverage,
  });

  final DateTime localDate;
  final double value;
  final TrackingMode mode;
  final TrackingCoverage coverage;
}

class TrackingComparison {
  const TrackingComparison({
    required this.status,
    this.relativeState = TrackingRelativeState.unspecified,
    this.baseline,
    this.comparedDates = const [],
    this.excludedDates = const [],
  });

  final TrackingComparisonStatus status;
  final TrackingRelativeState relativeState;
  final double? baseline;
  final List<DateTime> comparedDates;
  final List<DateTime> excludedDates;

  bool get isComparable => status == TrackingComparisonStatus.comparable;
}

/// 결측을 0으로 만들지 않고, 바로 앞의 완료된 같은 기록 방식 날짜만 비교한다.
class TrackingComparisonEngine {
  const TrackingComparisonEngine();

  static const algorithmVersion = 'tracking-median-v1';

  TrackingComparison compareDaily({
    required TrackingDayValue target,
    required Iterable<TrackingDayValue> previousDays,
    int minimumComparableDays = 4,
    int maximumComparableDays = 7,
  }) {
    if (target.mode == TrackingMode.notableOnly ||
        target.mode == TrackingMode.hidden) {
      return const TrackingComparison(
        status: TrackingComparisonStatus.unsupportedMode,
      );
    }
    if (target.coverage != TrackingCoverage.mostlyComplete) {
      return const TrackingComparison(
        status: TrackingComparisonStatus.incompleteTarget,
      );
    }

    final beforeTarget =
        previousDays
            .where((day) => day.localDate.isBefore(target.localDate))
            .toList()
          ..sort((a, b) => b.localDate.compareTo(a.localDate));
    final excluded = <DateTime>[];
    var sawOtherMode = false;
    final candidates = <TrackingDayValue>[];
    for (final day in beforeTarget) {
      if (day.mode != target.mode) {
        sawOtherMode = true;
        excluded.add(day.localDate);
        // A mode change starts a new baseline segment. Do not reach past that
        // boundary even if an older period happened to use the same mode.
        break;
      }
      if (day.coverage != TrackingCoverage.mostlyComplete) {
        excluded.add(day.localDate);
        continue;
      }
      candidates.add(day);
      if (candidates.length == maximumComparableDays) break;
    }
    if (candidates.length < minimumComparableDays) {
      return TrackingComparison(
        status: sawOtherMode
            ? TrackingComparisonStatus.modeChanged
            : TrackingComparisonStatus.insufficientHistory,
        excludedDates: excluded,
      );
    }

    final values = candidates.map((day) => day.value).toList()..sort();
    final baseline = _median(values);
    final deviations = values.map((value) => (value - baseline).abs()).toList()
      ..sort();
    final ordinaryVariation = _median(deviations);
    final tolerance = ordinaryVariation == 0
        ? (baseline.abs() * 0.1).clamp(1.0, double.infinity)
        : ordinaryVariation;
    final relative = target.value < baseline - tolerance
        ? TrackingRelativeState.less
        : target.value > baseline + tolerance
        ? TrackingRelativeState.more
        : TrackingRelativeState.usual;

    return TrackingComparison(
      status: TrackingComparisonStatus.comparable,
      relativeState: relative,
      baseline: baseline,
      comparedDates: candidates.map((day) => day.localDate).toList(),
      excludedDates: excluded,
    );
  }

  double _median(List<double> sorted) {
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
