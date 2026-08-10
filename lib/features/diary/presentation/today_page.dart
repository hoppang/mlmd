import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/presentation/app_empty_state.dart';
import '../../../core/presentation/app_section_header.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/activity_entity.dart';
import '../../../models/diary_entity.dart';
import '../../../models/record_draft_entity.dart';
import '../../../repositories/record_draft_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../drafts/presentation/draft_resume_card.dart';
import '../../duplicate_review/application/duplicate_review_notifier.dart';
import '../../events/domain/accident_injury_record.dart';
import '../../events/domain/care_procedure_record.dart';
import '../../events/domain/elimination_record.dart';
import '../../events/domain/event_catalog.dart';
import '../../events/domain/medical_guidance.dart';
import '../../events/domain/medication_record.dart';
import '../../events/domain/sleep_record.dart';
import '../../events/domain/symptom_record.dart';
import '../../events/presentation/medical_guidance_widgets.dart';
import '../../events/presentation/sleep_date_time_picker.dart';
import '../../events/presentation/sleep_event_form.dart';
import '../../../models/duplicate_review_edge_entity.dart';
import '../../profiles/presentation/record_author_tag.dart';
import '../../quick_launch/application/quick_launch_notifier.dart';
import '../../quick_launch/presentation/quick_launch_dock.dart';
import '../application/diary_draft_payload.dart';
import '../application/diary_list_notifier.dart';
import '../application/top_undo_notifier.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({
    required this.onNavigateToForm,
    required this.onEditActivity,
    required this.onOpenDuplicateReviews,
    required this.onQuickLaunch,
    required this.onEditQuickLaunch,
    required this.onOpenAllRecords,
    required this.onReviewQuickLaunchRecommendation,
    this.busyQuickLaunchSlot,
    super.key,
  });

  final void Function(DiaryEntity?, String?) onNavigateToForm;
  final void Function(
    DiaryEntity diary,
    ActivityEntity activity,
    Widget? editContext,
  )
  onEditActivity;
  final VoidCallback onOpenDuplicateReviews;
  final QuickLaunchSlotCallback onQuickLaunch;
  final ValueChanged<int> onEditQuickLaunch;
  final VoidCallback onOpenAllRecords;
  final VoidCallback onReviewQuickLaunchRecommendation;
  final int? busyQuickLaunchSlot;

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  late DateTime _today;
  Timer? _midnightTimer;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _scheduleMidnightRefresh();
    _elapsedTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(tomorrow.difference(now), () {
      if (!mounted) return;
      setState(() => _today = DateTime.now());
      _scheduleMidnightRefresh();
    });
  }

  String _draftDescription(BuildContext context, RecordDraftEntity draft) {
    var label = AppLocalizations.of(context)!.newDiary;
    try {
      final payload = DiaryDraftPayload.decode(draft.fieldPayloadJson);
      final candidate = [payload.title, payload.summary, payload.rawText]
          .map((value) => value.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (candidate.isNotEmpty) label = candidate.split('\n').first;
    } on FormatException {
      // 손상된 초안도 목록에서 숨기지 않는다.
    }
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(draft.lastSavedAt));
    return '$label · $time';
  }

  void _openDraft(RecordDraftEntity draft, List<DiaryEntity> diaries) {
    DiaryEntity? diary;
    if (draft.targetRecordId != null) {
      for (final candidate in diaries) {
        if (candidate.recordId == draft.targetRecordId ||
            'local:${candidate.id}' == draft.targetRecordId) {
          diary = candidate;
          break;
        }
      }
      if (diary == null) return;
    }
    widget.onNavigateToForm(diary, draft.draftId);
  }

  bool _isToday(DateTime value) {
    return value.year == _today.year &&
        value.month == _today.month &&
        value.day == _today.day;
  }

  List<_TodayTimelineEntry> _timelineEntries(List<DiaryEntity> todayDiaries) {
    final entries = <_TodayTimelineEntry>[];
    for (final diary in todayDiaries) {
      if (diary.content.trim().isNotEmpty) {
        entries.add(_TodayTimelineEntry(diary: diary));
      }
      for (final activity in diary.activities) {
        final sleep = SleepRecord.decode(activity.structuredDataJson ?? '');
        if (sleep?.status == SleepRecordStatus.active) continue;
        entries.add(_TodayTimelineEntry(diary: diary, activity: activity));
      }
    }
    entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return entries;
  }

  List<_TodayStatusGroup> _activityCounts(
    List<DiaryEntity> todayDiaries,
    List<DiaryEntity> allDiaries,
    AppLocalizations loc,
  ) {
    final now = DateTime.now();
    final latestAntipyreticDoses = <AntipyreticIngredient, DateTime>{};
    for (final diary in allDiaries) {
      for (final activity in diary.activities) {
        final medication = MedicationRecord.decode(
          activity.structuredDataJson ?? '',
        );
        final ingredient = medication?.ingredient;
        if (medication?.category != MedicationCategory.antipyretic ||
            (ingredient != AntipyreticIngredient.acetaminophen &&
                ingredient != AntipyreticIngredient.ibuprofen) ||
            medication!.administeredAt.isAfter(now)) {
          continue;
        }
        final previous = latestAntipyreticDoses[ingredient];
        if (previous == null || medication.administeredAt.isAfter(previous)) {
          latestAntipyreticDoses[ingredient!] = medication.administeredAt;
        }
      }
    }

    final counts = <String, _TodayStatusGroupBuilder>{};
    for (final diary in todayDiaries) {
      for (final activity in diary.activities) {
        final sleep = SleepRecord.decode(activity.structuredDataJson ?? '');
        if (sleep?.status == SleepRecordStatus.active) continue;
        final type = activity.type.trim();
        if (type.isEmpty) continue;

        final catalogItem =
            eventCatalogItemForActivity(activity) ??
            eventCatalog.where((item) => item.matches(type)).firstOrNull;
        final key = catalogItem == null ? 'legacy:$type' : catalogItem.id.name;
        final builder = counts.putIfAbsent(
          key,
          () => _TodayStatusGroupBuilder(
            key: key,
            label: catalogItem?.label(loc) ?? type,
            icon: catalogItem?.icon ?? Icons.check_circle_outline,
          ),
        );
        builder.total += 1;
        final endedAt = sleep?.endedAt;
        if (sleep?.status == SleepRecordStatus.completed && endedAt != null) {
          final duration = endedAt.difference(sleep!.startedAt);
          if (!duration.isNegative) {
            builder.hasCompletedSleep = true;
            builder.completedSleepDuration += duration;
          }
        }

        final subtype = _activitySubtype(activity, catalogItem, loc);
        if (subtype != null) {
          builder.subtypeCounts.update(
            subtype,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }
    counts[EventTypeId.medication.name]?.latestAntipyreticDoses.addAll(
      latestAntipyreticDoses,
    );
    return counts.values.map((builder) => builder.build(loc, now)).toList()
      ..sort((a, b) => a.label.compareTo(b.label));
  }

  String? _activitySubtype(
    ActivityEntity activity,
    EventCatalogItem? catalogItem,
    AppLocalizations loc,
  ) {
    if (catalogItem == null) return null;
    final encoded = activity.structuredDataJson ?? '';

    final medication = MedicationRecord.decode(encoded);
    if (medication != null) {
      return medicationCategoryLabel(loc, medication.category);
    }
    final symptom = SymptomRecord.decode(encoded);
    if (symptom != null && symptom.symptomName.trim().isNotEmpty) {
      return symptom.symptomName.trim();
    }
    final procedure = CareProcedureRecord.decode(encoded);
    if (procedure != null) {
      return procedure.procedureType.label(loc);
    }
    final accident = AccidentInjuryRecord.decode(encoded);
    if (accident != null) {
      final customType = accident.customType?.trim();
      return customType?.isNotEmpty == true
          ? customType
          : accident.injuryType.label(loc);
    }
    final elimination = EliminationRecord.decode(encoded);
    if (elimination != null) {
      return switch (elimination.kind) {
        EliminationKind.urine => loc.eliminationUrinePreset,
        EliminationKind.stool => loc.eliminationStoolPreset,
        EliminationKind.both => loc.eliminationBothPreset,
      };
    }

    final storedType = activity.type.trim();
    if (!catalogItem.matches(storedType) &&
        storedType != catalogItem.label(loc)) {
      return storedType;
    }
    return null;
  }

  void _openEntry(_TodayTimelineEntry entry) {
    final activity = entry.activity;
    if (activity == null) {
      widget.onNavigateToForm(entry.diary, null);
      return;
    }
    final guidance = evaluateMedicalGuidance(activity);
    final editContext = guidance.requiresAttention
        ? Card(
            child: ExpansionTile(
              key: const Key('record-edit-medical-guidance'),
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(
                AppLocalizations.of(context)!.medicalAttentionRequired,
              ),
              initiallyExpanded: false,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: MedicalGuidanceSection(activity: activity),
                ),
              ],
            ),
          )
        : null;
    widget.onEditActivity(entry.diary, activity, editContext);
  }

  Future<void> _completeSleep(ActivityEntity activity) async {
    final record = SleepRecord.decode(activity.structuredDataJson ?? '');
    if (record == null || record.status != SleepRecordStatus.active) return;
    final endedAt = DateTime.now();
    final completed = SleepRecord(
      status: SleepRecordStatus.completed,
      kind: suggestSleepKind(record.startedAt, endedAt),
      source: SleepRecordSource.suggested,
      startedAt: record.startedAt,
      endedAt: endedAt,
      markers: record.markers,
      note: record.note,
    );
    await ref
        .read(diaryListProvider.notifier)
        .completeSleep(
          activity,
          endedAt: endedAt,
          details: sleepRecordDetails(AppLocalizations.of(context)!, completed),
        );
    if (!mounted) return;
    final recordId = activity.recordId;
    final loc = AppLocalizations.of(context)!;
    if (recordId != null) {
      ref
          .read(topUndoProvider.notifier)
          .arm(
            () => ref.read(diaryListProvider.notifier).reopenSleep(recordId),
          );
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(loc.sleepEnded)));
  }

  Future<void> _editActiveSleepStart(ActivityEntity activity) async {
    final record = SleepRecord.decode(activity.structuredDataJson ?? '');
    final recordId = activity.recordId;
    if (record == null ||
        record.status != SleepRecordStatus.active ||
        recordId == null) {
      return;
    }
    final value = await showSleepDateTimePicker(
      context: context,
      title: AppLocalizations.of(context)!.editStartTime,
      initialValue: record.startedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (value == null || !mounted) return;
    if (value.isAfter(DateTime.now())) return;
    await ref
        .read(diaryListProvider.notifier)
        .editActiveSleepStart(recordId, value);
  }

  @override
  Widget build(BuildContext context) {
    final diaries = ref.watch(diaryListProvider);
    final drafts = ref.watch(recordDraftListProvider);
    final pendingDuplicateCount = ref
        .watch(duplicateReviewListProvider)
        .where(
          (item) => item.edge.status == DuplicateReviewEdgeEntity.statusPending,
        )
        .length;
    final loc = AppLocalizations.of(context)!;
    final quickLaunch = ref.watch(quickLaunchProvider);
    final activeSleeps = activeSleepActivities(diaries);
    final todayDiaries = diaries
        .where((diary) => _isToday(diary.date))
        .toList();
    final entries = _timelineEntries(todayDiaries);
    final counts = _activityCounts(todayDiaries, diaries, loc);
    final showAuthorTags = shouldShowAuthorTags(
      diaries,
      ref.watch(profileRepositoryProvider),
    );
    final summaries = todayDiaries
        .where((diary) => diary.summary.trim().isNotEmpty)
        .toList();

    return AdaptiveContentFrame(
      child: CustomScrollView(
        key: const Key('today-scroll-view'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                MaterialLocalizations.of(context).formatFullDate(_today),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: QuickLaunchDock(
              layout: quickLaunch.layout,
              busySlotIndex: widget.busyQuickLaunchSlot,
              onSlotPressed: widget.onQuickLaunch,
              onEditSlot: widget.onEditQuickLaunch,
              onOpenAll: widget.onOpenAllRecords,
            ),
          ),
          if (quickLaunch.hasRecommendation)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Card(
                  key: const Key('quick-launch-recommendation-card'),
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(loc.quickLaunchViewChanges),
                    subtitle: Text(loc.quickLaunchRecommendationDescription),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onReviewQuickLaunchRecommendation,
                  ),
                ),
              ),
            ),
          if (drafts.isNotEmpty)
            SliverToBoxAdapter(
              child: DraftResumeCard(
                count: drafts.length,
                description: _draftDescription(context, drafts.first),
                onContinue: () => _openDraft(drafts.first, diaries),
                onStartNew: () => widget.onNavigateToForm(null, null),
              ),
            ),
          if (pendingDuplicateCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Card(
                  key: const Key('duplicate-review-banner'),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.fact_check_outlined),
                    title: Text(
                      loc.duplicateReviewBanner(pendingDuplicateCount),
                    ),
                    subtitle: Text(loc.duplicateReviewBannerHint),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onOpenDuplicateReviews,
                  ),
                ),
              ),
            ),
          if (activeSleeps.isNotEmpty) ...[
            SliverAppSectionHeader(title: loc.sleepEvent),
            SliverList.separated(
              itemCount: activeSleeps.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final activity = activeSleeps[index];
                return _ActiveSleepCard(
                  activity: activity,
                  onEnd: () => _completeSleep(activity),
                  onEditStart: () => _editActiveSleepStart(activity),
                );
              },
            ),
          ],
          if (counts.isNotEmpty) ...[
            SliverAppSectionHeader(title: loc.todayStatusTitle),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: counts
                      .map(
                        (group) => _TodayStatusBadge(
                          key: ValueKey('today-status-${group.key}'),
                          group: group,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
          SliverAppSectionHeader(title: loc.todayTimelineTitle),
          if (entries.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 240,
                child: AppEmptyState(
                  icon: Icons.timeline,
                  title: loc.noDiaryTitle,
                  description: loc.noDiaryDesc,
                  iconColor: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _TimelineItem(
                  key: ValueKey(entry.resultKey),
                  entry: entry,
                  showAuthorTag: showAuthorTags,
                  onTap: () => _openEntry(entry),
                );
              },
            ),
          if (summaries.isNotEmpty) ...[
            SliverAppSectionHeader(title: loc.summaryLabel),
            SliverList.separated(
              itemCount: summaries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final diary = summaries[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    elevation: 0,
                    child: Padding(
                      padding: AppInsets.card,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(diary.summary.trim())),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}

class _TodayStatusBadge extends StatelessWidget {
  const _TodayStatusBadge({required this.group, super.key});

  final _TodayStatusGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: IntrinsicWidth(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: colors.primaryContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      group.icon,
                      size: 15,
                      color: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${group.label} ${group.total}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (group.details.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 7,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final detail in group.details)
                        Text(
                          detail.text,
                          key: ValueKey(detail.key),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayStatusGroupBuilder {
  _TodayStatusGroupBuilder({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
  int total = 0;
  final Map<String, int> subtypeCounts = {};
  bool hasCompletedSleep = false;
  Duration completedSleepDuration = Duration.zero;
  final Map<AntipyreticIngredient, DateTime> latestAntipyreticDoses = {};

  _TodayStatusGroup build(AppLocalizations loc, DateTime now) {
    final sortedSubtypes = Map.fromEntries(
      subtypeCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final details = <_TodayStatusDetail>[];
    if (sortedSubtypes.length > 1) {
      details.add(
        _TodayStatusDetail(
          key: 'today-status-subtypes-$key',
          text: sortedSubtypes.entries
              .map((entry) => '${entry.key} ${entry.value}')
              .join('   '),
        ),
      );
    }
    if (hasCompletedSleep) {
      details.add(
        _TodayStatusDetail(
          key: 'today-status-sleep-total-$key',
          text: loc.todayStatusSleepTotal(
            formatSleepDuration(loc, completedSleepDuration),
          ),
        ),
      );
    }
    for (final ingredient in const [
      AntipyreticIngredient.acetaminophen,
      AntipyreticIngredient.ibuprofen,
    ]) {
      final administeredAt = latestAntipyreticDoses[ingredient];
      if (administeredAt == null) continue;
      details.add(
        _TodayStatusDetail(
          key: 'today-status-last-dose-${ingredient.name}-$key',
          text: loc.todayStatusLastDoseElapsed(
            antipyreticIngredientLabel(loc, ingredient),
            formatSleepDuration(loc, now.difference(administeredAt)),
          ),
        ),
      );
    }
    return _TodayStatusGroup(
      key: key,
      label: label,
      icon: icon,
      total: total,
      details: details,
    );
  }
}

class _TodayStatusDetail {
  const _TodayStatusDetail({required this.key, required this.text});

  final String key;
  final String text;
}

class _TodayStatusGroup {
  const _TodayStatusGroup({
    required this.key,
    required this.label,
    required this.icon,
    required this.total,
    required this.details,
  });

  final String key;
  final String label;
  final IconData icon;
  final int total;
  final List<_TodayStatusDetail> details;
}

class _ActiveSleepCard extends StatelessWidget {
  const _ActiveSleepCard({
    required this.activity,
    required this.onEnd,
    required this.onEditStart,
  });

  final ActivityEntity activity;
  final VoidCallback onEnd;
  final VoidCallback onEditStart;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final record = SleepRecord.decode(activity.structuredDataJson ?? '');
    if (record == null) return const SizedBox.shrink();
    final elapsed = DateTime.now().difference(record.startedAt);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(record.startedAt));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        key: Key('active-sleep-${activity.recordId ?? activity.id}'),
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc.sleepInProgress(formatSleepDuration(loc, elapsed)),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                loc.sleepSince(time),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  TextButton.icon(
                    key: const Key('edit-active-sleep-start'),
                    onPressed: onEditStart,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(loc.editStartTime),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('end-active-sleep'),
                    onPressed: onEnd,
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: Text(loc.wakeUp),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayTimelineEntry {
  const _TodayTimelineEntry({required this.diary, this.activity});

  final DiaryEntity diary;
  final ActivityEntity? activity;

  DateTime get occurredAt => activity?.time ?? diary.date;
  bool get hasExactTime => activity?.hasExactTime ?? true;
  String get title => activity?.type.trim().isNotEmpty == true
      ? activity!.type.trim()
      : diary.title.trim();
  String get content =>
      activity == null ? diary.content.trim() : activity!.details.trim();
  String get resultKey => activity == null
      ? 'today-memo:${diary.id}'
      : 'today-activity:${activity!.id}';
  String? get authorProfileId =>
      activity?.createdByAuthorProfileId ?? diary.createdByAuthorProfileId;
  bool get requiresMedicalAttention =>
      evaluateMedicalGuidance(activity).requiresAttention;
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.showAuthorTag,
    required this.onTap,
    super.key,
  });

  final _TodayTimelineEntry entry;
  final bool showAuthorTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final timeLabel = entry.hasExactTime
        ? MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(entry.occurredAt))
        : loc.eventTimeUnknown;

    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${entry.title}, $timeLabel, ${loc.edit}, '
          '${entry.requiresMedicalAttention ? '${loc.medicalAttentionRequired}, ' : ''}'
          '${loc.searchResultDetail}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                child: Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                entry.activity == null ? Icons.notes : Icons.event_note,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (showAuthorTag) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      RecordAuthorTag(
                        authorProfileId: entry.authorProfileId,
                        visible: true,
                      ),
                    ],
                    if (entry.content.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        entry.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (entry.requiresMedicalAttention) ...[
                      const SizedBox(height: AppSpacing.xs),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: MedicalAttentionLabel(),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
