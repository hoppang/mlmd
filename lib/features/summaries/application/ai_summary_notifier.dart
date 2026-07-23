import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ai_summary_entity.dart';
import '../../../providers/locale_provider.dart';
import '../../../repositories/ai_summary_repository.dart';
import '../../../services/record_summary_service.dart';
import '../domain/summary_source_snapshot.dart';

enum SummaryGenerationStatus { success, unavailable, failed, empty }

class SummaryGenerationCandidate {
  const SummaryGenerationCandidate({required this.status, this.text});

  final SummaryGenerationStatus status;
  final String? text;
}

class AiSummaryNotifier extends Notifier<List<AiSummaryEntity>> {
  @override
  List<AiSummaryEntity> build() {
    return ref.watch(aiSummaryRepositoryProvider).getAll();
  }

  bool get isAvailable => ref.read(recordSummaryServiceProvider).isAvailable;

  bool get canGenerateAutomatically {
    final service = ref.read(recordSummaryServiceProvider);
    return service.isAvailable && !service.usesExternalService;
  }

  AiSummaryEntity? summaryFor(
    SummaryPeriodType periodType,
    DateTime periodStart,
  ) => ref
      .read(aiSummaryRepositoryProvider)
      .getForPeriod(periodType, periodStart);

  AiSummaryFreshness freshness(
    AiSummaryEntity summary,
    SummarySourceSnapshot snapshot,
  ) => ref.read(aiSummaryRepositoryProvider).freshness(summary, snapshot);

  List<SummaryEvidence> evidenceFor(AiSummaryEntity summary) =>
      ref.read(aiSummaryRepositoryProvider).evidenceFor(summary);

  Future<SummaryGenerationCandidate> generateCandidate(
    SummarySourceSnapshot snapshot, {
    required String languageCode,
  }) async {
    if (snapshot.evidence.isEmpty) {
      return const SummaryGenerationCandidate(
        status: SummaryGenerationStatus.empty,
      );
    }
    final outcome = await ref
        .read(recordSummaryServiceProvider)
        .summarize(snapshot, languageCode: languageCode);
    return switch (outcome.status) {
      RecordSummaryStatus.success => SummaryGenerationCandidate(
        status: SummaryGenerationStatus.success,
        text: outcome.text,
      ),
      RecordSummaryStatus.unavailable => const SummaryGenerationCandidate(
        status: SummaryGenerationStatus.unavailable,
      ),
      RecordSummaryStatus.failed => const SummaryGenerationCandidate(
        status: SummaryGenerationStatus.failed,
      ),
    };
  }

  AiSummaryEntity saveCandidate(
    SummarySourceSnapshot snapshot,
    String text, {
    required bool automatic,
  }) {
    final service = ref.read(recordSummaryServiceProvider);
    final saved = ref
        .read(aiSummaryRepositoryProvider)
        .saveGenerated(
          snapshot,
          text,
          automatic: automatic,
          modelVersion: service.modelVersion,
        );
    _reload();
    return saved;
  }

  Future<SummaryGenerationStatus> generateAndSave(
    SummarySourceSnapshot snapshot, {
    required String languageCode,
    required bool automatic,
  }) async {
    final candidate = await generateCandidate(
      snapshot,
      languageCode: languageCode,
    );
    if (candidate.status == SummaryGenerationStatus.success) {
      saveCandidate(snapshot, candidate.text!, automatic: automatic);
    }
    return candidate.status;
  }

  void edit(int id, String text) {
    ref.read(aiSummaryRepositoryProvider).edit(id, text);
    _reload();
  }

  void setHidden(int id, bool hidden) {
    ref.read(aiSummaryRepositoryProvider).setHidden(id, hidden);
    _reload();
  }

  void _reload() {
    state = ref.read(aiSummaryRepositoryProvider).getAll();
  }
}

final aiSummaryListProvider =
    NotifierProvider<AiSummaryNotifier, List<AiSummaryEntity>>(
      AiSummaryNotifier.new,
      dependencies: [aiSummaryRepositoryProvider, recordSummaryServiceProvider],
    );

class WeeklyAiAutoSummaryNotifier extends Notifier<bool> {
  static const _key = 'weekly_ai_auto_summary';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
    state = enabled;
  }
}

final weeklyAiAutoSummaryProvider =
    NotifierProvider<WeeklyAiAutoSummaryNotifier, bool>(
      WeeklyAiAutoSummaryNotifier.new,
      dependencies: [sharedPreferencesProvider],
    );
