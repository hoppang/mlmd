import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/quick_launch_models.dart';

class QuickLaunchPreferencesRepository {
  QuickLaunchPreferencesRepository(this._preferences);

  static const recommendationVersion = 1;
  static const _layoutPrefix = 'quick_launch.layout.v1';
  static const _decisionPrefix = 'quick_launch.recommendation.v1';

  final SharedPreferences? _preferences;
  final Map<String, String> _memory = {};

  QuickLaunchLayout loadLayout({
    required String childId,
    required String deviceProfileId,
  }) {
    final source = _getString(_layoutKey(childId, deviceProfileId));
    if (source != null) {
      try {
        return QuickLaunchLayout.fromJsonString(source);
      } on FormatException {
        // Fall back to a usable default without discarding the corrupt value.
      }
    }
    return const QuickLaunchRecommendationBuilder().buildForMilestone(
      milestone: GrowthMilestone.newborn,
      childId: childId,
      deviceProfileId: deviceProfileId,
    );
  }

  Future<void> saveLayout(QuickLaunchLayout layout) async {
    final first = layout.slots.first;
    final childId = first.childId;
    final deviceProfileId = first.deviceProfileId;
    if (childId == null || deviceProfileId == null) {
      throw ArgumentError('Quick launch layout requires child and device IDs.');
    }
    await _setString(
      _layoutKey(childId, deviceProfileId),
      layout.toJsonString(),
    );
  }

  QuickLaunchRecommendationDecision? loadDecision({
    required String childId,
    required String deviceProfileId,
    required GrowthMilestone milestone,
    int version = recommendationVersion,
  }) {
    final source = _getString(
      _decisionKey(childId, deviceProfileId, milestone, version),
    );
    if (source == null) return null;
    try {
      return QuickLaunchRecommendationDecision.fromJsonString(source);
    } on FormatException {
      return null;
    }
  }

  Future<void> saveDecision(QuickLaunchRecommendationDecision decision) =>
      _setString(
        _decisionKey(
          decision.childId,
          decision.deviceProfileId,
          decision.milestone,
          decision.recommendationVersion,
        ),
        decision.toJsonString(),
      );

  Future<void> removeDecision({
    required String childId,
    required String deviceProfileId,
    required GrowthMilestone milestone,
    int version = recommendationVersion,
  }) => _remove(_decisionKey(childId, deviceProfileId, milestone, version));

  String exportLayouts() {
    final values = <String, String>{};
    for (final key in _keys) {
      if (!key.startsWith(_layoutPrefix)) continue;
      final value = _getString(key);
      if (value != null) values[key] = value;
    }
    return jsonEncode(values);
  }

  String _layoutKey(String childId, String deviceProfileId) =>
      '$_layoutPrefix.$childId.$deviceProfileId';

  String _decisionKey(
    String childId,
    String deviceProfileId,
    GrowthMilestone milestone,
    int version,
  ) => '$_decisionPrefix.$childId.$deviceProfileId.${milestone.name}.$version';

  Set<String> get _keys => _preferences?.getKeys() ?? _memory.keys.toSet();

  String? _getString(String key) =>
      _preferences?.getString(key) ?? _memory[key];

  Future<bool> _setString(String key, String value) async {
    final preferences = _preferences;
    if (preferences != null) return preferences.setString(key, value);
    _memory[key] = value;
    return true;
  }

  Future<bool> _remove(String key) async {
    final preferences = _preferences;
    if (preferences != null) return preferences.remove(key);
    return _memory.remove(key) != null;
  }
}
