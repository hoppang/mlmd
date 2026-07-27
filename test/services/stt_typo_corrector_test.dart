import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/services/stt_typo_corrector.dart';

void main() {
  group('SttTypoCorrectorService Unit Tests', () {
    const corrector = SttTypoCorrectorService();

    test('corrects known STT typos while preserving text meaning', () {
      final input = '어재 분유 180미리 잘 먹었슴.';
      final result = corrector.correct(input);

      expect(result.hasChanges, isTrue);
      expect(result.correctedText, contains('어제'));
      expect(result.correctedText, contains('180ml'));
      expect(result.correctedText, contains('먹었음'));
      expect(result.changesSummary, isNotEmpty);
    });

    test('preserves exact numbers, times, and dosages without modification', () {
      final input = '오후 3시 20분 체온 37.8도 타이레놀 2.5ml 투약했슴.';
      final result = corrector.correct(input);

      expect(result.correctedText, contains('오후 3시 20분'));
      expect(result.correctedText, contains('37.8도'));
      expect(result.correctedText, contains('2.5ml'));
      expect(result.correctedText, contains('했음'));
    });

    test('cleans up multiple consecutive spaces and punctuation spaces', () {
      final input = '아침 수유함.  분유 160ml 먹음.잘 잤음';
      final result = corrector.correct(input);

      expect(result.hasChanges, isTrue);
      expect(result.correctedText, equals('아침 수유함. 분유 160ml 먹음. 잘 잤음'));
    });

    test('returns hasChanges false when no typos are found', () {
      final input = '오늘 하루도 아무 문제 없이 건강하게 잘 놀았다.';
      final result = corrector.correct(input);

      expect(result.hasChanges, isFalse);
      expect(result.correctedText, equals(input));
      expect(result.changesSummary, isEmpty);
    });
  });
}
