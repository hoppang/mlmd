import 'package:mlmd/models/author_profile_entity.dart';
import 'package:mlmd/models/device_profile_entity.dart';
import 'package:mlmd/repositories/profile_repository.dart';

class TestProfileRepository implements ProfileRepository {
  TestProfileRepository({
    String nickname = 'Test author',
    bool withAuthor = true,
  }) {
    if (withAuthor) {
      _authors.add(
        AuthorProfileEntity(
          authorProfileId: _authorId,
          nickname: nickname,
          colorValue: 0xFF00796B,
          createdAt: DateTime.utc(2026),
          isCurrent: true,
        ),
      );
    }
  }

  static const _authorId = '550e8400-e29b-41d4-a716-446655440010';
  static const _deviceId = '550e8400-e29b-41d4-a716-446655440020';
  final List<AuthorProfileEntity> _authors = [];
  final DeviceProfileEntity _device = DeviceProfileEntity(
    deviceProfileId: _deviceId,
    createdAt: DateTime.utc(2026),
    isCurrent: true,
  );

  @override
  AuthorProfileEntity? get currentAuthor {
    for (final author in _authors) {
      if (author.isCurrent) return author;
    }
    return null;
  }

  @override
  DeviceProfileEntity get currentDevice => _device;

  @override
  bool get hasSharedHistory => _device.hasSharedHistory;

  @override
  AuthorProfileEntity? authorByProfileId(String authorProfileId) {
    for (final author in _authors) {
      if (author.authorProfileId == authorProfileId) return author;
    }
    return null;
  }

  @override
  AuthorProfileEntity createAuthor({
    required String nickname,
    required int colorValue,
  }) {
    for (final author in _authors) {
      author.isCurrent = false;
    }
    final author = AuthorProfileEntity(
      authorProfileId: _authors.isEmpty ? _authorId : '${_authorId}1',
      nickname: nickname.trim(),
      colorValue: colorValue,
      createdAt: DateTime.utc(2026),
      isCurrent: true,
    );
    _authors.add(author);
    return author;
  }

  @override
  List<AuthorProfileEntity> getAuthorProfiles() => List.of(_authors);

  @override
  void markSharedHistory() => _device.hasSharedHistory = true;

  @override
  RecordSource requireCurrentSource() {
    final author = currentAuthor;
    if (author == null) throw StateError('No author');
    return RecordSource(
      authorProfileId: author.authorProfileId,
      deviceProfileId: _device.deviceProfileId,
    );
  }

  @override
  void selectAuthor(String authorProfileId) {
    for (final author in _authors) {
      author.isCurrent = author.authorProfileId == authorProfileId;
    }
  }

  @override
  AuthorProfileEntity updateAuthor({
    required String authorProfileId,
    required String nickname,
    required int colorValue,
  }) {
    final author = authorByProfileId(authorProfileId);
    if (author == null) throw StateError('No author');
    author
      ..nickname = nickname.trim()
      ..colorValue = colorValue;
    return author;
  }
}
