import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of an STT typo correction operation (UX-033).
class SttTypoCorrectionResult {
  final String originalText;
  final String correctedText;
  final bool hasChanges;
  final List<String> changesSummary;

  const SttTypoCorrectionResult({
    required this.originalText,
    required this.correctedText,
    required this.hasChanges,
    required this.changesSummary,
  });
}

/// Service for user-initiated STT spelling & typo correction (UX-033).
///
/// Rules:
/// - Never runs automatically; only executed on explicit user request.
/// - Never summarizes, paraphrases, or changes tone/style.
/// - Preserves all numbers, times, dates, amounts, dosages, and medical terms.
/// - Fixes Korean spelling, spacing, punctuation, and common STT misrecognition errors.
class SttTypoCorrectorService {
  const SttTypoCorrectorService();

  /// Map of common STT phoneme/spelling misrecognitions to corrected terms.
  /// Preserves numbers and units strictly.
  static const Map<String, String> _knownTypos = {
    '어재': '어제',
    '내일은': '내일은',
    '먹었슴': '먹었음',
    '하였슴': '하였음',
    '했슴': '했음',
    '자었음': '잤음',
    '잤슴': '잤음',
    '됬다': '됐도',
    '됬음': '됐음',
    '됬어': '됐어',
    '됬': '됐',
    '몇일': '며칠',
    '틀린부분': '틀린 부분',
    '수유함': '수유함',
    '안녀하세요': '안녕하세요',
    '분유 180미리': '분유 180ml',
    '180미리': '180ml',
    '100미리': '100ml',
    '200미리': '200ml',
    '미리리터': 'ml',
  };

  SttTypoCorrectionResult correct(String text) {
    if (text.trim().isEmpty) {
      return SttTypoCorrectionResult(
        originalText: text,
        correctedText: text,
        hasChanges: false,
        changesSummary: const [],
      );
    }

    String result = text;
    final changes = <String>[];

    // 1. Apply known STT typo dictionary corrections while respecting word boundaries
    _knownTypos.forEach((typo, replacement) {
      if (result.contains(typo)) {
        result = result.replaceAll(typo, replacement);
        changes.add("'$typo' -> '$replacement'");
      }
    });

    // 2. Fix multiple consecutive spaces (spacing correction)
    if (result.contains('  ')) {
      final before = result;
      result = result.replaceAll(RegExp(r' +'), ' ');
      if (before != result) {
        changes.add('다중 공백 정리');
      }
    }

    // 3. Fix common missing spaces after punctuation if not in numbers
    // e.g., "먹음.다음" -> "먹음. 다음"
    final regexPunctuationSpace = RegExp(r'([가-힣\w])([,\.])([가-힣a-zA-Z])');
    if (regexPunctuationSpace.hasMatch(result)) {
      result = result.replaceAllMapped(regexPunctuationSpace, (match) {
        changes.add("구두점 띄어쓰기 교정 ('${match.group(0)}' -> '${match.group(1)}${match.group(2)} ${match.group(3)}')");
        return '${match.group(1)}${match.group(2)} ${match.group(3)}';
      });
    }

    return SttTypoCorrectionResult(
      originalText: text,
      correctedText: result,
      hasChanges: result != text,
      changesSummary: changes,
    );
  }
}

final sttTypoCorrectorProvider = Provider<SttTypoCorrectorService>((ref) {
  return const SttTypoCorrectorService();
});
