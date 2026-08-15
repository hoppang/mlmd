import 'dart:async';
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
  final StreamController<ChildProfileMutation> _mutations =
      StreamController<ChildProfileMutation>.broadcast();
  final StreamController<void> _changes = StreamController<void>.broadcast();
  ChildProfileState _state;

  ChildProfileState get state => _state;

  List<ChildProfile> get children =>
      List.unmodifiable(_state.children.where((item) => !item.isDeleted));
  List<ChildProfile> get allChildren => List.unmodifiable(_state.children);
  Stream<ChildProfileMutation> get mutations => _mutations.stream;
  Stream<void> get changes => _changes.stream;
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
    _notifyMutation(profile, ChildProfileMutationKind.create);
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
      revision: _state.children[index].revision + 1,
      updatedAt: DateTime.now(),
    );
    final nextChildren = [..._state.children]..[index] = updated;
    _updateState(nextChildren);
    _notifyMutation(updated, ChildProfileMutationKind.update);
    return updated;
  }

  bool delete(String childId) {
    if (_state.children.length <= 1) return false;
    if (childId == ChildProfile.localChildId) return false;
    final index = _state.children.indexWhere(
      (item) => item.childId == childId && !item.isDeleted,
    );
    if (index < 0) return false;
    final deletedAt = DateTime.now();
    final deleted = _state.children[index].copyWith(
      revision: _state.children[index].revision + 1,
      updatedAt: deletedAt,
      deletedAt: deletedAt,
    );
    final nextChildren = [..._state.children]..[index] = deleted;
    final visibleChildren = nextChildren
        .where((item) => !item.isDeleted)
        .toList();
    final nextSelected =
        visibleChildren.any((item) => item.childId == _state.selectedChildId)
        ? _state.selectedChildId
        : visibleChildren.first.childId;
    _updateState(nextChildren, selectedChildId: nextSelected);
    _notifyMutation(deleted, ChildProfileMutationKind.delete);
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

  List<ChildProfile> associateUnscopedWithFamily(String familySpaceId) {
    var changed = false;
    final associated = _state.children.map((profile) {
      if (profile.familySpaceId != null) return profile;
      changed = true;
      return profile.copyWith(familySpaceId: familySpaceId);
    }).toList();
    if (changed) _updateState(associated);
    return List.unmodifiable(
      associated.where((item) => item.familySpaceId == familySpaceId),
    );
  }

  ChildProfile associateWithFamily(String childId, String familySpaceId) {
    final index = _state.children.indexWhere((item) => item.childId == childId);
    if (index < 0) throw StateError('Child profile does not exist.');
    final existing = _state.children[index];
    if (existing.familySpaceId == familySpaceId) return existing;
    if (existing.familySpaceId != null) {
      throw StateError('Child profile belongs to another family space.');
    }
    final associated = existing.copyWith(familySpaceId: familySpaceId);
    final nextChildren = [..._state.children]..[index] = associated;
    _updateState(nextChildren);
    return associated;
  }

  ChildProfile? findIncludingDeleted(String childId) {
    for (final profile in _state.children) {
      if (profile.childId == childId) return profile;
    }
    return null;
  }

  void applyRemote(ChildProfile profile) {
    final index = _state.children.indexWhere(
      (item) => item.childId == profile.childId,
    );
    final nextChildren = [..._state.children];
    if (index < 0) {
      nextChildren.add(profile);
    } else {
      nextChildren[index] = profile;
    }
    _updateState(nextChildren);
  }

  void dispose() {
    _mutations.close();
    _changes.close();
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
    if (!_changes.isClosed) _changes.add(null);
  }

  void _persist() {
    if (_prefs == null) return;
    _prefs.setString(
      _profilesKey,
      jsonEncode(_state.children.map((item) => item.toJson()).toList()),
    );
    _prefs.setString(_selectedChildIdKey, _state.selectedChildId);
  }

  void _notifyMutation(ChildProfile profile, ChildProfileMutationKind kind) {
    if (!_mutations.isClosed) {
      _mutations.add(ChildProfileMutation(profile: profile, kind: kind));
    }
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
    final visible = children.where((item) => !item.isDeleted).toList();
    if (selectedChildId != null &&
        visible.any((item) => item.childId == selectedChildId)) {
      return selectedChildId;
    }
    return visible.first.childId;
  }

  String _normalizeName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'name', 'Child name must not be empty.');
    }
    return normalized;
  }
}

enum ChildProfileMutationKind { create, update, delete }

class ChildProfileMutation {
  const ChildProfileMutation({required this.profile, required this.kind});

  final ChildProfile profile;
  final ChildProfileMutationKind kind;
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
  late final ChildProfileRepository repository;
  try {
    repository = ChildProfileRepository(ref.watch(sharedPreferencesProvider));
  } catch (_) {
    repository = ChildProfileRepository();
  }
  ref.onDispose(repository.dispose);
  return repository;
}, dependencies: [sharedPreferencesProvider]);

class ChildProfileListNotifier extends Notifier<List<ChildProfile>> {
  @override
  List<ChildProfile> build() {
    final repository = ref.watch(childProfileRepositoryProvider);
    final subscription = repository.changes.listen((_) {
      state = repository.children;
      ref.invalidate(selectedChildIdProvider);
    });
    ref.onDispose(subscription.cancel);
    return repository.children;
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
