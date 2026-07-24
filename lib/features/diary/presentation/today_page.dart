import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/presentation/adaptive_detail.dart';
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
import '../../events/domain/sleep_record.dart';
import '../../events/presentation/sleep_event_form.dart';
import '../../../models/duplicate_review_edge_entity.dart';
import '../../profiles/presentation/record_author_tag.dart';
import '../application/diary_draft_payload.dart';
import '../application/diary_list_notifier.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({
    required this.onNavigateToForm,
    required this.onOpenDuplicateReviews,
    super.key,
  });

  final void Function(DiaryEntity?, String?) onNavigateToForm;
  final VoidCallback onOpenDuplicateReviews;

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

  Map<String, int> _activityCounts(List<DiaryEntity> todayDiaries) {
    final counts = <String, int>{};
    for (final diary in todayDiaries) {
      for (final activity in diary.activities) {
        final sleep = SleepRecord.decode(activity.structuredDataJson ?? '');
        if (sleep?.status == SleepRecordStatus.active) continue;
        final type = activity.type.trim();
        if (type.isNotEmpty) {
          counts.update(type, (count) => count + 1, ifAbsent: () => 1);
        }
      }
    }
    return Map.fromEntries(
      counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  Future<void> _openEntry(_TodayTimelineEntry entry) async {
    final showAuthorTags = shouldShowAuthorTags(
      ref.read(diaryListProvider),
      ref.read(profileRepositoryProvider),
    );
    final shouldEdit = await showAdaptiveDetail<bool>(
      context: context,
      builder: (context) =>
          _TodayRecordDetail(entry: entry, showAuthorTag: showAuthorTags),
    );
    if (shouldEdit == true && mounted) {
      widget.onNavigateToForm(entry.diary, null);
    }
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(loc.sleepEnded),
          action: recordId == null
              ? null
              : SnackBarAction(
                  label: loc.undo,
                  onPressed: () => ref
                      .read(diaryListProvider.notifier)
                      .reopenSleep(recordId),
                ),
        ),
      );
  }

  Future<void> _editActiveSleepStart(ActivityEntity activity) async {
    final record = SleepRecord.decode(activity.structuredDataJson ?? '');
    final recordId = activity.recordId;
    if (record == null ||
        record.status != SleepRecordStatus.active ||
        recordId == null) {
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: record.startedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(record.startedAt),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (value.isAfter(DateTime.now())) return;
    await ref
        .read(diaryListProvider.notifier)
        .editActiveSleepStart(recordId, value);
  }

  Future<void> _editSleepMarkers(ActivityEntity activity) async {
    final record = SleepRecord.decode(activity.structuredDataJson ?? '');
    final recordId = activity.recordId;
    if (record == null ||
        record.status != SleepRecordStatus.completed ||
        recordId == null) {
      return;
    }
    final selected = record.markers.toSet();
    final result = await showDialog<List<SleepRecordMarker>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final loc = AppLocalizations.of(context)!;
          return AlertDialog(
            title: Text(loc.sleepMarkersTitle),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.sleepMarkersHint),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final marker in SleepRecordMarker.values)
                        FilterChip(
                          key: Key('edit-sleep-marker-${marker.name}'),
                          label: Text(sleepMarkerLabel(loc, marker)),
                          selected: selected.contains(marker),
                          onSelected: (value) => setDialogState(() {
                            value
                                ? selected.add(marker)
                                : selected.remove(marker);
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(loc.cancel),
              ),
              FilledButton(
                key: const Key('save-sleep-markers'),
                onPressed: () => Navigator.pop(
                  dialogContext,
                  selected.toList(growable: false),
                ),
                child: Text(loc.saveRecord),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    final updated = SleepRecord(
      status: record.status,
      kind: record.kind,
      source: record.source,
      startedAt: record.startedAt,
      endedAt: record.endedAt,
      markers: result,
      endedByAuthorProfileId: record.endedByAuthorProfileId,
      endedByDeviceProfileId: record.endedByDeviceProfileId,
      note: record.note,
    );
    await ref
        .read(diaryListProvider.notifier)
        .updateSleepMarkers(
          recordId,
          result,
          details: sleepRecordDetails(AppLocalizations.of(context)!, updated),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.sleepMarkersSaved)),
    );
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
    final activeSleeps = activeSleepActivities(diaries);
    final todayDiaries = diaries
        .where((diary) => _isToday(diary.date))
        .toList();
    final entries = _timelineEntries(todayDiaries);
    final counts = _activityCounts(todayDiaries);
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
                  children: counts.entries
                      .map(
                        (entry) => Chip(
                          avatar: const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: Text('${entry.key} · ${entry.value}'),
                          visualDensity: VisualDensity.compact,
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
                  onAddSleepMarkers:
                      entry.sleepRecord?.status == SleepRecordStatus.completed
                      ? () => _editSleepMarkers(entry.activity!)
                      : null,
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
  SleepRecord? get sleepRecord =>
      SleepRecord.decode(activity?.structuredDataJson ?? '');
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.showAuthorTag,
    required this.onTap,
    this.onAddSleepMarkers,
    super.key,
  });

  final _TodayTimelineEntry entry;
  final bool showAuthorTag;
  final VoidCallback onTap;
  final VoidCallback? onAddSleepMarkers;

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
          '${entry.title}, $timeLabel, ${loc.searchReadOnly}, '
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
                    if (onAddSleepMarkers != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: Key(
                            'add-sleep-markers-${entry.activity!.recordId ?? entry.activity!.id}',
                          ),
                          onPressed: onAddSleepMarkers,
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(loc.addSleepMarkers),
                        ),
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

class _TodayRecordDetail extends StatelessWidget {
  const _TodayRecordDetail({required this.entry, required this.showAuthorTag});

  final _TodayTimelineEntry entry;
  final bool showAuthorTag;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final activity = entry.activity;
    final timeLabel = entry.hasExactTime
        ? MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(entry.occurredAt))
        : loc.eventTimeUnknown;

    return SafeArea(
      child: SingleChildScrollView(
        padding: AppInsets.dialog,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(loc.searchReadOnly),
                ),
              ],
            ),
            Text(
              timeLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (showAuthorTag) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: RecordAuthorTag(
                  authorProfileId: entry.authorProfileId,
                  visible: true,
                ),
              ),
            ],
            if (entry.content.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(entry.content),
            ],
            if (activity != null && entry.diary.title.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                entry.diary.title.trim(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (activity == null && entry.diary.summary.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                loc.summaryLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(entry.diary.summary.trim()),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('today-record-edit-button'),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.edit_outlined),
              label: Text(loc.edit),
            ),
          ],
        ),
      ),
    );
  }
}
