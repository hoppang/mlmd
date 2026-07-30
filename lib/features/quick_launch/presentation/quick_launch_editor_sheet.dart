import 'dart:convert';

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
  FeedingMethod _feedingMethod = FeedingMethod.timeOnly;
  BreastSide _breastSide = BreastSide.left;
  BottleContents _bottleContents = BottleContents.formula;
  EliminationPreset _eliminationPreset = EliminationPreset.urine;
  final _amountController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _slotIndex = widget.initialSlotIndex < 0
        ? 0
        : widget.initialSlotIndex >= quickLaunchSlotCount
        ? quickLaunchSlotCount - 1
        : widget.initialSlotIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreCurrentSlot());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _restoreCurrentSlot() {
    final slot = ref.read(quickLaunchProvider).layout.slotAt(_slotIndex);
    final intake = IntakeRecord.decode(slot.structuredPresetJson ?? '');
    String? eliminationKind;
    try {
      final decoded = jsonDecode(slot.structuredPresetJson ?? '');
      if (decoded is Map) eliminationKind = decoded['kind']?.toString();
    } on FormatException {
      // Keep defaults for an invalid legacy preset.
    }
    setState(() {
      _target = slot.eventTypeId;
      _mode = slot.executionMode;
      _labelController.text = slot.displayLabel ?? '';
      if (intake != null) {
        _feedingMethod = intake.method ?? FeedingMethod.timeOnly;
        _breastSide = intake.side ?? BreastSide.left;
        _bottleContents = intake.bottleContents ?? BottleContents.formula;
        _amountController.text =
            intake.amountExpression?.exactValue?.toString() ?? '';
      } else {
        _feedingMethod = FeedingMethod.timeOnly;
        _amountController.clear();
      }
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
      _mode = quickLaunchCanSaveInstantly(target)
          ? QuickLaunchExecutionMode.instant
          : QuickLaunchExecutionMode.prefilledForm;
      _labelController.clear();
    });
  }

  Future<void> _moveSelectedSlot(int offset) async {
    final targetIndex = _slotIndex + offset;
    if (targetIndex < 0 || targetIndex >= quickLaunchSlotCount) return;
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
    if (target == QuickLaunchEventTarget.feeding) {
      final exactAmount = num.tryParse(_amountController.text.trim());
      return IntakeRecord(
        kind: IntakeRecordKind.feeding,
        method: _feedingMethod,
        side: _feedingMethod == FeedingMethod.breast ? _breastSide : null,
        bottleContents: _feedingMethod == FeedingMethod.bottle
            ? _bottleContents
            : null,
        amountExpression:
            _feedingMethod == FeedingMethod.bottle &&
                exactAmount != null &&
                exactAmount > 0
            ? AmountExpression.exact(exactValue: exactAmount, unit: 'ml')
            : null,
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
            SegmentedButton<int>(
              segments: [
                for (var index = 0; index < quickLaunchSlotCount; index++)
                  ButtonSegment(
                    value: index,
                    label: Text('${index + 1}'),
                    tooltip: quickLaunchSlotLabel(layout.slotAt(index), loc),
                  ),
              ],
              selected: {_slotIndex},
              onSelectionChanged: (values) => _selectSlot(values.first),
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
                  onPressed: _slotIndex == quickLaunchSlotCount - 1
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
                for (final item in eventCatalog)
                  ChoiceChip(
                    key: Key('quick-launch-event-${item.id.name}'),
                    avatar: Icon(item.icon, size: 18),
                    label: Text(item.label(loc)),
                    selected: target?.name == item.id.name,
                    onSelected: (_) =>
                        _selectTarget(quickLaunchTarget(item.id)),
                  ),
              ],
            ),
            if (target != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ExecutionPreview(
                mode: _mode,
                label: quickLaunchCatalogItem(target).label(loc),
              ),
              if (target == QuickLaunchEventTarget.feeding) ...[
                const SizedBox(height: AppSpacing.md),
                _feedingEditor(loc),
              ],
              if (target == QuickLaunchEventTarget.diaper) ...[
                const SizedBox(height: AppSpacing.md),
                _eliminationEditor(loc),
              ],
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

  Widget _feedingEditor(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.feedingMethodLabel),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final method in FeedingMethod.values)
              ChoiceChip(
                key: Key('quick-launch-feeding-${method.name}'),
                label: Text(switch (method) {
                  FeedingMethod.breast => loc.breastFeedingOption,
                  FeedingMethod.bottle => loc.bottleFeedingOption,
                  FeedingMethod.timeOnly => loc.feedingTimeOnlyOption,
                }),
                selected: _feedingMethod == method,
                onSelected: (_) => setState(() => _feedingMethod = method),
              ),
          ],
        ),
        if (_feedingMethod == FeedingMethod.breast) ...[
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<BreastSide>(
            segments: [
              ButtonSegment(
                value: BreastSide.left,
                label: Text(loc.leftSideOption),
              ),
              ButtonSegment(
                value: BreastSide.right,
                label: Text(loc.rightSideOption),
              ),
            ],
            selected: {_breastSide},
            onSelectionChanged: (values) =>
                setState(() => _breastSide = values.first),
          ),
        ],
        if (_feedingMethod == FeedingMethod.bottle) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final contents in BottleContents.values)
                ChoiceChip(
                  key: Key('quick-launch-bottle-${contents.name}'),
                  label: Text(switch (contents) {
                    BottleContents.formula => loc.formulaOption,
                    BottleContents.expressedMilk => loc.expressedMilkOption,
                    BottleContents.other => loc.otherOption,
                  }),
                  selected: _bottleContents == contents,
                  onSelected: (_) => setState(() => _bottleContents = contents),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('quick-launch-feeding-amount'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: loc.quickLaunchPresetAmount,
              suffixText: 'mL',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _eliminationEditor(AppLocalizations loc) {
    return SegmentedButton<EliminationPreset>(
      segments: [
        ButtonSegment(
          value: EliminationPreset.urine,
          label: Text(loc.eliminationUrinePreset),
        ),
        ButtonSegment(
          value: EliminationPreset.stool,
          label: Text(loc.eliminationStoolPreset),
        ),
        ButtonSegment(
          value: EliminationPreset.both,
          label: Text(loc.eliminationBothPreset),
        ),
      ],
      selected: {_eliminationPreset},
      onSelectionChanged: (values) =>
          setState(() => _eliminationPreset = values.first),
    );
  }
}

enum EliminationPreset { urine, stool, both }

class _ExecutionPreview extends StatelessWidget {
  const _ExecutionPreview({required this.mode, required this.label});

  final QuickLaunchExecutionMode mode;
  final String label;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final instant = mode == QuickLaunchExecutionMode.instant;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Icon(instant ? Icons.bolt : Icons.edit_outlined),
      ),
      title: Text(
        instant
            ? loc.quickLaunchInstantSemantic(label)
            : loc.quickLaunchFormSemantic(label),
      ),
    );
  }
}
