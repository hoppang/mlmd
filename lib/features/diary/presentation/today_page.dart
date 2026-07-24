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

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
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
