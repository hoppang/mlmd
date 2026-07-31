import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../children/application/child_profile_repository.dart';
import '../application/quick_launch_notifier.dart';
import '../domain/quick_launch_models.dart';
import 'quick_launch_labels.dart';

class QuickLaunchRecommendationSheet extends ConsumerStatefulWidget {
  const QuickLaunchRecommendationSheet({super.key});

  @override
  ConsumerState<QuickLaunchRecommendationSheet> createState() =>
      _QuickLaunchRecommendationSheetState();
}

class _QuickLaunchRecommendationSheetState
    extends ConsumerState<QuickLaunchRecommendationSheet> {
  final Set<int> _selected = Set<int>.from(
    List.generate(quickLaunchSlotCount, (index) => index),
  );
  bool _saving = false;

  Future<void> _apply({required bool all}) async {
    final state = ref.read(quickLaunchProvider);
    final milestone = state.recommendedMilestone;
    if (milestone == null || _saving) return;
    setState(() => _saving = true);
    await ref
        .read(quickLaunchProvider.notifier)
        .applyRecommendation(selectedSlots: all ? null : _selected);
    if (mounted) Navigator.pop(context, milestone);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final state = ref.watch(quickLaunchProvider);
    final suggested = state.recommendedLayout;
    final milestone = state.recommendedMilestone;
    final childId = ref.watch(selectedChildIdProvider);
    final children = ref.watch(childProfileListProvider);
    final child = children.firstWhere(
      (item) => item.childId == childId,
      orElse: () => children.first,
    );
    if (suggested == null || milestone == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: AppInsets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.quickLaunchRecommendationTitle(
                      child.name,
                      _stageLabel(loc, milestone),
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: loc.close,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(loc.quickLaunchRecommendationDescription),
            const SizedBox(height: AppSpacing.md),
            for (var index = 0; index < quickLaunchSlotCount; index++)
              CheckboxListTile(
                key: Key('quick-launch-recommendation-$index'),
                value: _selected.contains(index),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        value == true
                            ? _selected.add(index)
                            : _selected.remove(index);
                      }),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  '${index + 1}. '
                  '${quickLaunchSlotLabel(suggested.slotAt(index), loc)}',
                ),
                subtitle: Text(
                  '${loc.quickLaunchCurrent}: '
                  '${quickLaunchSlotLabel(state.layout.slotAt(index), loc)}',
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('apply-all-quick-launch-recommendation'),
              onPressed: _saving ? null : () => _apply(all: true),
              child: Text(loc.quickLaunchApplyAll),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('apply-selected-quick-launch-recommendation'),
              onPressed: _saving || _selected.isEmpty
                  ? null
                  : () => _apply(all: false),
              child: Text(loc.quickLaunchApplySelected),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            await ref
                                .read(quickLaunchProvider.notifier)
                                .snoozeRecommendation();
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: Text(loc.quickLaunchLater),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            await ref
                                .read(quickLaunchProvider.notifier)
                                .skipRecommendation();
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: Text(loc.quickLaunchSkipStage),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String quickLaunchStageLabel(AppLocalizations loc, GrowthMilestone milestone) =>
    _stageLabel(loc, milestone);

String _stageLabel(AppLocalizations loc, GrowthMilestone milestone) =>
    switch (milestone) {
      GrowthMilestone.newborn => loc.growthStageNewborn,
      GrowthMilestone.month3 => loc.growthStageMonth3,
      GrowthMilestone.month6 => loc.growthStageMonth6,
      GrowthMilestone.year1 => loc.growthStageYear1,
    };
