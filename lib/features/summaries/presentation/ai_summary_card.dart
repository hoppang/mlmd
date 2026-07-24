import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/ai_summary_entity.dart';
import '../../../repositories/ai_summary_repository.dart';
import '../domain/summary_source_snapshot.dart';

class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({
    required this.title,
    required this.actionLabel,
    required this.summary,
    required this.evidence,
    required this.freshness,
    required this.isGenerating,
    required this.hasSourceRecords,
    required this.onGenerate,
    required this.onEvidence,
    required this.onEdit,
    required this.onHide,
    required this.onRestore,
    super.key,
  });

  final String title;
  final String actionLabel;
  final AiSummaryEntity? summary;
  final List<SummaryEvidence> evidence;
  final AiSummaryFreshness? freshness;
  final bool isGenerating;
  final bool hasSourceRecords;
  final VoidCallback onGenerate;
  final VoidCallback onEvidence;
  final VoidCallback onEdit;
  final VoidCallback onHide;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final value = summary;
    if (value?.hidden == true) {
      return OutlinedButton.icon(
        key: ValueKey('${value!.summaryId}:restore'),
        onPressed: onRestore,
        icon: const Icon(Icons.visibility_outlined),
        label: Text('$title · ${loc.summaryRestore}'),
      );
    }
    if (value == null && !isGenerating) {
      return OutlinedButton.icon(
        key: ValueKey('create-${title.hashCode}'),
        onPressed: hasSourceRecords ? onGenerate : null,
        icon: const Icon(Icons.auto_awesome),
        label: Text(
          hasSourceRecords ? actionLabel : '$title · ${loc.summaryNoRecords}',
        ),
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (value?.userEdited == true)
                  Chip(
                    label: Text(loc.summaryEdited),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (isGenerating)
              Row(
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(loc.summaryGenerating)),
                ],
              )
            else if (value != null) ...[
              Text(value.displayText),
              const SizedBox(height: AppSpacing.xs),
              Text(
                loc.summaryBasis(
                  evidence.length,
                  MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(value.cutoffAt)),
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (freshness != null &&
                  freshness != AiSummaryFreshness.fresh) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  freshness == AiSummaryFreshness.newRecords
                      ? loc.summaryNewRecords
                      : loc.summarySourceChanged,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  TextButton.icon(
                    onPressed: onEvidence,
                    icon: const Icon(Icons.source_outlined),
                    label: Text(loc.summaryEvidence),
                  ),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(loc.edit),
                  ),
                  TextButton.icon(
                    onPressed: onGenerate,
                    icon: const Icon(Icons.refresh),
                    label: Text(loc.summaryRegenerate),
                  ),
                  TextButton.icon(
                    onPressed: onHide,
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: Text(loc.summaryHide),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
