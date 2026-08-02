import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum SttStatus { idle, listening, disabled, error }

class SttService {
  final stt.SpeechToText _speechToText;
  final TargetPlatform _platform;
  bool _isAvailable = false;
  bool _isListening = false;

  SttService({stt.SpeechToText? speechToText, TargetPlatform? platform})
    : _speechToText = speechToText ?? stt.SpeechToText(),
      _platform = platform ?? defaultTargetPlatform;

  /// Android 플랫폼에서만 공통 STT가 지원됨 (Windows 등 MVP 지원 제외)
  bool get isSupportedPlatform => _platform == TargetPlatform.android;
  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (!isSupportedPlatform) {
      _isAvailable = false;
      return false;
    }
    try {
      _isAvailable = await _speechToText.initialize(
        onError: (val) {
          _isListening = false;
        },
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
          }
        },
      );
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  Future<bool> startListening({
    required Function(String text) onResult,
    Function(String status)? onStatus,
    Function(String error)? onError,
  }) async {
    if (!isSupportedPlatform) return false;

    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      _isListening = true;
      await _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      return true;
    } catch (e) {
      _isListening = false;
      onError?.call(e.toString());
      return false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speechToText.stop();
    } catch (_) {}
    _isListening = false;
  }
}

final sttServiceProvider = Provider<SttService>((ref) {
  return SttService();
});
