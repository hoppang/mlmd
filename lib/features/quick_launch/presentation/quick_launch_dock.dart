import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/quick_launch_models.dart';
import 'quick_launch_labels.dart';

class QuickLaunchDock extends StatelessWidget {
  const QuickLaunchDock({
    required this.layout,
    required this.onSlotPressed,
    required this.onEditSlot,
    required this.onOpenAll,
    this.busySlotIndex,
    super.key,
  });

  final QuickLaunchLayout layout;
  final ValueChanged<QuickLaunchSlot> onSlotPressed;
  final ValueChanged<int> onEditSlot;
  final VoidCallback onOpenAll;
  final int? busySlotIndex;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      key: const Key('quick-launch-dock'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final slot in layout.slots)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _QuickLaunchTile(
                  slot: slot,
                  busy: busySlotIndex == slot.slotIndex,
                  onPressed: slot.hasEventType
                      ? () => onSlotPressed(slot)
                      : () => onEditSlot(slot.slotIndex),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _SystemTile(
                key: const Key('quick-launch-all'),
                label: loc.quickLaunchAll,
                icon: Icons.apps,
                onPressed: onOpenAll,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLaunchTile extends StatelessWidget {
  const _QuickLaunchTile({
    required this.slot,
    required this.busy,
    required this.onPressed,
  });

  final QuickLaunchSlot slot;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final target = slot.eventTypeId;
    if (target == null) {
      return _SystemTile(
        key: Key('quick-launch-slot-${slot.slotIndex}'),
        label: loc.quickLaunchAdd,
        icon: Icons.add,
        outlined: true,
        onPressed: onPressed,
      );
    }
    final instant = slot.executionMode == QuickLaunchExecutionMode.instant;
    final label = quickLaunchSlotLabel(slot, loc);
    final semanticLabel = instant
        ? loc.quickLaunchInstantSemantic(label)
        : loc.quickLaunchFormSemantic(label);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        key: Key('quick-launch-slot-${slot.slotIndex}'),
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: instant
                            ? colors.primaryContainer
                            : colors.surfaceContainerHighest,
                        shape: instant ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: instant
                            ? null
                            : BorderRadius.circular(12),
                        border: instant
                            ? null
                            : Border.all(color: colors.outlineVariant),
                      ),
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              quickLaunchCatalogItem(target).icon,
                              size: 21,
                              color: instant
                                  ? colors.onPrimaryContainer
                                  : colors.onSurfaceVariant,
                            ),
                    ),
                    if (!busy)
                      Positioned(
                        right: -4,
                        bottom: -3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              instant ? Icons.bolt : Icons.edit_outlined,
                              size: 12,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemTile extends StatelessWidget {
  const _SystemTile({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: outlined
                      ? Colors.transparent
                      : colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: outlined
                        ? colors.outline
                        : colors.secondaryContainer,
                    style: outlined ? BorderStyle.solid : BorderStyle.none,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: outlined
                      ? colors.onSurfaceVariant
                      : colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
