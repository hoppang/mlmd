import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/tracking_repository.dart';
import '../domain/tracking_models.dart';

const defaultTrackingChildId = 'local-child';

class TrackingPreferencesNotifier extends Notifier<Map<String, TrackingMode>> {
  @override
  Map<String, TrackingMode> build() =>
      ref.watch(trackingRepositoryProvider).latestModes(defaultTrackingChildId);

  TrackingMode modeFor(String eventCategory) =>
      state[eventCategory] ?? TrackingMode.detailed;

  void setMode(String eventCategory, TrackingMode mode) {
    ref
        .read(trackingRepositoryProvider)
        .setMode(
          childId: defaultTrackingChildId,
          eventCategory: eventCategory,
          mode: mode,
        );
    state = ref
        .read(trackingRepositoryProvider)
        .latestModes(defaultTrackingChildId);
  }
}

final trackingPreferencesProvider =
    NotifierProvider<TrackingPreferencesNotifier, Map<String, TrackingMode>>(
      TrackingPreferencesNotifier.new,
      dependencies: [trackingRepositoryProvider],
    );
