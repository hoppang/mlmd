import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/domain/event_catalog.dart';
import '../../events/domain/intake_record.dart';
import '../application/quick_launch_notifier.dart';
import '../domain/quick_launch_models.dart';
import 'quick_launch_labels.dart';

class QuickLaunchEditorSheet extends ConsumerStatefulWidget {
  const QuickLaunchEditorSheet({this.initialSlotIndex = 0, super.key});

  final int initialSlotIndex;

  @override
  ConsumerState<QuickLaunchEditorSheet> createState() =>
      _QuickLaunchEditorSheetState();
}

class _QuickLaunchEditorSheetState
    extends ConsumerState<QuickLaunchEditorSheet> {
  late int _slotIndex;
  QuickLaunchEventTarget? _target;
  QuickLaunchExecutionMode _mode = QuickLaunchExecutionMode.instant;
  EliminationPreset _eliminationPreset = EliminationPreset.urine;
  final _labelController = TextEditingController();

  int get _editableSlotCount => defaultTargetPlatform == TargetPlatform.windows
      ? quickLaunchSlotCount
      : quickLaunchCoreSlotCount;

  @override
  void initState() {
    super.initState();
    _slotIndex = widget.initialSlotIndex < 0
        ? 0
        : widget.initialSlotIndex >= _editableSlotCount
        ? _editableSlotCount - 1
        : widget.initialSlotIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreCurrentSlot());
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _restoreCurrentSlot() {
    final slot = ref.read(quickLaunchProvider).layout.slotAt(_slotIndex);
    final target = slot.eventTypeId;
    String? eliminationKind;
    try {
      final decoded = jsonDecode(slot.structuredPresetJson ?? '');
      if (decoded is Map) eliminationKind = decoded['kind']?.toString();
    } on FormatException {
      // Keep defaults for an invalid legacy preset.
    }
    setState(() {
      _target = target;
      _mode = target != null && quickLaunchOpensCategory(target)
          ? QuickLaunchExecutionMode.category
          : slot.executionMode;
      _labelController.text = slot.displayLabel ?? '';
      _eliminationPreset = switch (eliminationKind) {
        'stool' => EliminationPreset.stool,
        'both' => EliminationPreset.both,
        _ => EliminationPreset.urine,
      };
    });
  }

  void _selectSlot(int index) {
    _slotIndex = index;
    _restoreCurrentSlot();
  }

  void _selectTarget(QuickLaunchEventTarget target) {
    setState(() {
      _target = target;
      _mode = quickLaunchOpensCategory(target)
          ? QuickLaunchExecutionMode.category
          : quickLaunchCanSaveInstantly(target)
          ? QuickLaunchExecutionMode.instant
          : QuickLaunchExecutionMode.prefilledForm;
      _labelController.clear();
    });
  }

  void _selectEliminationPreset(EliminationPreset preset) {
    setState(() {
      _target = QuickLaunchEventTarget.diaper;
      _mode = QuickLaunchExecutionMode.instant;
      _eliminationPreset = preset;
      _labelController.clear();
    });
  }

  Future<void> _moveSelectedSlot(int offset) async {
    final targetIndex = _slotIndex + offset;
    if (targetIndex < 0 || targetIndex >= _editableSlotCount) return;
    await ref
        .read(quickLaunchProvider.notifier)
        .moveSlot(_slotIndex, targetIndex);
    if (!mounted) return;
    _slotIndex = targetIndex;
    _restoreCurrentSlot();
  }

  Future<void> _save() async {
    final target = _target;
    if (target == null) return;
    final state = ref.read(quickLaunchProvider);
    final current = state.layout.slotAt(_slotIndex);
    final structuredPreset = _structuredPreset(target);
    await ref
        .read(quickLaunchProvider.notifier)
        .setSlot(
          _slotIndex,
          current.copyWith(
            eventTypeId: target,
            executionMode: _mode,
            structuredPresetJson: structuredPreset,
            clearStructuredPresetJson: structuredPreset == null,
            displayLabel: _labelController.text.trim().isEmpty
                ? null
                : _labelController.text.trim(),
            clearDisplayLabel: _labelController.text.trim().isEmpty,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  String? _structuredPreset(QuickLaunchEventTarget target) {
    if (target == QuickLaunchEventTarget.feeding) return null;
    if (target == QuickLaunchEventTarget.formulaFeeding) {
      return const IntakeRecord(
        kind: IntakeRecordKind.feeding,
        method: FeedingMethod.bottle,
        bottleContents: BottleContents.formula,
      ).encode();
    }
    if (target == QuickLaunchEventTarget.breastFeeding) {
      return const IntakeRecord(
        kind: IntakeRecordKind.feeding,
        method: FeedingMethod.breast,
        side: BreastSide.left,
      ).encode();
    }
    if (target == QuickLaunchEventTarget.expressedMilkFeeding) {
      return const IntakeRecord(
        kind: IntakeRecordKind.feeding,
        method: FeedingMethod.bottle,
        bottleContents: BottleContents.expressedMilk,
      ).encode();
    }
    if (target == QuickLaunchEventTarget.diaper) {
      return jsonEncode({'kind': _eliminationPreset.name});
    }
    return null;
  }

  Future<void> _clear() async {
    await ref.read(quickLaunchProvider.notifier).clearSlot(_slotIndex);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final layout = ref.watch(quickLaunchProvider).layout;
    final target = _target;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('quick-launch-editor'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.quickLaunchEditTitle,
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
            Text(loc.quickLaunchEditDescription),
            const SizedBox(height: AppSpacing.md),
            Text(
              loc.quickLaunchChooseSlot,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: [
                  for (var index = 0; index < _editableSlotCount; index++)
                    ButtonSegment(
                      value: index,
                      label: Text('${index + 1}'),
                      tooltip: quickLaunchSlotLabel(layout.slotAt(index), loc),
                    ),
                ],
                selected: {_slotIndex},
                onSelectionChanged: (values) => _selectSlot(values.first),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('move-quick-launch-left'),
                  onPressed: _slotIndex == 0
                      ? null
                      : () => _moveSelectedSlot(-1),
                  tooltip: loc.quickLaunchMoveLeft,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  key: const Key('move-quick-launch-right'),
                  onPressed: _slotIndex == _editableSlotCount - 1
                      ? null
                      : () => _moveSelectedSlot(1),
                  tooltip: loc.quickLaunchMoveRight,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              loc.quickLaunchChooseEvent,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final item in eventCatalog) ...[
                  if (item.id == EventTypeId.feeding) ...[
                    for (final feedingTarget in const [
                      QuickLaunchEventTarget.feeding,
                      QuickLaunchEventTarget.formulaFeeding,
                      QuickLaunchEventTarget.breastFeeding,
                      QuickLaunchEventTarget.expressedMilkFeeding,
                    ])
                      ChoiceChip(
                        key: Key('quick-launch-event-${feedingTarget.name}'),
                        avatar: Icon(item.icon, size: 18),
                        label: Text(
                          _quickLaunchTargetLabel(feedingTarget, loc),
                        ),
                        selected: target == feedingTarget,
                        onSelected: (_) => _selectTarget(feedingTarget),
                      ),
                  ] else if (item.id == EventTypeId.diaper) ...[
                    for (final preset in EliminationPreset.values)
                      ChoiceChip(
                        key: Key(
                          'quick-launch-event-diaper${_presetKeySuffix(preset)}',
                        ),
                        avatar: Icon(_presetIcon(preset), size: 18),
                        label: Text(_eliminationPresetLabel(preset, loc)),
                        selected:
                            target == QuickLaunchEventTarget.diaper &&
                            _eliminationPreset == preset,
                        onSelected: (_) => _selectEliminationPreset(preset),
                      ),
                  ] else
                    ChoiceChip(
                      key: Key('quick-launch-event-${item.id.name}'),
                      avatar: Icon(item.icon, size: 18),
                      label: Text(item.label(loc)),
                      selected: target?.name == item.id.name,
                      onSelected: (_) =>
                          _selectTarget(quickLaunchTarget(item.id)),
                    ),
                ],
              ],
            ),
            if (target != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ExecutionPreview(
                mode: _mode,
                label: target == QuickLaunchEventTarget.diaper
                    ? _eliminationPresetLabel(_eliminationPreset, loc)
                    : _quickLaunchTargetLabel(target, loc),
                category: quickLaunchOpensCategory(target),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('quick-launch-display-label'),
                controller: _labelController,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: loc.quickLaunchDisplayLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('save-quick-launch-slot'),
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(loc.quickLaunchSaveSlot),
              ),
            ],
            if (layout.slotAt(_slotIndex).hasEventType) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                key: const Key('clear-quick-launch-slot'),
                onPressed: _clear,
                icon: const Icon(Icons.remove_circle_outline),
                label: Text(loc.quickLaunchClearSlot),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum EliminationPreset { urine, stool, both }

String _eliminationPresetLabel(
  EliminationPreset preset,
  AppLocalizations loc,
) => switch (preset) {
  EliminationPreset.urine => loc.eliminationUrinePreset,
  EliminationPreset.stool => loc.eliminationStoolPreset,
  EliminationPreset.both => loc.eliminationBothPreset,
};

String _presetKeySuffix(EliminationPreset preset) => switch (preset) {
  EliminationPreset.urine => 'Urine',
  EliminationPreset.stool => 'Stool',
  EliminationPreset.both => 'Both',
};

IconData _presetIcon(EliminationPreset preset) => switch (preset) {
  EliminationPreset.urine => Icons.water_drop_outlined,
  EliminationPreset.stool => Icons.circle_outlined,
  EliminationPreset.both => Icons.done_all,
};

String _quickLaunchTargetLabel(
  QuickLaunchEventTarget target,
  AppLocalizations loc,
) => switch (target) {
  QuickLaunchEventTarget.feeding => loc.feedingEvent,
  QuickLaunchEventTarget.formulaFeeding => loc.formulaOption,
  QuickLaunchEventTarget.breastFeeding => loc.breastFeedingOption,
  QuickLaunchEventTarget.expressedMilkFeeding => loc.expressedMilkFeedingOption,
  _ => quickLaunchCatalogItem(target).label(loc),
};

class _ExecutionPreview extends StatelessWidget {
  const _ExecutionPreview({
    required this.mode,
    required this.label,
    this.category = false,
  });

  final QuickLaunchExecutionMode mode;
  final String label;
  final bool category;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final instant = mode == QuickLaunchExecutionMode.instant && !category;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Icon(
          category
              ? Icons.arrow_drop_down
              : instant
              ? Icons.bolt
              : Icons.edit_outlined,
        ),
      ),
      title: Text(
        category
            ? loc.quickLaunchCategorySemantic(label)
            : instant
            ? loc.quickLaunchInstantSemantic(label)
            : loc.quickLaunchFormSemantic(label),
      ),
    );
  }
}
