import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/locale_provider.dart';
import '../../../repositories/profile_repository.dart';
import '../../children/application/child_profile_repository.dart';
import '../../children/domain/child_profile.dart';
import '../domain/quick_launch_models.dart';
import 'quick_launch_preferences.dart';

final quickLaunchPreferencesRepositoryProvider =
    Provider<QuickLaunchPreferencesRepository>(
      (ref) => QuickLaunchPreferencesRepository(_optionalPreferences(ref)),
      dependencies: [sharedPreferencesProvider],
    );

SharedPreferences? _optionalPreferences(Ref ref) {
  try {
    return ref.watch(sharedPreferencesProvider);
  } catch (_) {
    return null;
  }
}

final quickLaunchChildIdProvider = Provider<String>(
  (ref) => ref.watch(selectedChildIdProvider),
  dependencies: [selectedChildIdProvider],
);

final quickLaunchDeviceIdProvider = Provider<String>(
  (ref) => ref.watch(profileRepositoryProvider).currentDevice.deviceProfileId,
  dependencies: [profileRepositoryProvider],
);

class QuickLaunchState {
  const QuickLaunchState({
    required this.layout,
    this.recommendedMilestone,
    this.recommendedLayout,
  });

  final QuickLaunchLayout layout;
  final GrowthMilestone? recommendedMilestone;
  final QuickLaunchLayout? recommendedLayout;

  bool get hasRecommendation =>
      recommendedMilestone != null && recommendedLayout != null;

  QuickLaunchState copyWith({
    QuickLaunchLayout? layout,
    GrowthMilestone? recommendedMilestone,
    QuickLaunchLayout? recommendedLayout,
    bool clearRecommendation = false,
  }) => QuickLaunchState(
    layout: layout ?? this.layout,
    recommendedMilestone: clearRecommendation
        ? null
        : recommendedMilestone ?? this.recommendedMilestone,
    recommendedLayout: clearRecommendation
        ? null
        : recommendedLayout ?? this.recommendedLayout,
  );
}

class QuickLaunchNotifier extends Notifier<QuickLaunchState> {
  static const _snoozeDuration = Duration(days: 14);
  static const _recommendationBuilder = QuickLaunchRecommendationBuilder();
  static const _ageCalculator = GrowthAgeCalculator();

  late String _childId;
  late String _deviceProfileId;
  late QuickLaunchPreferencesRepository _repository;

  @override
  QuickLaunchState build() {
    _childId = ref.watch(quickLaunchChildIdProvider);
    _deviceProfileId = ref.watch(quickLaunchDeviceIdProvider);
    _repository = ref.watch(quickLaunchPreferencesRepositoryProvider);
    ref.watch(childProfileListProvider);
    final layout = _repository.loadLayout(
      childId: _childId,
      deviceProfileId: _deviceProfileId,
    );
    return _withRecommendation(layout);
  }

  Future<void> setSlot(int index, QuickLaunchSlot slot) async {
    final normalized = slot.copyWith(
      slotIndex: index,
      childId: _childId,
      deviceProfileId: _deviceProfileId,
    );
    final layout = state.layout.copyWithSlot(index, normalized);
    await _saveLayout(layout);
  }

  Future<void> clearSlot(int index) => setSlot(
    index,
    QuickLaunchSlot(
      slotIndex: index,
      childId: _childId,
      deviceProfileId: _deviceProfileId,
    ),
  );

  Future<void> moveSlot(int from, int to) async {
    if (from == to) return;
    final slots = List<QuickLaunchSlot>.from(state.layout.slots);
    final moved = slots.removeAt(from);
    slots.insert(to, moved);
    final layout = QuickLaunchLayout(
      slots: [
        for (var index = 0; index < slots.length; index++)
          slots[index].copyWith(slotIndex: index),
      ],
    );
    await _saveLayout(layout);
  }

  Future<void> applyRecommendation({Set<int>? selectedSlots}) async {
    final milestone = state.recommendedMilestone;
    final recommendation = state.recommendedLayout;
    if (milestone == null || recommendation == null) return;
    final indexes =
        selectedSlots ??
        Set<int>.from(List.generate(quickLaunchSlotCount, (index) => index));
    var next = state.layout;
    for (final index in indexes) {
      next = next.copyWithSlot(index, recommendation.slotAt(index));
    }
    final now = DateTime.now();
    await _repository.saveLayout(next);
    await _repository.saveDecision(
      QuickLaunchRecommendationDecision(
        childId: _childId,
        deviceProfileId: _deviceProfileId,
        milestone: milestone,
        recommendationVersion:
            QuickLaunchPreferencesRepository.recommendationVersion,
        status: indexes.length == quickLaunchSlotCount
            ? QuickLaunchRecommendationDecisionStatus.applied
            : QuickLaunchRecommendationDecisionStatus.partiallyApplied,
        suggestedAt: now,
        decidedAt: now,
        previousSlotSnapshot: state.layout.toJsonString(),
      ),
    );
    state = QuickLaunchState(layout: next);
  }

  Future<void> snoozeRecommendation() async {
    final milestone = state.recommendedMilestone;
    if (milestone == null) return;
    final now = DateTime.now();
    await _repository.saveDecision(
      QuickLaunchRecommendationDecision(
        childId: _childId,
        deviceProfileId: _deviceProfileId,
        milestone: milestone,
        recommendationVersion:
            QuickLaunchPreferencesRepository.recommendationVersion,
        status: QuickLaunchRecommendationDecisionStatus.snoozed,
        suggestedAt: now,
        decidedAt: now,
        nextEligibleAt: now.add(_snoozeDuration),
      ),
    );
    state = state.copyWith(clearRecommendation: true);
  }

  Future<void> skipRecommendation() async {
    final milestone = state.recommendedMilestone;
    if (milestone == null) return;
    final now = DateTime.now();
    await _repository.saveDecision(
      QuickLaunchRecommendationDecision(
        childId: _childId,
        deviceProfileId: _deviceProfileId,
        milestone: milestone,
        recommendationVersion:
            QuickLaunchPreferencesRepository.recommendationVersion,
        status: QuickLaunchRecommendationDecisionStatus.skipped,
        suggestedAt: now,
        decidedAt: now,
      ),
    );
    state = state.copyWith(clearRecommendation: true);
  }

  Future<bool> undoRecommendation(GrowthMilestone milestone) async {
    final decision = _repository.loadDecision(
      childId: _childId,
      deviceProfileId: _deviceProfileId,
      milestone: milestone,
    );
    final snapshot = decision?.previousSlotSnapshot;
    if (snapshot == null) return false;
    try {
      final layout = QuickLaunchLayout.fromJsonString(snapshot);
      await _repository.saveLayout(layout);
      await _repository.removeDecision(
        childId: _childId,
        deviceProfileId: _deviceProfileId,
        milestone: milestone,
      );
      state = _withRecommendation(layout);
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<void> _saveLayout(QuickLaunchLayout layout) async {
    await _repository.saveLayout(layout);
    state = state.copyWith(layout: layout);
  }

  QuickLaunchState _withRecommendation(QuickLaunchLayout layout) {
    final profile = _selectedChild();
    final birthDate = profile?.birthDate;
    if (birthDate == null) return QuickLaunchState(layout: layout);
    final decision = _ageCalculator.decisionFor(
      birthDate: birthDate,
      asOf: DateTime.now(),
    );
    final milestone = decision?.milestone;
    if (milestone == null) return QuickLaunchState(layout: layout);
    final saved = _repository.loadDecision(
      childId: _childId,
      deviceProfileId: _deviceProfileId,
      milestone: milestone,
    );
    if (!_shouldShow(saved)) return QuickLaunchState(layout: layout);
    return QuickLaunchState(
      layout: layout,
      recommendedMilestone: milestone,
      recommendedLayout: _recommendationBuilder.buildForMilestone(
        milestone: milestone,
        childId: _childId,
        deviceProfileId: _deviceProfileId,
      ),
    );
  }

  ChildProfile? _selectedChild() {
    final profiles = ref.read(childProfileListProvider);
    for (final profile in profiles) {
      if (profile.childId == _childId) return profile;
    }
    return null;
  }

  bool _shouldShow(QuickLaunchRecommendationDecision? decision) {
    if (decision == null) return true;
    if (decision.status != QuickLaunchRecommendationDecisionStatus.snoozed) {
      return false;
    }
    final nextEligibleAt = decision.nextEligibleAt;
    return nextEligibleAt != null && !DateTime.now().isBefore(nextEligibleAt);
  }
}

final quickLaunchProvider =
    NotifierProvider<QuickLaunchNotifier, QuickLaunchState>(
      QuickLaunchNotifier.new,
      dependencies: [
        quickLaunchChildIdProvider,
        quickLaunchDeviceIdProvider,
        quickLaunchPreferencesRepositoryProvider,
        childProfileListProvider,
      ],
    );
