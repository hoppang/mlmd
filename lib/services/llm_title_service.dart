import 'package:flutter_gemma/flutter_gemma.dart';

/// 아기 중심 육아일기 제목을 LLM(Gemma)으로 자동 생성하는 서비스.
class LlmTitleService {
  static final LlmTitleService _instance = LlmTitleService._internal();
  factory LlmTitleService() => _instance;
  LlmTitleService._internal();

  /// 지정된 [languageCode]에 맞는 시스템 프롬프트를 반환합니다.
  String _getSystemPrompt(String languageCode) {
    final isKorean = languageCode == 'ko';
    final isJapanese = languageCode == 'ja';
    
    String langInstruction;
    if (isKorean) {
      langInstruction = 'ALL OUTPUT MUST BE WRITTEN IN KOREAN.';
    } else if (isJapanese) {
      langInstruction = 'ALL OUTPUT MUST BE WRITTEN IN JAPANESE.';
    } else {
      langInstruction = 'ALL OUTPUT MUST BE WRITTEN IN ENGLISH.';
    }

    return 'You are a helpful assistant that summarizes baby diaries.\n'
           '$langInstruction\n\n'
           'Rules:\n'
           '1. Read the diary carefully and extract only the most essential facts related to the baby.\n'
           '2. Remove all emotional expressions and modifiers. Create a very plain and objective title.\n'
           '3. The title MUST be a single line (around 15 characters). DO NOT include quotes, explanations, or any extra text.\n'
           '4. DO NOT use emojis or complex special characters. Use only text and basic punctuation.\n'
           '5. DO NOT hallucinate facts not present in the content.\n'
           '\n'
           'Good Examples:\n'
           '  - First successful rollover\n'
           '  - 2 naps, 1 night feeding\n'
           '  - Pediatrician visit due to fever\n'
           '  - 10 hours of uninterrupted sleep';
  }

  /// [content]를 분석해 아기 중심의 한 줄 제목을 생성합니다.
  Future<String> generate(
    String content, {
    String fallback = 'Diary',
    int maxOutputTokens = 1024,
    String languageCode = 'ko',
  }) async {
    if (content.trim().isEmpty) return fallback;

    if (!FlutterGemma.hasActiveModel()) {
      print('[LlmTitleService] 활성 모델 없음. fallback 반환.');
      return fallback;
    }

    InferenceModel? model;
    InferenceModelSession? session;

    try {
      model = await FlutterGemma.getActiveModel(maxTokens: 2048);

      session = await model.createSession(
        systemInstruction: _getSystemPrompt(languageCode),
        temperature: 0.3,
        topK: 10,
        maxOutputTokens: maxOutputTokens,
      );

      final isKorean = languageCode == 'ko';
      final isJapanese = languageCode == 'ja';
      final langTarget = isKorean ? 'KOREAN' : (isJapanese ? 'JAPANESE' : 'ENGLISH');
      final userPrompt = 
          'Summarize the following diary content into a plain, factual title of about 15 characters.\n'
          'The title MUST be written in $langTarget.\n'
          'Exclude emotional expressions and include only core facts.\n\n'
          'Diary Content:\n$content';

      await session.addQueryChunk(
        Message.text(
          text: userPrompt,
          isUser: true,
        ),
      );

      final buffer = StringBuffer();
      final stream = session.getResponseAsync();
      await for (final token in stream) {
        buffer.write(token);
      }

      final raw = buffer.toString();
      final title = _sanitizeTitle(raw);

      print('[LlmTitleService] 생성된 제목: "$title"');
      return title.isNotEmpty ? title : fallback;
    } catch (e) {
      print('[LlmTitleService] 제목 생성 실패: $e');
      return fallback;
    } finally {
      await session?.close();
      await model?.close();
    }
  }

  /// 스트리밍 토큰 분리로 인해 깨진 문자를 제거합니다.
  String _sanitizeTitle(String text) {
    final allowed = RegExp(
      r'[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7A3' // 한글
      r'\u3040-\u309F\u30A0-\u30FF'             // 일본어 (히라가나, 가타카나)
      r'\u4E00-\u9FFF\u3400-\u4DBF'             // 한자 (중국어, 일본어, 한국어 한자)
      r'\u0020-\u007E'                         // 기본 영문 및 기호 (ASCII)
      r'\u00B7'                                // 가운데 점 (·)
      r'\u3000-\u303F\uFF00-\uFFEF]',          // CJK 기호 및 전각 문자
    );
    final sanitized = text.runes
        .map((r) {
          final ch = String.fromCharCode(r);
          return allowed.hasMatch(ch) ? ch : '';
        })
        .join()
        .trim();
    return sanitized;
  }
}
