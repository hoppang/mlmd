import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../providers/locale_provider.dart';
import '../domain/child_profile.dart';

class ChildProfileRepository {
  ChildProfileRepository([this._prefs]) : _state = _loadState(_prefs);

  static const _uuid = Uuid();
  static const _profilesKey = 'child_profiles_json';
  static const _selectedChildIdKey = 'selected_child_id';

  final SharedPreferences? _prefs;
  ChildProfileState _state;

  ChildProfileState get state => _state;

  List<ChildProfile> get children => List.unmodifiable(_state.children);
  String get selectedChildId => _state.selectedChildId;
  ChildProfile get selectedChild => _state.children.firstWhere(
    (item) => item.childId == _state.selectedChildId,
  );

  ChildProfile create({
    required String name,
    DateTime? birthDate,
    String? childId,
  }) {
    final profile = ChildProfile(
      childId: childId ?? _uuid.v4(),
      name: _normalizeName(name),
      birthDate: birthDate,
      createdAt: DateTime.now(),
    );
    final nextChildren = [..._state.children, profile];
    _updateState(nextChildren, selectedChildId: profile.childId);
    return profile;
  }

  ChildProfile update({
    required String childId,
    required String name,
    DateTime? birthDate,
    bool clearBirthDate = false,
  }) {
    final index = _state.children.indexWhere((item) => item.childId == childId);
    if (index < 0) {
      throw StateError('Child profile does not exist.');
    }
    final updated = _state.children[index].copyWith(
      name: _normalizeName(name),
      birthDate: birthDate,
      clearBirthDate: clearBirthDate,
    );
    final nextChildren = [..._state.children]..[index] = updated;
    _updateState(nextChildren);
    return updated;
  }

  bool delete(String childId) {
    if (_state.children.length <= 1) return false;
    if (childId == ChildProfile.localChildId) return false;
    final nextChildren = _state.children
        .where((item) => item.childId != childId)
        .toList();
    if (nextChildren.length == _state.children.length) return false;
    final nextSelected =
        nextChildren.any((item) => item.childId == _state.selectedChildId)
        ? _state.selectedChildId
        : nextChildren.first.childId;
    _updateState(nextChildren, selectedChildId: nextSelected);
    return true;
  }

  void select(String childId) {
    if (!_state.children.any((item) => item.childId == childId)) {
      throw StateError('Child profile does not exist.');
    }
    _updateState(_state.children, selectedChildId: childId);
  }

  void reload() {
    _state = _loadState(_prefs);
  }

  void reset() {
    _updateState([
      ChildProfile.localDefault(),
    ], selectedChildId: ChildProfile.localChildId);
  }

  void _updateState(List<ChildProfile> children, {String? selectedChildId}) {
    final normalized = _normalize(children);
    final nextSelected = _normalizeSelectedChildId(
      normalized,
      selectedChildId ?? _state.selectedChildId,
    );
    _state = ChildProfileState(
      children: normalized,
      selectedChildId: nextSelected,
    );
    _persist();
  }

  void _persist() {
    if (_prefs == null) return;
    _prefs.setString(
      _profilesKey,
      jsonEncode(_state.children.map((item) => item.toJson()).toList()),
    );
    _prefs.setString(_selectedChildIdKey, _state.selectedChildId);
  }

  static ChildProfileState _loadState(SharedPreferences? prefs) {
    final decoded = _decodeChildren(prefs?.getString(_profilesKey));
    final children = _normalize(decoded);
    final selectedChildId = _normalizeSelectedChildId(
      children,
      prefs?.getString(_selectedChildIdKey),
    );
    return ChildProfileState(
      children: children,
      selectedChildId: selectedChildId,
    );
  }

  static List<ChildProfile> _decodeChildren(String? raw) {
    if (raw == null || raw.isEmpty) {
      return [ChildProfile.localDefault()];
    }
    final parsed = jsonDecode(raw);
    if (parsed is! List) {
      return [ChildProfile.localDefault()];
    }
    final children = <ChildProfile>[];
    for (final item in parsed) {
      if (item is Map<String, Object?>) {
        children.add(ChildProfile.fromJson(item));
      } else if (item is Map) {
        children.add(ChildProfile.fromJson(item.cast<String, Object?>()));
      }
    }
    return children.isEmpty ? [ChildProfile.localDefault()] : children;
  }

  static List<ChildProfile> _normalize(List<ChildProfile> children) {
    final seen = <String>{};
    final normalized = <ChildProfile>[];
    for (final child in children) {
      if (seen.add(child.childId)) {
        normalized.add(child);
      }
    }
    if (normalized.isEmpty) {
      normalized.add(ChildProfile.localDefault());
    }
    if (!normalized.any((item) => item.childId == ChildProfile.localChildId)) {
      normalized.insert(0, ChildProfile.localDefault());
    }
    normalized.sort((a, b) {
      if (a.childId == ChildProfile.localChildId) return -1;
      if (b.childId == ChildProfile.localChildId) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return normalized;
  }

  static String _normalizeSelectedChildId(
    List<ChildProfile> children,
    String? selectedChildId,
  ) {
    if (selectedChildId != null &&
        children.any((item) => item.childId == selectedChildId)) {
      return selectedChildId;
    }
    return children.first.childId;
  }

  String _normalizeName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'name', 'Child name must not be empty.');
    }
    return normalized;
  }
}

class ChildProfileState {
  const ChildProfileState({
    required this.children,
    required this.selectedChildId,
  });

  final List<ChildProfile> children;
  final String selectedChildId;
}

final childProfileRepositoryProvider = Provider<ChildProfileRepository>((ref) {
  try {
    return ChildProfileRepository(ref.watch(sharedPreferencesProvider));
  } catch (_) {
    return ChildProfileRepository();
  }
}, dependencies: [sharedPreferencesProvider]);

class ChildProfileListNotifier extends Notifier<List<ChildProfile>> {
  @override
  List<ChildProfile> build() {
    return ref.watch(childProfileRepositoryProvider).children;
  }

  void create({required String name, DateTime? birthDate, String? childId}) {
    ref
        .read(childProfileRepositoryProvider)
        .create(name: name, birthDate: birthDate, childId: childId);
    _reload();
    ref.invalidate(selectedChildIdProvider);
  }

  void update({
    required String childId,
    required String name,
    DateTime? birthDate,
    bool clearBirthDate = false,
  }) {
    ref
        .read(childProfileRepositoryProvider)
        .update(
          childId: childId,
          name: name,
          birthDate: birthDate,
          clearBirthDate: clearBirthDate,
        );
    _reload();
  }

  bool delete(String childId) {
    final deleted = ref.read(childProfileRepositoryProvider).delete(childId);
    _reload();
    ref.invalidate(selectedChildIdProvider);
    return deleted;
  }

  void reload() => _reload();

  void _reload() {
    state = ref.read(childProfileRepositoryProvider).children;
  }
}

final childProfileListProvider =
    NotifierProvider<ChildProfileListNotifier, List<ChildProfile>>(
      ChildProfileListNotifier.new,
      dependencies: [childProfileRepositoryProvider],
    );

class SelectedChildNotifier extends Notifier<String> {
  @override
  String build() {
    final repository = ref.watch(childProfileRepositoryProvider);
    return repository.selectedChildId;
  }

  void select(String childId) {
    ref.read(childProfileRepositoryProvider).select(childId);
    state = childId;
  }

  void reload() {
    state = ref.read(childProfileRepositoryProvider).selectedChildId;
  }
}

final selectedChildIdProvider = NotifierProvider<SelectedChildNotifier, String>(
  SelectedChildNotifier.new,
  dependencies: [childProfileRepositoryProvider],
);
