import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mlmd/repositories/stt_notice_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SttNoticeRepository Tests', () {
    test('Initial state when no consent is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SttNoticeRepository(prefs);

      expect(repo.isAccepted, isFalse);
      expect(repo.acceptedAt, isNull);
      expect(repo.noticeVersion, equals('v1.0'));
    });

    test('acceptNotice updates and persists consent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SttNoticeRepository(prefs);

      await repo.acceptNotice();

      expect(repo.isAccepted, isTrue);
      expect(repo.acceptedAt, isNotNull);
      expect(prefs.getBool('stt_notice_accepted'), isTrue);
      expect(prefs.getString('stt_notice_accepted_at'), isNotNull);
    });

    test('resetNotice clears consent status', () async {
      SharedPreferences.setMockInitialValues({
        'stt_notice_accepted': true,
        'stt_notice_accepted_at': DateTime.now().toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SttNoticeRepository(prefs);

      expect(repo.isAccepted, isTrue);

      await repo.resetNotice();

      expect(repo.isAccepted, isFalse);
      expect(repo.acceptedAt, isNull);
      expect(prefs.getBool('stt_notice_accepted'), isNull);
    });
  });
}
