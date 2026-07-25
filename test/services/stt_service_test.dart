import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/services/stt_service.dart';

void main() {
  group('SttService Tests', () {
    test('Android platform is supported', () {
      final service = SttService(platform: TargetPlatform.android);
      expect(service.isSupportedPlatform, isTrue);
    });

    test('Non-Android platform (e.g. Windows) is not supported', () async {
      final service = SttService(platform: TargetPlatform.windows);
      expect(service.isSupportedPlatform, isFalse);

      final initialized = await service.initialize();
      expect(initialized, isFalse);

      final started = await service.startListening(onResult: (_) {});
      expect(started, isFalse);
    });
  });
}
