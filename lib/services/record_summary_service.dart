import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/summaries/domain/summary_source_snapshot.dart';
import '../utils/logger.dart';

enum RecordSummaryStatus { success, unavailable, failed }

class RecordSummaryOutcome {
  const RecordSummaryOutcome._(this.status, this.text);

  const RecordSummaryOutcome.success(String text)
    : this._(RecordSummaryStatus.success, text);

  const RecordSummaryOutcome.unavailable()
    : this._(RecordSummaryStatus.unavailable, null);

  const RecordSummaryOutcome.failed()
    : this._(RecordSummaryStatus.failed, null);

  final RecordSummaryStatus status;
  final String? text;
}

abstract interface class RecordSummaryService {
  bool get isAvailable;
  bool get usesExternalService;
  String get modelVersion;

  Future<RecordSummaryOutcome> summarize(
    SummarySourceSnapshot snapshot, {
    String languageCode = 'ko',
  });
}

final recordSummaryServiceProvider = Provider<RecordSummaryService>(
  (ref) => LlmRecordSummaryService(),
);

/// 앱에 등록된 기기 내 모델로 원본 스냅샷을 짧게 문장화합니다.
class LlmRecordSummaryService implements RecordSummaryService {
  static final LlmRecordSummaryService _instance =
      LlmRecordSummaryService._internal();

  factory LlmRecordSummaryService() => _instance;
  LlmRecordSummaryService._internal();

  @override
  bool get isAvailable => FlutterGemma.hasActiveModel();

  @override
  bool get usesExternalService => false;

  @override
  String get modelVersion => 'local-gemma-record-summary-v1';

  @override
  Future<RecordSummaryOutcome> summarize(
    SummarySourceSnapshot snapshot, {
    String languageCode = 'ko',
  }) async {
    if (snapshot.evidence.isEmpty) {
      return const RecordSummaryOutcome.failed();
    }
    if (!isAvailable) {
      return const RecordSummaryOutcome.unavailable();
    }

    InferenceModel? model;
    InferenceModelSession? session;
    try {
      model = await FlutterGemma.getActiveModel(maxTokens: 4096);
      session = await model.createSession(
        systemInstruction: _systemPrompt(languageCode),
        temperature: 0.15,
        topK: 8,
        maxOutputTokens: 768,
      );
      await session.addQueryChunk(
        Message.text(text: snapshot.promptText, isUser: true),
      );
      final output = StringBuffer();
      await for (final token in session.getResponseAsync()) {
        output.write(token);
      }
      final text = output
          .toString()
          .replaceAll(RegExp(r'^(SUMMARY|요약|まとめ)\s*:\s*'), '')
          .trim();
      if (text.isEmpty) return const RecordSummaryOutcome.failed();
      return RecordSummaryOutcome.success(text);
    } catch (error, stackTrace) {
      logger.e(
        'Record summary generation failed.',
        error: error,
        stackTrace: stackTrace,
      );
      return const RecordSummaryOutcome.failed();
    } finally {
      await session?.close();
      await model?.close();
    }
  }

  String _systemPrompt(String languageCode) {
    final language = switch (languageCode) {
      'ja' => 'JAPANESE',
      'en' => 'ENGLISH',
      _ => 'KOREAN',
    };
    return '''
You turn a supplied baby-care record snapshot into a short factual recap.
Write all output in $language.
Use only facts in SOURCE RECORDS and CODE-CALCULATED COUNTS.
Never calculate or infer counts, averages, trends, diagnoses, causes, or normality.
Do not give medical advice. Do not invent missing activity or say that no record means zero.
Write 2 to 4 concise sentences as plain text with no heading or bullet list.
Important health values such as temperature and medication must remain exact.
''';
  }
}
