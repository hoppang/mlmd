import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';

import '../data/objectbox_helper.dart';
import '../features/tracking/domain/tracking_models.dart';
import '../models/daily_tracking_coverage_entity.dart';
import '../models/tracking_preference_entity.dart';

abstract interface class TrackingRepository {
  TrackingMode modeFor(String childId, String eventCategory, {DateTime? at});

  Map<String, TrackingMode> latestModes(String childId);

  TrackingPreferenceEntity setMode({
    required String childId,
    required String eventCategory,
    required TrackingMode mode,
    DateTime? changedAt,
  });

  DailyTrackingCoverageEntity? coverageFor({
    required String childId,
    required DateTime localDate,
    required String eventCategory,
  });

  DailyTrackingCoverageEntity saveCoverage({
    required String childId,
    required DateTime localDate,
    required String eventCategory,
    required TrackingCoverage coverage,
    TrackingRelativeState relativeState = TrackingRelativeState.unspecified,
    String? memo,
  });
}

class TrackingRepositoryImpl implements TrackingRepository {
  TrackingRepositoryImpl(ObjectBoxHelper objectBox)
    : this.fromStore(objectBox.store);

  TrackingRepositoryImpl.fromStore(Store store)
    : _preferenceBox = Box<TrackingPreferenceEntity>(store),
      _coverageBox = Box<DailyTrackingCoverageEntity>(store);

  final Box<TrackingPreferenceEntity> _preferenceBox;
  final Box<DailyTrackingCoverageEntity> _coverageBox;

  @override
  TrackingMode modeFor(String childId, String eventCategory, {DateTime? at}) {
    final limit = at ?? DateTime.now();
    final matches =
        _preferenceBox
            .getAll()
            .where(
              (item) =>
                  item.childId == childId &&
                  item.eventCategory == eventCategory &&
                  !item.changedAt.isAfter(limit),
            )
            .toList()
          ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
    return matches.isEmpty
        ? TrackingMode.detailed
        : _parseMode(matches.first.mode);
  }

  @override
  Map<String, TrackingMode> latestModes(String childId) {
    final result = <String, TrackingPreferenceEntity>{};
    for (final item in _preferenceBox.getAll()) {
      if (item.childId != childId) continue;
      final previous = result[item.eventCategory];
      if (previous == null || item.changedAt.isAfter(previous.changedAt)) {
        result[item.eventCategory] = item;
      }
    }
    return {
      for (final entry in result.entries)
        entry.key: _parseMode(entry.value.mode),
    };
  }

  @override
  TrackingPreferenceEntity setMode({
    required String childId,
    required String eventCategory,
    required TrackingMode mode,
    DateTime? changedAt,
  }) {
    final effectiveAt = changedAt ?? DateTime.now();
    final current = modeFor(childId, eventCategory, at: effectiveAt);
    final existing = _preferenceBox
        .getAll()
        .where(
          (item) =>
              item.childId == childId &&
              item.eventCategory == eventCategory &&
              item.changedAt.isAtSameMomentAs(effectiveAt),
        )
        .firstOrNull;
    if (existing != null) {
      existing.mode = mode.name;
      _preferenceBox.put(existing);
      return existing;
    }
    if (current == mode) {
      final latest =
          _preferenceBox
              .getAll()
              .where(
                (item) =>
                    item.childId == childId &&
                    item.eventCategory == eventCategory,
              )
              .toList()
            ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
      if (latest.isNotEmpty) return latest.first;
    }
    final entity = TrackingPreferenceEntity(
      childId: childId,
      eventCategory: eventCategory,
      mode: mode.name,
      changedAt: effectiveAt,
    );
    entity.id = _preferenceBox.put(entity);
    return entity;
  }

  @override
  DailyTrackingCoverageEntity? coverageFor({
    required String childId,
    required DateTime localDate,
    required String eventCategory,
  }) {
    final date = _dateKey(localDate);
    return _coverageBox
        .getAll()
        .where(
          (item) =>
              item.childId == childId &&
              item.localDate == date &&
              item.eventCategory == eventCategory,
        )
        .firstOrNull;
  }

  @override
  DailyTrackingCoverageEntity saveCoverage({
    required String childId,
    required DateTime localDate,
    required String eventCategory,
    required TrackingCoverage coverage,
    TrackingRelativeState relativeState = TrackingRelativeState.unspecified,
    String? memo,
  }) {
    final entity =
        coverageFor(
          childId: childId,
          localDate: localDate,
          eventCategory: eventCategory,
        ) ??
        DailyTrackingCoverageEntity(
          childId: childId,
          localDate: _dateKey(localDate),
          eventCategory: eventCategory,
          coverage: coverage.name,
          relativeState: relativeState.name,
          lastModified: DateTime.now(),
        );
    entity
      ..coverage = coverage.name
      ..relativeState = relativeState.name
      ..memo = memo?.trim().isEmpty == true ? null : memo?.trim()
      ..lastModified = DateTime.now();
    entity.id = _coverageBox.put(entity);
    return entity;
  }

  TrackingMode _parseMode(String raw) => TrackingMode.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => TrackingMode.detailed,
  );

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => TrackingRepositoryImpl(ref.watch(objectBoxProvider)),
  dependencies: [objectBoxProvider],
);
