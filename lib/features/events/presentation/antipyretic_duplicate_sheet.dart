import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/antipyretic_duplicate_check.dart';
import '../domain/medication_record.dart';

enum AntipyreticDuplicateDecision { sameEvent, distinctEvent, defer }

class AntipyreticDuplicateSheet extends StatelessWidget {
  const AntipyreticDuplicateSheet({
    required this.candidate,
    required this.onDecision,
    super.key,
  });

  final AntipyreticDuplicateCandidate candidate;
  final ValueChanged<AntipyreticDuplicateDecision> onDecision;

  String _promptText(AppLocalizations loc) {
    return switch (candidate.relation) {
      AntipyreticDuplicateRelation.sameIngredient =>
        loc.antipyreticDupSameIngredientPrompt,
      AntipyreticDuplicateRelation.differentIngredient =>
        loc.antipyreticDupDiffIngredientPrompt,
      AntipyreticDuplicateRelation.unknownIngredient =>
        loc.antipyreticDupUnknownIngredientPrompt,
    };
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final newRec = candidate.newRecord;
    final oldRec = candidate.existingRecord;
    final oldAct = candidate.existingActivity;

    final newTimeStr =
        '${newRec.administeredAt.hour.toString().padLeft(2, '0')}:${newRec.administeredAt.minute.toString().padLeft(2, '0')}';
    final oldTimeStr =
        '${oldAct.time.hour.toString().padLeft(2, '0')}:${oldAct.time.minute.toString().padLeft(2, '0')}';

    final newIngStr = newRec.ingredient != null
        ? antipyreticIngredientLabel(loc, newRec.ingredient!)
        : loc.ingredientUnknown;
    final oldIngStr = oldRec.ingredient != null
        ? antipyreticIngredientLabel(loc, oldRec.ingredient!)
        : loc.ingredientUnknown;

    final newAmountStr = newRec.amount != null
        ? '${newRec.amount == newRec.amount!.toInt() ? newRec.amount!.toInt() : newRec.amount}${newRec.unit ?? "mL"}'
        : '-';
    final oldAmountStr = oldRec.amount != null
        ? '${oldRec.amount == oldRec.amount!.toInt() ? oldRec.amount!.toInt() : oldRec.amount}${oldRec.unit ?? "mL"}'
        : '-';

    final oldDeviceStr = oldAct.createdByDeviceProfileId ?? '-';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    loc.antipyreticDuplicateReviewTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Prompt message
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Text(
                _promptText(loc),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Side-by-side comparison
            Row(
              children: [
                // Existing / Previous Record
                Expanded(
                  child: Card(
                    key: const Key('antipyretic-dup-existing-card'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '이전 기록',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            oldTimeStr,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text('성분: $oldIngStr'),
                          Text('용량: $oldAmountStr'),
                          Text(
                            '기기: $oldDeviceStr',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // New Record
                Expanded(
                  child: Card(
                    key: const Key('antipyretic-dup-new-card'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '지금 기록',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            newTimeStr,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text('성분: $newIngStr'),
                          Text('용량: $newAmountStr'),
                          Text(
                            '기기: 이 기기',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Action Buttons
            ElevatedButton(
              key: const Key('antipyretic-dup-same-btn'),
              onPressed: () =>
                  onDecision(AntipyreticDuplicateDecision.sameEvent),
              child: Text(loc.antipyreticDupSameEventAction),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('antipyretic-dup-distinct-btn'),
              onPressed: () =>
                  onDecision(AntipyreticDuplicateDecision.distinctEvent),
              child: Text(loc.antipyreticDupDistinctEventAction),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('antipyretic-dup-defer-btn'),
              onPressed: () => onDecision(AntipyreticDuplicateDecision.defer),
              child: Text(loc.antipyreticDupDeferAction),
            ),
          ],
        ),
      ),
    );
  }
}
