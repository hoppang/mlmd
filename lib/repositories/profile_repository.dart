import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

import '../data/objectbox_helper.dart';
import '../models/author_profile_entity.dart';
import '../models/device_profile_entity.dart';

class RecordSource {
  const RecordSource({
    required this.authorProfileId,
    required this.deviceProfileId,
  });

  final String authorProfileId;
  final String deviceProfileId;
}

abstract interface class ProfileRepository {
  List<AuthorProfileEntity> getAuthorProfiles();
  AuthorProfileEntity? get currentAuthor;
  DeviceProfileEntity get currentDevice;
  bool get hasSharedHistory;

  AuthorProfileEntity createAuthor({
    required String nickname,
    required int colorValue,
  });
  AuthorProfileEntity updateAuthor({
    required String authorProfileId,
    required String nickname,
    required int colorValue,
  });
  void selectAuthor(String authorProfileId);
  void markSharedHistory();
  AuthorProfileEntity? authorByProfileId(String authorProfileId);
  RecordSource requireCurrentSource();
}

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._objectBox) {
    _normalizeCurrentDevice();
    _normalizeCurrentAuthor();
  }

  static const _uuid = Uuid();
  final ObjectBoxHelper _objectBox;

  @override
  List<AuthorProfileEntity> getAuthorProfiles() {
    final profiles = _objectBox.authorProfileBox.getAll()
      ..sort((a, b) {
        if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    return profiles;
  }

  @override
  AuthorProfileEntity? get currentAuthor {
    for (final profile in _objectBox.authorProfileBox.getAll()) {
      if (profile.isCurrent) return profile;
    }
    return null;
  }

  @override
  DeviceProfileEntity get currentDevice {
    for (final profile in _objectBox.deviceProfileBox.getAll()) {
      if (profile.isCurrent) return profile;
    }
    throw StateError('Current device profile is not initialized.');
  }

  @override
  bool get hasSharedHistory => currentDevice.hasSharedHistory;

  @override
  AuthorProfileEntity createAuthor({
    required String nickname,
    required int colorValue,
  }) {
    final normalized = _normalizeNickname(nickname);
    final profile = AuthorProfileEntity(
      authorProfileId: _uuid.v4(),
      nickname: normalized,
      colorValue: colorValue,
      createdAt: DateTime.now(),
      isCurrent: true,
    );
    _objectBox.store.runInTransaction(TxMode.write, () {
      _clearCurrentAuthors();
      _objectBox.authorProfileBox.put(profile);
    });
    return profile;
  }

  @override
  AuthorProfileEntity updateAuthor({
    required String authorProfileId,
    required String nickname,
    required int colorValue,
  }) {
    final profile = authorByProfileId(authorProfileId);
    if (profile == null) {
      throw StateError('Author profile does not exist.');
    }
    profile
      ..nickname = _normalizeNickname(nickname)
      ..colorValue = colorValue;
    _objectBox.authorProfileBox.put(profile);
    return profile;
  }

  @override
  void selectAuthor(String authorProfileId) {
    final selected = authorByProfileId(authorProfileId);
    if (selected == null) {
      throw StateError('Author profile does not exist.');
    }
    _objectBox.store.runInTransaction(TxMode.write, () {
      for (final profile in _objectBox.authorProfileBox.getAll()) {
        final shouldBeCurrent = profile.id == selected.id;
        if (profile.isCurrent != shouldBeCurrent) {
          profile.isCurrent = shouldBeCurrent;
          _objectBox.authorProfileBox.put(profile);
        }
      }
    });
  }

  @override
  void markSharedHistory() {
    final device = currentDevice;
    if (device.hasSharedHistory) return;
    device.hasSharedHistory = true;
    _objectBox.deviceProfileBox.put(device);
  }

  @override
  AuthorProfileEntity? authorByProfileId(String authorProfileId) {
    for (final profile in _objectBox.authorProfileBox.getAll()) {
      if (profile.authorProfileId == authorProfileId) return profile;
    }
    return null;
  }

  @override
  RecordSource requireCurrentSource() {
    final author = currentAuthor;
    if (author == null) {
      throw StateError('An author profile is required before saving records.');
    }
    return RecordSource(
      authorProfileId: author.authorProfileId,
      deviceProfileId: currentDevice.deviceProfileId,
    );
  }

  void _normalizeCurrentDevice() {
    _objectBox.store.runInTransaction(TxMode.write, () {
      final devices = _objectBox.deviceProfileBox.getAll()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final current = devices.where((item) => item.isCurrent).toList();
      if (current.isEmpty) {
        _objectBox.deviceProfileBox.put(
          DeviceProfileEntity(
            deviceProfileId: _uuid.v4(),
            createdAt: DateTime.now(),
            isCurrent: true,
          ),
        );
        return;
      }
      final keep = current.last;
      for (final device in current) {
        if (device.id == keep.id) continue;
        device.isCurrent = false;
        _objectBox.deviceProfileBox.put(device);
      }
    });
  }

  void _normalizeCurrentAuthor() {
    _objectBox.store.runInTransaction(TxMode.write, () {
      final authors = _objectBox.authorProfileBox.getAll()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final current = authors.where((item) => item.isCurrent).toList();
      if (current.isEmpty && authors.isNotEmpty) {
        authors.first.isCurrent = true;
        _objectBox.authorProfileBox.put(authors.first);
        return;
      }
      if (current.length <= 1) return;
      final keep = current.last;
      for (final author in current) {
        if (author.id == keep.id) continue;
        author.isCurrent = false;
        _objectBox.authorProfileBox.put(author);
      }
    });
  }

  void _clearCurrentAuthors() {
    for (final profile in _objectBox.authorProfileBox.getAll()) {
      if (!profile.isCurrent) continue;
      profile.isCurrent = false;
      _objectBox.authorProfileBox.put(profile);
    }
  }

  String _normalizeNickname(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 30) {
      throw ArgumentError.value(
        value,
        'nickname',
        'Nickname must contain 1 to 30 characters.',
      );
    }
    return normalized;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(objectBoxProvider));
}, dependencies: [objectBoxProvider]);

class AuthorProfileListNotifier extends Notifier<List<AuthorProfileEntity>> {
  @override
  List<AuthorProfileEntity> build() {
    return ref.watch(profileRepositoryProvider).getAuthorProfiles();
  }

  void create({required String nickname, required int colorValue}) {
    ref
        .read(profileRepositoryProvider)
        .createAuthor(nickname: nickname, colorValue: colorValue);
    _reload();
  }

  void update({
    required String authorProfileId,
    required String nickname,
    required int colorValue,
  }) {
    ref
        .read(profileRepositoryProvider)
        .updateAuthor(
          authorProfileId: authorProfileId,
          nickname: nickname,
          colorValue: colorValue,
        );
    _reload();
  }

  void select(String authorProfileId) {
    ref.read(profileRepositoryProvider).selectAuthor(authorProfileId);
    _reload();
  }

  void reload() => _reload();

  void _reload() {
    state = ref.read(profileRepositoryProvider).getAuthorProfiles();
  }
}

final authorProfileListProvider =
    NotifierProvider<AuthorProfileListNotifier, List<AuthorProfileEntity>>(
      AuthorProfileListNotifier.new,
      dependencies: [profileRepositoryProvider],
    );
