import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/presentation/adaptive_detail.dart';
import '../../../core/presentation/app_empty_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/activity_entity.dart';
import '../../../models/diary_entity.dart';
import '../../../models/duplicate_review_edge_entity.dart';
import '../../../repositories/duplicate_review_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../profiles/presentation/record_author_tag.dart';
import '../application/duplicate_review_notifier.dart';

class DuplicateReviewPage extends ConsumerWidget {
  const DuplicateReviewPage({required this.onOpenOriginal, super.key});

  final ValueChanged<DiaryEntity> onOpenOriginal;

  Future<void> _openSource(
    BuildContext context,
    WidgetRef ref,
    DiaryEntity diary,
    ActivityEntity activity,
  ) async {
    final items = ref.read(duplicateReviewListProvider);
    final showAuthor = shouldShowAuthorTags(
      {
        for (final item in items) item.firstDiary.id: item.firstDiary,
        for (final item in items) item.secondDiary.id: item.secondDiary,
      }.values,
      ref.read(profileRepositoryProvider),
    );
    final open = await showAdaptiveDetail<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: AppInsets.dialog,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      activity.type,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Chip(
                    label: Text(AppLocalizations.of(context)!.searchReadOnly),
                  ),
                ],
              ),
              Text(_timeLabel(context, activity)),
              if (showAuthor) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RecordAuthorTag(
                    authorProfileId: activity.createdByAuthorProfileId,
                    visible: true,
                  ),
                ),
              ],
              if (activity.details.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                SelectableText(activity.details.trim()),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: Key('duplicate-open-original:${activity.recordId}'),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.open_in_new),
                label: Text(AppLocalizations.of(context)!.briefingOpenOriginal),
              ),
            ],
          ),
        ),
      ),
    );
    if (open == true) onOpenOriginal(diary);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItems = ref.watch(duplicateReviewListProvider);
    final pending = allItems
        .where(
          (item) => item.edge.status == DuplicateReviewEdgeEntity.statusPending,
        )
        .toList();
    final resolved = allItems
        .where(
          (item) => item.edge.status != DuplicateReviewEdgeEntity.statusPending,
        )
        .toList();
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.duplicateReviewTitle)),
      body: AdaptiveContentFrame(
        child: allItems.isEmpty
            ? AppEmptyState(
                icon: Icons.fact_check_outlined,
                title: loc.duplicateReviewEmpty,
                description: loc.duplicateReviewEmptyHint,
              )
            : ListView(
                padding: AppInsets.page,
                children: [
                  Text(
                    loc.duplicateReviewDescription,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      loc.duplicatePendingCount(pending.length),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final item in pending)
                      _DuplicateReviewCard(
                        item: item,
                        pending: true,
                        onOpenSource: (diary, activity) =>
                            _openSource(context, ref, diary, activity),
                      ),
                  ],
                  if (resolved.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      loc.duplicateResolvedTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final item in resolved)
                      _DuplicateReviewCard(
                        item: item,
                        pending: false,
                        onOpenSource: (diary, activity) =>
                            _openSource(context, ref, diary, activity),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _DuplicateReviewCard extends ConsumerWidget {
  const _DuplicateReviewCard({
    required this.item,
    required this.pending,
    required this.onOpenSource,
  });

  final DuplicateReviewItem item;
  final bool pending;
  final void Function(DiaryEntity, ActivityEntity) onOpenSource;

  void _showSaved(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.duplicateDecisionSaved),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final notifier = ref.read(duplicateReviewListProvider.notifier);
    final edge = item.edge;
    return Card(
      key: Key('duplicate-review-card:${edge.pairKey}'),
      color: pending ? Theme.of(context).colorScheme.tertiaryContainer : null,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  pending
                      ? Icons.fact_check_outlined
                      : Icons.check_circle_outline,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    pending
                        ? loc.duplicateNeedsReview
                        : (edge.status ==
                                  DuplicateReviewEdgeEntity.statusSameEvent
                              ? loc.duplicateSameEvent
                              : loc.duplicateDistinctEvents),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              loc.duplicateExactReason,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DuplicateSourceTile(
              number: 1,
              diary: item.firstDiary,
              activity: item.firstActivity,
              onTap: () => onOpenSource(item.firstDiary, item.firstActivity),
            ),
            const SizedBox(height: AppSpacing.xs),
            _DuplicateSourceTile(
              number: 2,
              diary: item.secondDiary,
              activity: item.secondActivity,
              onTap: () => onOpenSource(item.secondDiary, item.secondActivity),
            ),
            const SizedBox(height: AppSpacing.md),
            if (pending) ...[
              FilledButton(
                key: Key('duplicate-use-source:${edge.recordAId}'),
                onPressed: () {
                  notifier.useRepresentative(edge.pairKey, edge.recordAId);
                  _showSaved(context);
                },
                child: Text(loc.duplicateUseSource(1)),
              ),
              const SizedBox(height: AppSpacing.xs),
              FilledButton.tonal(
                key: Key('duplicate-use-source:${edge.recordBId}'),
                onPressed: () {
                  notifier.useRepresentative(edge.pairKey, edge.recordBId);
                  _showSaved(context);
                },
                child: Text(loc.duplicateUseSource(2)),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                key: Key('duplicate-distinct:${edge.pairKey}'),
                onPressed: () {
                  notifier.markDistinct(edge.pairKey);
                  _showSaved(context);
                },
                child: Text(loc.duplicateMarkDistinct),
              ),
              TextButton(
                key: Key('duplicate-later:${edge.pairKey}'),
                onPressed: () {
                  notifier.defer(edge.pairKey);
                  _showSaved(context);
                },
                child: Text(loc.duplicateReviewLater),
              ),
            ] else
              OutlinedButton(
                key: Key('duplicate-change:${edge.pairKey}'),
                onPressed: () => notifier.resetDecision(edge.pairKey),
                child: Text(loc.duplicateChangeDecision),
              ),
          ],
        ),
      ),
    );
  }
}

class _DuplicateSourceTile extends StatelessWidget {
  const _DuplicateSourceTile({
    required this.number,
    required this.diary,
    required this.activity,
    required this.onTap,
  });

  final int number;
  final DiaryEntity diary;
  final ActivityEntity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: ListTile(
        key: Key('duplicate-source:${activity.recordId}'),
        leading: CircleAvatar(child: Text('$number')),
        title: Text(activity.type),
        subtitle: Text(
          [
            _timeLabel(context, activity),
            if (activity.details.trim().isNotEmpty) activity.details.trim(),
          ].join('\n'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

String _timeLabel(BuildContext context, ActivityEntity activity) {
  final loc = AppLocalizations.of(context)!;
  if (!activity.hasExactTime) return loc.eventTimeUnknown;
  return MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(activity.time));
}
