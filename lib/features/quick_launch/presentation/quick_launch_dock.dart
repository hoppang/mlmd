import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/quick_launch_models.dart';
import 'quick_launch_labels.dart';

typedef QuickLaunchSlotCallback =
    void Function(QuickLaunchSlot slot, BuildContext anchorContext);

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
  final QuickLaunchSlotCallback onSlotPressed;
  final ValueChanged<int> onEditSlot;
  final VoidCallback onOpenAll;
  final int? busySlotIndex;

  static const double _wideBreakpoint = 960;
  static const double _narrowBreakpoint = 480;
  static const double _desktopMaxWidth = 1080;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final desktop = defaultTargetPlatform == TargetPlatform.windows;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dockWidth = desktop
            ? math.min(constraints.maxWidth, _desktopMaxWidth)
            : constraints.maxWidth;
        final visibleSlotCount = !desktop
            ? quickLaunchCoreSlotCount
            : dockWidth >= _wideBreakpoint
            ? quickLaunchSlotCount
            : dockWidth < _narrowBreakpoint
            ? quickLaunchCoreSlotCount - 1
            : quickLaunchCoreSlotCount;
        final visibleSlots = layout.slots.take(visibleSlotCount);
        final hiddenSlots = desktop
            ? layout.slots.skip(visibleSlotCount).toList(growable: false)
            : const <QuickLaunchSlot>[];
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _desktopMaxWidth),
            child: Padding(
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
                  for (final slot in visibleSlots)
                    Expanded(
                      child: _QuickLaunchTile(
                        slot: slot,
                        busy: busySlotIndex == slot.slotIndex,
                        onPressed: slot.hasEventType
                            ? (anchorContext) =>
                                  onSlotPressed(slot, anchorContext)
                            : (_) => onEditSlot(slot.slotIndex),
                      ),
                    ),
                  if (hiddenSlots.isNotEmpty)
                    Expanded(
                      child: _QuickLaunchOverflowTile(
                        slots: hiddenSlots,
                        busySlotIndex: busySlotIndex,
                        onSlotPressed: onSlotPressed,
                        onEditSlot: onEditSlot,
                      ),
                    ),
                  Expanded(
                    child: _SystemTile(
                      key: const Key('quick-launch-all'),
                      label: loc.quickLaunchAll,
                      icon: Icons.apps,
                      onPressed: onOpenAll,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickLaunchOverflowTile extends StatelessWidget {
  const _QuickLaunchOverflowTile({
    required this.slots,
    required this.busySlotIndex,
    required this.onSlotPressed,
    required this.onEditSlot,
  });

  final List<QuickLaunchSlot> slots;
  final int? busySlotIndex;
  final QuickLaunchSlotCallback onSlotPressed;
  final ValueChanged<int> onEditSlot;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Builder(
      builder: (anchorContext) => PopupMenuButton<int>(
        key: const Key('quick-launch-more'),
        tooltip: loc.quickLaunchMore,
        onSelected: (index) {
          final slot = slots.firstWhere((item) => item.slotIndex == index);
          if (!slot.hasEventType) {
            onEditSlot(index);
            return;
          }
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onSlotPressed(slot, anchorContext),
          );
        },
        itemBuilder: (context) => [
          for (final slot in slots)
            PopupMenuItem<int>(
              key: Key('quick-launch-overflow-slot-${slot.slotIndex}'),
              value: slot.slotIndex,
              enabled: busySlotIndex != slot.slotIndex,
              child: Row(
                children: [
                  Icon(
                    slot.eventTypeId == null
                        ? Icons.add
                        : quickLaunchCatalogItem(slot.eventTypeId!).icon,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${slot.slotIndex + 1}. '
                      '${quickLaunchSlotLabel(slot, loc)}',
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: _SystemTileContent(
          label: loc.quickLaunchMore,
          icon: Icons.more_horiz,
        ),
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
  final ValueChanged<BuildContext> onPressed;

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
        onPressed: () => onPressed(context),
      );
    }
    final category =
        slot.executionMode == QuickLaunchExecutionMode.category ||
        quickLaunchOpensCategory(target);
    final instant =
        slot.executionMode == QuickLaunchExecutionMode.instant && !category;
    final label = quickLaunchSlotLabel(slot, loc);
    final semanticLabel = category
        ? loc.quickLaunchCategorySemantic(label)
        : instant
        ? loc.quickLaunchInstantSemantic(label)
        : loc.quickLaunchFormSemantic(label);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Builder(
        builder: (anchorContext) => InkWell(
          key: Key('quick-launch-slot-${slot.slotIndex}'),
          borderRadius: BorderRadius.circular(12),
          onTap: busy ? null : () => onPressed(anchorContext),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                                category
                                    ? Icons.arrow_drop_down
                                    : instant
                                    ? Icons.bolt
                                    : Icons.edit_outlined,
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: _SystemTileContent(label: label, icon: icon, outlined: outlined),
    );
  }
}

class _SystemTileContent extends StatelessWidget {
  const _SystemTileContent({
    required this.label,
    required this.icon,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
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
                  color: outlined ? colors.outline : colors.secondaryContainer,
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
    );
  }
}
