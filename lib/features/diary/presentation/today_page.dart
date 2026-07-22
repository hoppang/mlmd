import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/presentation/adaptive_detail.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/activity_entity.dart';
import '../../../models/diary_entity.dart';
import '../../../models/record_draft_entity.dart';
import '../../../repositories/record_draft_repository.dart';
import '../../drafts/presentation/draft_resume_card.dart';
import '../application/diary_draft_payload.dart';
import '../application/diary_list_notifier.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({required this.onNavigateToForm, super.key});

  final void Function(DiaryEntity?, String?) onNavigateToForm;

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
    final shouldEdit = await showAdaptiveDetail<bool>(
      context: context,
      builder: (context) => _TodayRecordDetail(entry: entry),
    );
    if (shouldEdit == true && mounted) {
      widget.onNavigateToForm(entry.diary, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diaries = ref.watch(diaryListProvider);
    final drafts = ref.watch(recordDraftListProvider);
    final loc = AppLocalizations.of(context)!;
    final todayDiaries = diaries
        .where((diary) => _isToday(diary.date))
        .toList();
    final entries = _timelineEntries(todayDiaries);
    final counts = _activityCounts(todayDiaries);
    final summaries = todayDiaries
        .where((diary) => diary.summary.trim().isNotEmpty)
        .toList();

    return AdaptiveContentFrame(
      child: CustomScrollView(
        key: const Key('today-scroll-view'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
          if (counts.isNotEmpty) ...[
            _SectionTitle(title: loc.todayStatusTitle),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
          _SectionTitle(title: loc.todayTimelineTitle),
          if (entries.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 240,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timeline,
                        size: 48,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loc.noDiaryTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc.noDiaryDesc,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
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
                  onTap: () => _openEntry(entry),
                );
              },
            ),
          if (summaries.isNotEmpty) ...[
            _SectionTitle(title: loc.summaryLabel),
            SliverList.separated(
              itemCount: summaries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final diary = summaries[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
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
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.entry, required this.onTap, super.key});

  final _TodayTimelineEntry entry;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (entry.content.isNotEmpty) ...[
                      const SizedBox(height: 4),
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
  const _TodayRecordDetail({required this.entry});

  final _TodayTimelineEntry entry;

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
        padding: const EdgeInsets.all(24),
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
            if (entry.content.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(entry.content),
            ],
            if (activity != null && entry.diary.title.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                entry.diary.title.trim(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (activity == null && entry.diary.summary.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                loc.summaryLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(entry.diary.summary.trim()),
            ],
            const SizedBox(height: 24),
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
