import 'package:flutter_gemma/flutter_gemma.dart';
import '../models/activity_entity.dart';
import '../utils/logger.dart';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

/// LLM이 추출한 이벤트 한 건의 요약 (집계 형태).
class ActivitySummary {
  final String type; // 수유, 수면, 병원 등
  final String detail; // "[7, 9, 11]시", "2회", "저녁 소아과" 등
  final DateTime? occurredAt;

  const ActivitySummary({
    required this.type,
    required this.detail,
    this.occurredAt,
  });
}

/// LLM 분석 결과 전체를 담는 DTO.
class DiaryExtractionResult {
  final String title;
  final String summary;
  final List<ActivitySummary> activities;

  const DiaryExtractionResult({
    required this.title,
    required this.summary,
    required this.activities,
  });
}

// ---------------------------------------------------------------------------
// 이벤트 화이트리스트
// ---------------------------------------------------------------------------

/// LLM이 추출할 수 있는 허용된 이벤트 타입 목록 (언어별 화이트리스트)
const Map<String, List<String>> allowedEventTypes = {
  'ko': ['수유', '이유식', '수면', '건강', '투약', '병원'],
  'en': ['Feeding', 'Baby food', 'Sleep', 'Health', 'Medication', 'Hospital'],
  'ja': ['授乳', '離乳食', '睡眠', '健康', '投薬', '病院'],
};

// ---------------------------------------------------------------------------
// 일상 루틴 이벤트 제외 목록
// ---------------------------------------------------------------------------

/// 임베딩 텍스트 조합 시 제외할 일상 루틴 이벤트 타입 목록.
/// 수유·낮잠 등은 빈도가 높아 벡터 공간을 오염시킬 수 있으므로 제외합니다.
const Set<String> routineEventTypes = {
  '수유',
  '낮잠',
  '수면',
  '기저귀',
  '목욕',
  'feeding',
  'nap',
  'sleep',
  'diaper',
  'bath',
  '授乳',
  '昼寝',
  '睡眠',
  'おむつ',
  'お風呂',
};

/// [summary]와 비일상 [activities]를 합산하여 임베딩 대상 텍스트를 반환합니다.
String buildEmbeddingText(String summary, List<ActivityEntity> activities) {
  final nonRoutine = activities
      .where((a) => !routineEventTypes.contains(a.type))
      .map((a) => '${a.type}: ${a.details}')
      .join('\n');
  return nonRoutine.isEmpty ? summary : '$summary\n$nonRoutine';
}

// ---------------------------------------------------------------------------
// LlmDiaryService
// ---------------------------------------------------------------------------

/// 육아일기 자유 텍스트에서 제목·요약·이벤트 목록을 LLM으로 추출하는 서비스.
///
/// LLM 출력 형식 (separator 구분, JSON 미사용):
/// ```
/// TITLE: <제목>
/// ===
/// SUMMARY: <요약>
/// ===
/// EVENTS:
/// <타입> | <상세>
/// ...
/// ```
class LlmDiaryService {
  static final LlmDiaryService _instance = LlmDiaryService._internal();
  factory LlmDiaryService() => _instance;
  LlmDiaryService._internal();

  // -------------------------------------------------------------------------
  // 프롬프트
  // -------------------------------------------------------------------------

  String _getSystemPrompt(String languageCode) {
    final isKorean = languageCode == 'ko';
    final isJapanese = languageCode == 'ja';

    String langInstruction;
    if (isKorean) {
      langInstruction =
          'ALL OUTPUT MUST BE WRITTEN IN KOREAN.\n'
          'TONE: Use a casual, personal diary style (반말/해라체) for the summary. DO NOT use honorifics (존댓말).';
    } else if (isJapanese) {
      langInstruction =
          'ALL OUTPUT MUST BE WRITTEN IN JAPANESE.\n'
          'TONE: Use a casual, personal diary style (常体/だ・である調) for the summary. DO NOT use polite forms (敬体/です・ます調).';
    } else {
      langInstruction =
          'ALL OUTPUT MUST BE WRITTEN IN ENGLISH.\n'
          'TONE: Use a casual, personal first-person diary style for the summary.';
    }

    final allowedEvents =
        allowedEventTypes[languageCode] ?? allowedEventTypes['ko']!;
    final allowedEventsStr = allowedEvents.join(', ');

    return 'You are a helpful assistant that analyzes baby diaries.\n'
        '$langInstruction\n\n'
        'Output Format (STRICT — do NOT add any extra text or explanation):\n'
        'TITLE: <one-line title, ~15 chars, plain text only>\n'
        '===\n'
        'SUMMARY: <1-3 sentence summary of the day>\n'
        '===\n'
        'EVENTS:\n'
        '<type> | <detail>\n'
        '<type> | <detail>\n'
        '...\n\n'
        'Rules:\n'
        '1. Title: one line, ~15 characters, plain factual text, no quotes, no emojis.\n'
        '2. Summary: 1~3 sentences covering key facts of the day. Match the requested TONE.\n'
        '   - DO NOT include details in the summary that are already listed in the EVENTS section (avoid redundancy).\n'
        '   - HOWEVER, any activity NOT in the allowed EVENTS list (e.g., 산책, 놀이, 목욕) MUST be described here in the summary instead.\n'
        '3. Events: one LINE per event TYPE. Group same-type events together.\n'
        '   - STRICT RESTRICTION: You MUST ONLY extract events if they exactly match one of these allowed types: $allowedEventsStr\n'
        '   - DO NOT extract any other types of events. If it is not in the list, it is NOT an event.\n'
        '   - Example: ${allowedEvents[0]} | [7, 9, 11]시  (NOT separate lines for each feeding)\n'
        '4. DO NOT hallucinate. Only use facts from the input.\n'
        '5. Separator between sections is exactly "===".\n'
        '6. If there are no events, write "EVENTS:" with no lines below it.';
  }

  String _getUserPrompt(String content, String languageCode) {
    final isKorean = languageCode == 'ko';
    final isJapanese = languageCode == 'ja';
    final langTarget = isKorean
        ? 'KOREAN'
        : (isJapanese ? 'JAPANESE' : 'ENGLISH');
    return 'Analyze the following baby diary entry and extract the title, summary, and events.\n'
        'All output must be in $langTarget.\n\n'
        'Diary:\n$content';
  }

  // -------------------------------------------------------------------------
  // 파싱
  // -------------------------------------------------------------------------

  /// separator("===") 기반 규칙 파싱.
  /// 섹션별로 실패해도 fallback을 적용하여 최대한 복구합니다.
  DiaryExtractionResult _parse(String raw, String content) {
    // 1. "===" 으로 섹션 분리
    final sections = raw.split('===').map((s) => s.trim()).toList();

    // 2. TITLE 추출
    String title = '';
    for (final s in sections) {
      if (s.startsWith('TITLE:')) {
        title = s.replaceFirst('TITLE:', '').trim();
        break;
      }
    }

    // 3. SUMMARY 추출
    String summary = '';
    for (final s in sections) {
      if (s.startsWith('SUMMARY:')) {
        summary = s.replaceFirst('SUMMARY:', '').trim();
        break;
      }
    }

    // 4. EVENTS 파싱 ("<타입> | <상세>" 형식)
    final activities = <ActivitySummary>[];
    // 모든 언어의 허용된 이벤트 타입 집합 생성
    final allAllowedTypes = allowedEventTypes.values.expand((e) => e).toSet();

    for (final s in sections) {
      if (s.startsWith('EVENTS:')) {
        final lines = s.replaceFirst('EVENTS:', '').trim().split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final parts = trimmed.split(' | ');
          if (parts.length >= 2) {
            final type = parts[0].trim();
            // 화이트리스트에 없는 타입은 무조건 버림 (필터링)
            if (allAllowedTypes.contains(type)) {
              activities.add(
                ActivitySummary(
                  type: type,
                  detail: parts.sublist(1).join(' | ').trim(),
                ),
              );
            } else {
              logger.d('[LlmDiaryService] 화이트리스트 제외 이벤트 필터링 됨: $type');
            }
          }
        }
        break;
      }
    }

    // 5. Fallback
    if (title.isEmpty) {
      title = summary.isNotEmpty
          ? (summary.length > 20 ? summary.substring(0, 20) : summary)
          : (content.length > 20 ? content.substring(0, 20) : content);
    }
    if (summary.isEmpty) {
      summary = content.length > 100 ? content.substring(0, 100) : content;
    }

    logger.d(
      '[LlmDiaryService] parsed title="$title" summary="${summary.substring(0, summary.length.clamp(0, 30))}..." events=${activities.length}',
    );
    return DiaryExtractionResult(
      title: title,
      summary: summary,
      activities: activities,
    );
  }

  // -------------------------------------------------------------------------
  // 공개 API
  // -------------------------------------------------------------------------

  /// [content] 자유 텍스트를 분석하여 제목·요약·이벤트를 추출합니다.
  Future<DiaryExtractionResult> generate(
    String content, {
    String languageCode = 'ko',
  }) async {
    final fallback = DiaryExtractionResult(
      title: content.length > 20 ? content.substring(0, 20) : content,
      summary: content.length > 100 ? content.substring(0, 100) : content,
      activities: const [],
    );

    if (content.trim().isEmpty) return fallback;

    if (!FlutterGemma.hasActiveModel()) {
      logger.w('[LlmDiaryService] 활성 모델 없음. fallback 반환.');
      return fallback;
    }

    InferenceModel? model;
    InferenceModelSession? session;

    try {
      model = await FlutterGemma.getActiveModel(maxTokens: 2048);
      session = await model.createSession(
        systemInstruction: _getSystemPrompt(languageCode),
        temperature: 0.2,
        topK: 10,
        maxOutputTokens: 1024,
      );

      await session.addQueryChunk(
        Message.text(text: _getUserPrompt(content, languageCode), isUser: true),
      );

      final buffer = StringBuffer();
      await for (final token in session.getResponseAsync()) {
        buffer.write(token);
      }

      final raw = buffer.toString();
      logger.d('[LlmDiaryService] raw output:\n$raw');
      return _parse(raw, content);
    } catch (e) {
      logger.e('[LlmDiaryService] 분석 실패: $e');
      return fallback;
    } finally {
      await session?.close();
      await model?.close();
    }
  }
}
