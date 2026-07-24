import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/presentation/app_empty_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/diary_entity.dart';
import '../../../models/ai_summary_entity.dart';
import '../../../repositories/profile_repository.dart';
import '../../summaries/application/ai_summary_notifier.dart';
import '../../summaries/domain/summary_source_snapshot.dart';
import '../../summaries/presentation/ai_summary_card.dart';
import '../../profiles/presentation/record_author_tag.dart';
import '../application/diary_list_notifier.dart';

class DiaryListPage extends ConsumerStatefulWidget {
  final void Function(DiaryEntity) onEditDiary;

  const DiaryListPage({super.key, required this.onEditDiary});

  @override
  ConsumerState<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends ConsumerState<DiaryListPage> {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  bool _generatingDaily = false;
  bool _generatingWeekly = false;
  String? _autoAttemptedWeek;

  void _changeDay(int delta) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(
        _selectedDate.add(Duration(days: delta)),
      );
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDate = DateUtils.dateOnly(picked);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _weekStart(DateTime date) => DateUtils.dateOnly(
    date.subtract(Duration(days: date.weekday - DateTime.monday)),
  );

  Future<void> _generateSummary(
    SummarySourceSnapshot snapshot,
    AiSummaryEntity? existing, {
    bool automatic = false,
  }) async {
    final isDaily = snapshot.periodType == SummaryPeriodType.daily;
    if (isDaily ? _generatingDaily : _generatingWeekly) return;
    setState(() {
      if (isDaily) {
        _generatingDaily = true;
      } else {
        _generatingWeekly = true;
      }
    });

    final notifier = ref.read(aiSummaryListProvider.notifier);
    final candidate = await notifier.generateCandidate(
      snapshot,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    if (!mounted) return;
    try {
      if (candidate.status == SummaryGenerationStatus.success) {
        var replace = existing == null || automatic;
        if (!replace) {
          replace =
              await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    AppLocalizations.of(context)!.summaryPreviewTitle,
                  ),
                  content: SingleChildScrollView(child: Text(candidate.text!)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(AppLocalizations.of(context)!.summaryReplace),
                    ),
                  ],
                ),
              ) ??
              false;
        }
        if (replace) {
          notifier.saveCandidate(
            snapshot,
            candidate.text!,
            automatic: automatic,
          );
        }
      } else if (!automatic) {
        _showGenerationMessage(candidate.status);
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isDaily) {
            _generatingDaily = false;
          } else {
            _generatingWeekly = false;
          }
        });
      }
    }
  }

  void _showGenerationMessage(SummaryGenerationStatus status) {
    final loc = AppLocalizations.of(context)!;
    final message = switch (status) {
      SummaryGenerationStatus.unavailable => loc.summaryUnavailable,
      SummaryGenerationStatus.empty => loc.summaryNoRecords,
      _ => loc.summaryFailed,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editSummary(AiSummaryEntity summary) async {
    final controller = TextEditingController(text: summary.displayText);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.summaryEditTitle),
        content: TextField(
          key: const Key('ai-summary-edit-field'),
          controller: controller,
          minLines: 4,
          maxLines: 10,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: Text(AppLocalizations.of(context)!.saveRecord),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      ref.read(aiSummaryListProvider.notifier).edit(summary.id, value);
    }
  }

  Future<void> _showEvidence(AiSummaryEntity summary) async {
    final evidence = ref
        .read(aiSummaryListProvider.notifier)
        .evidenceFor(summary);
    final diaries = ref.read(diaryListProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: AppInsets.dialog,
          children: [
            Text(
              AppLocalizations.of(context)!.summaryEvidenceTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in evidence)
              ListTile(
                leading: Icon(
                  item.activityId == null ? Icons.notes : Icons.event_note,
                ),
                title: Text(item.title),
                subtitle: Text(
                  item.text.isEmpty
                      ? MaterialLocalizations.of(
                          context,
                        ).formatShortDate(item.occurredAt)
                      : item.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  final matches = diaries.where(
                    (diary) => diary.id == item.diaryId,
                  );
                  if (matches.isEmpty) return;
                  Navigator.pop(context);
                  widget.onEditDiary(matches.first);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _scheduleAutomaticWeeklySummary(
    DateTime weekStart,
    DateTime weekEnd,
    SummarySourceSnapshot snapshot,
    AiSummaryEntity? existing,
  ) {
    final today = DateUtils.dateOnly(DateTime.now());
    final key = weekStart.toIso8601String();
    if (weekEnd.isAfter(today) ||
        existing != null ||
        snapshot.evidence.isEmpty ||
        _autoAttemptedWeek == key ||
        !ref.read(weeklyAiAutoSummaryProvider) ||
        !ref.read(aiSummaryListProvider.notifier).canGenerateAutomatically) {
      return;
    }
    _autoAttemptedWeek = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _generateSummary(snapshot, null, automatic: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final diaries = ref.watch(diaryListProvider);
    final summaries = ref.watch(aiSummaryListProvider);
    ref.watch(weeklyAiAutoSummaryProvider);
    final showAuthorTags = shouldShowAuthorTags(
      diaries,
      ref.watch(profileRepositoryProvider),
    );
    final loc = AppLocalizations.of(context)!;
    final selectedDiaries =
        diaries.where((diary) => _isSameDay(diary.date, _selectedDate)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final dayStart = DateUtils.dateOnly(_selectedDate);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final weekStart = _weekStart(_selectedDate);
    final weekEnd = weekStart.add(const Duration(days: 7));
    const snapshotBuilder = SummarySourceSnapshotBuilder();
    final dailySnapshot = snapshotBuilder.build(
      diaries,
      periodType: SummaryPeriodType.daily,
      start: dayStart,
      endExclusive: dayEnd,
    );
    final weeklySnapshot = snapshotBuilder.build(
      diaries,
      periodType: SummaryPeriodType.weekly,
      start: weekStart,
      endExclusive: weekEnd,
    );
    AiSummaryEntity? dailySummary;
    AiSummaryEntity? weeklySummary;
    for (final summary in summaries) {
      if (summary.periodType == AiSummaryEntity.periodDaily &&
          _isSameDay(summary.periodStart, dayStart)) {
        dailySummary = summary;
      }
      if (summary.periodType == AiSummaryEntity.periodWeekly &&
          _isSameDay(summary.periodStart, weekStart)) {
        weeklySummary = summary;
      }
    }
    final summaryNotifier = ref.read(aiSummaryListProvider.notifier);
    final dailyFreshness = dailySummary == null
        ? null
        : summaryNotifier.freshness(dailySummary, dailySnapshot);
    final weeklyFreshness = weeklySummary == null
        ? null
        : summaryNotifier.freshness(weeklySummary, weeklySnapshot);
    final today = DateUtils.dateOnly(DateTime.now());
    final isCurrentWeek = !today.isBefore(weekStart) && today.isBefore(weekEnd);
    final latestCompletedWeekEnd = _weekStart(today);
    final latestCompletedWeekStart = latestCompletedWeekEnd.subtract(
      const Duration(days: 7),
    );
    final latestCompletedSnapshot = snapshotBuilder.build(
      diaries,
      periodType: SummaryPeriodType.weekly,
      start: latestCompletedWeekStart,
      endExclusive: latestCompletedWeekEnd,
    );
    AiSummaryEntity? latestCompletedSummary;
    for (final summary in summaries) {
      if (summary.periodType == AiSummaryEntity.periodWeekly &&
          _isSameDay(summary.periodStart, latestCompletedWeekStart)) {
        latestCompletedSummary = summary;
        break;
      }
    }
    _scheduleAutomaticWeeklySummary(
      latestCompletedWeekStart,
      latestCompletedWeekEnd,
      latestCompletedSnapshot,
      latestCompletedSummary,
    );
    _scheduleAutomaticWeeklySummary(
      weekStart,
      weekEnd,
      weeklySnapshot,
      weeklySummary,
    );

    return AdaptiveContentFrame(
      child: Column(
        children: [
          Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('date-previous-button'),
                    onPressed: () => _changeDay(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).previousPageTooltip,
                  ),
                  Expanded(
                    child: InkWell(
                      key: const Key('date-picker-button'),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      onTap: _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              MaterialLocalizations.of(
                                context,
                              ).formatFullDate(_selectedDate),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('date-next-button'),
                    onPressed: () => _changeDay(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              children: [
                AiSummaryCard(
                  title: loc.dailyAiSummary,
                  actionLabel: loc.summarizeDay,
                  summary: dailySummary,
                  evidence: dailySummary == null
                      ? dailySnapshot.evidence
                      : summaryNotifier.evidenceFor(dailySummary),
                  freshness: dailyFreshness,
                  isGenerating: _generatingDaily,
                  hasSourceRecords: dailySnapshot.evidence.isNotEmpty,
                  onGenerate: () =>
                      _generateSummary(dailySnapshot, dailySummary),
                  onEvidence: () => _showEvidence(dailySummary!),
                  onEdit: () => _editSummary(dailySummary!),
                  onHide: () =>
                      summaryNotifier.setHidden(dailySummary!.id, true),
                  onRestore: () =>
                      summaryNotifier.setHidden(dailySummary!.id, false),
                ),
                const SizedBox(height: AppSpacing.sm),
                AiSummaryCard(
                  title: loc.weeklyAiSummary,
                  actionLabel: isCurrentWeek
                      ? loc.summarizeWeekSoFar
                      : loc.summarizeWeek,
                  summary: weeklySummary,
                  evidence: weeklySummary == null
                      ? weeklySnapshot.evidence
                      : summaryNotifier.evidenceFor(weeklySummary),
                  freshness: weeklyFreshness,
                  isGenerating: _generatingWeekly,
                  hasSourceRecords: weeklySnapshot.evidence.isNotEmpty,
                  onGenerate: () =>
                      _generateSummary(weeklySnapshot, weeklySummary),
                  onEvidence: () => _showEvidence(weeklySummary!),
                  onEdit: () => _editSummary(weeklySummary!),
                  onHide: () =>
                      summaryNotifier.setHidden(weeklySummary!.id, true),
                  onRestore: () =>
                      summaryNotifier.setHidden(weeklySummary!.id, false),
                ),
                const SizedBox(height: AppSpacing.md),
                if (selectedDiaries.isEmpty)
                  SizedBox(
                    height: 220,
                    child: AppEmptyState(
                      icon: Icons.book_outlined,
                      title: loc.noDiaryTitle,
                      description: loc.noDiaryDesc,
                    ),
                  )
                else
                  for (final diary in selectedDiaries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _DiaryDateCard(
                        diary: diary,
                        showAuthorTag: showAuthorTags,
                        onTap: () => widget.onEditDiary(diary),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryDateCard extends StatelessWidget {
  const _DiaryDateCard({
    required this.diary,
    required this.showAuthorTag,
    required this.onTap,
  });

  final DiaryEntity diary;
  final bool showAuthorTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      diary.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatShortDate(diary.date),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                diary.summary.isNotEmpty ? diary.summary : diary.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (showAuthorTag) ...[
                const SizedBox(height: AppSpacing.xs),
                RecordAuthorTag(
                  authorProfileId: diary.createdByAuthorProfileId,
                  visible: true,
                ),
              ],
              if (diary.activities.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: diary.activities
                      .map(
                        (activity) => Chip(
                          label: Text(
                            '${activity.type} ${activity.details}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxs,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
