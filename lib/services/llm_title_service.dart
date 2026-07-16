import 'package:flutter_gemma/flutter_gemma.dart';

/// 아기 중심 육아일기 제목을 LLM(Qwen3)으로 자동 생성하는 서비스.
///
/// [FlutterGemma.initialize]와 모델 설치가 완료된 상태에서 사용합니다.
/// 모델이 없거나 오류 발생 시 [fallback]을 반환하고 예외를 던지지 않습니다.
class LlmTitleService {
  static final LlmTitleService _instance = LlmTitleService._internal();
  factory LlmTitleService() => _instance;
  LlmTitleService._internal();

  static const String _systemPrompt =
      '당신은 육아 일기의 핵심 내용을 요약해주는 도우미입니다. 모든 출력은 반드시 한국어(Korean)로 작성하세요.\n'
      '\n'
      '규칙:\n'
      '1. 일기 내용을 꼼꼼히 읽고, 아기와 관련된 가장 핵심적인 사건(팩트)만 파악하세요.\n'
      '2. 감정적인 표현이나 수식어를 완전히 배제하고, 매우 담백하고 객관적인 한국어 제목을 만드세요.\n'
      '3. 제목은 한 줄(15자 내외)로만 출력하고, 따옴표·설명·추가 텍스트는 절대 포함하지 마세요.\n'
      '4. 이모지나 복잡한 특수기호는 절대 사용하지 마세요. 텍스트와 기본 문장부호만 사용합니다.\n'
      '5. 내용에 없는 사실을 지어내지 마세요.\n'
      '\n'
      '좋은 예시:\n'
      '  - 첫 뒤집기 성공 (발달 이정표)\n'
      '  - 낮잠 2회, 밤수유 1회 (수면 및 수유 기록)\n'
      '  - 발열로 인한 소아과 방문 (병원 방문)\n'
      '  - 이유식 50ml 섭취 (식사 기록)\n'
      '  - 통잠 10시간 (수면 기록)';

  /// [content]를 분석해 아기 중심의 한 줄 제목을 생성합니다.
  ///
  /// - 모델 미설치 또는 오류 시 [fallback] 반환 (예외 없음)
  /// - Qwen3의 <think>...</think> 블록을 자동으로 제거합니다.
  /// - [maxOutputTokens]: thinking 블록 포함 최대 토큰 (기본 1024)
  Future<String> generate(
    String content, {
    String fallback = '육아 일기',
    int maxOutputTokens = 1024,
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
        systemInstruction: _systemPrompt,
        temperature: 0.3,
        topK: 10,
        maxOutputTokens: maxOutputTokens,
      );

      // 메시지 추가 (엣지 모델 특성상 사용자 메시지에서도 핵심 규칙 재강조)
      final userPrompt = 
          '다음 일기 내용을 15자 내외의 담백한 "한국어" 제목으로 요약하세요.\n'
          '감정 표현을 배제하고 핵심 팩트만 포함하세요.\n\n'
          '일기 내용:\n$content';

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
  ///
  /// 한국어, 영어, 일본어, 중국어 문자 및 기본 문장부호만 허용하여
  /// 깨진 멀티바이트 잔재(BPE 아티팩트 등)를 필터링합니다.
  String _sanitizeTitle(String text) {
    // 허용: 
    // - 한글 자모 및 음절
    // - 일본어 (히라가나, 가타카나)
    // - 한자 (CJK 통합 한자)
    // - 기본 라틴 (영어 및 ASCII 기호)
    // - CJK 문장부호 및 전각 문자, 가운데 점
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
