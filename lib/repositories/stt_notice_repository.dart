import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SttNoticeState {
  final bool isAccepted;
  final DateTime? acceptedAt;
  final String noticeVersion;

  const SttNoticeState({
    required this.isAccepted,
    this.acceptedAt,
    this.noticeVersion = 'v1.0',
  });
}

class SttNoticeRepository {
  static const String _keyIsAccepted = 'stt_notice_accepted';
  static const String _keyAcceptedAt = 'stt_notice_accepted_at';
  static const String _keyNoticeVersion = 'stt_notice_version';
  static const String currentVersion = 'v1.0';

  final SharedPreferences? _prefs;
  SttNoticeState _state;

  SttNoticeRepository([this._prefs])
      : _state = SttNoticeState(
          isAccepted: _prefs?.getBool(_keyIsAccepted) ?? false,
          acceptedAt: _prefs?.getString(_keyAcceptedAt) != null
              ? DateTime.tryParse(_prefs!.getString(_keyAcceptedAt)!)
              : null,
          noticeVersion:
              _prefs?.getString(_keyNoticeVersion) ?? currentVersion,
        );

  SttNoticeState get state => _state;
  bool get isAccepted => _state.isAccepted;
  DateTime? get acceptedAt => _state.acceptedAt;
  String get noticeVersion => _state.noticeVersion;

  Future<void> acceptNotice({String version = currentVersion}) async {
    final now = DateTime.now();
    _state = SttNoticeState(
      isAccepted: true,
      acceptedAt: now,
      noticeVersion: version,
    );
    if (_prefs != null) {
      await _prefs.setBool(_keyIsAccepted, true);
      await _prefs.setString(_keyAcceptedAt, now.toIso8601String());
      await _prefs.setString(_keyNoticeVersion, version);
    }
  }

  Future<void> resetNotice() async {
    _state = const SttNoticeState(
      isAccepted: false,
      acceptedAt: null,
      noticeVersion: currentVersion,
    );
    if (_prefs != null) {
      await _prefs.remove(_keyIsAccepted);
      await _prefs.remove(_keyAcceptedAt);
      await _prefs.remove(_keyNoticeVersion);
    }
  }
}

final sttNoticeRepositoryProvider = Provider<SttNoticeRepository>((ref) {
  return SttNoticeRepository();
});
