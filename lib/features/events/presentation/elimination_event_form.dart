import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/elimination_record.dart';

class EliminationEventForm extends StatefulWidget {
  const EliminationEventForm({
    required this.savedRecord,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onQuickSave,
    required this.onUpdate,
    required this.onUndo,
    required this.onDone,
    super.key,
  });

  final EliminationRecord? savedRecord;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final ValueChanged<EliminationKind> onQuickSave;
  final ValueChanged<EliminationRecord> onUpdate;
  final VoidCallback onUndo;
  final VoidCallback onDone;

  @override
  State<EliminationEventForm> createState() => _EliminationEventFormState();
}

class _EliminationEventFormState extends State<EliminationEventForm> {
  final _noteController = TextEditingController();
  EliminationKind? _kind;
  EliminationAmount? _stoolAmount;
  StoolConsistency? _stoolConsistency;
  StoolColor? _stoolColor;

  @override
  void initState() {
    super.initState();
    _restore(widget.savedRecord);
  }

  @override
  void didUpdateWidget(covariant EliminationEventForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.savedRecord != widget.savedRecord) {
      _restore(widget.savedRecord);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _restore(EliminationRecord? record) {
    _kind = record?.kind;
    _stoolAmount = record?.stoolAmount;
    _stoolConsistency = record?.stoolConsistency;
    _stoolColor = record?.stoolColor;
    _noteController.text = record?.note ?? '';
  }

  void _changeKind(EliminationKind kind) {
    setState(() {
      _kind = kind;
      if (kind == EliminationKind.urine) {
        _stoolAmount = null;
        _stoolConsistency = null;
        _stoolColor = null;
      }
    });
  }

  void _saveChanges() {
    final original = widget.savedRecord;
    final kind = _kind;
    if (original == null || kind == null || widget.saving) return;
    final note = _noteController.text.trim();
    widget.onUpdate(
      original.copyWith(
        kind: kind,
        stoolAmount: _stoolAmount,
        clearStoolAmount: _stoolAmount == null,
        stoolConsistency: _stoolConsistency,
        clearStoolConsistency: _stoolConsistency == null,
        stoolColor: _stoolColor,
        clearStoolColor: _stoolColor == null,
        note: note,
        clearNote: note.isEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final saved = widget.savedRecord;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      key: const Key('elimination-record-form'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('back-to-record-types'),
                tooltip: saved == null ? loc.backToRecordTypes : loc.close,
                onPressed: widget.saving
                    ? null
                    : saved == null
                    ? widget.onBack
                    : widget.onDone,
                icon: Icon(saved == null ? Icons.arrow_back : Icons.close),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.child_friendly_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.diaperEvent,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (saved == null)
            _QuickKindButtons(
              saving: widget.saving,
              onSelected: widget.onQuickSave,
            )
          else ...[
            Semantics(
              liveRegion: true,
              child: Text(
                loc.eliminationSavedHint,
                key: const Key('elimination-saved-hint'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              loc.eliminationKindTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final kind in EliminationKind.values)
                  ChoiceChip(
                    key: Key('elimination-kind-${kind.name}'),
                    label: Text(eliminationKindLabel(loc, kind)),
                    selected: _kind == kind,
                    onSelected: widget.saving ? null : (_) => _changeKind(kind),
                  ),
              ],
            ),
            if (_kind != EliminationKind.urine) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                loc.eliminationOptionalDetailsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ChoiceSection<EliminationAmount>(
                title: loc.eliminationAmountTitle,
                values: EliminationAmount.values,
                selected: _stoolAmount,
                label: (value) => eliminationAmountLabel(loc, value),
                keyFor: (value) => 'elimination-amount-${value.name}',
                enabled: !widget.saving,
                onSelected: (value) => setState(
                  () => _stoolAmount = _stoolAmount == value ? null : value,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChoiceSection<StoolConsistency>(
                title: loc.stoolConsistencyTitle,
                values: StoolConsistency.values,
                selected: _stoolConsistency,
                label: (value) => stoolConsistencyLabel(loc, value),
                keyFor: (value) => 'stool-consistency-${value.name}',
                enabled: !widget.saving,
                onSelected: (value) => setState(
                  () => _stoolConsistency = _stoolConsistency == value
                      ? null
                      : value,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChoiceSection<StoolColor>(
                title: loc.stoolColorTitle,
                values: StoolColor.values,
                selected: _stoolColor,
                label: (value) => stoolColorLabel(loc, value),
                keyFor: (value) => 'stool-color-${value.name}',
                enabled: !widget.saving,
                onSelected: (value) => setState(
                  () => _stoolColor = _stoolColor == value ? null : value,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('elimination-note'),
                controller: _noteController,
                enabled: !widget.saving,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: loc.memoOptionalLabel),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                loc.eliminationObservationHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (widget.error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.error!,
                key: const Key('quick-record-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('save-elimination-changes'),
              onPressed: widget.saving ? null : _saveChanges,
              icon: widget.saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(loc.saveEliminationChanges),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('undo-elimination-record'),
                    onPressed: widget.saving ? null : widget.onUndo,
                    icon: const Icon(Icons.undo),
                    label: Text(loc.undo),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextButton(
                    key: const Key('finish-elimination-record'),
                    onPressed: widget.saving ? null : widget.onDone,
                    child: Text(loc.close),
                  ),
                ),
              ],
            ),
          ],
          if (saved == null && widget.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.error!,
              key: const Key('quick-record-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickKindButtons extends StatelessWidget {
  const _QuickKindButtons({required this.saving, required this.onSelected});

  final bool saving;
  final ValueChanged<EliminationKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in EliminationKind.values) ...[
          FilledButton.tonalIcon(
            key: Key('save-elimination-${kind.name}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              alignment: Alignment.centerLeft,
            ),
            onPressed: saving ? null : () => onSelected(kind),
            icon: Icon(_kindIcon(kind)),
            label: Text(eliminationKindLabel(loc, kind)),
          ),
          if (kind != EliminationKind.both)
            const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _ChoiceSection<T> extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.keyFor,
    required this.enabled,
    required this.onSelected,
  });

  final String title;
  final Iterable<T> values;
  final T? selected;
  final String Function(T value) label;
  final String Function(T value) keyFor;
  final bool enabled;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final value in values)
              ChoiceChip(
                key: Key(keyFor(value)),
                label: Text(label(value)),
                selected: selected == value,
                onSelected: enabled ? (_) => onSelected(value) : null,
              ),
          ],
        ),
      ],
    );
  }
}

IconData _kindIcon(EliminationKind kind) => switch (kind) {
  EliminationKind.urine => Icons.water_drop_outlined,
  EliminationKind.stool => Icons.circle_outlined,
  EliminationKind.both => Icons.done_all,
};

String eliminationKindLabel(AppLocalizations loc, EliminationKind kind) =>
    switch (kind) {
      EliminationKind.urine => loc.eliminationUrineAction,
      EliminationKind.stool => loc.eliminationStoolAction,
      EliminationKind.both => loc.eliminationBothAction,
    };

String eliminationPresetLabel(AppLocalizations loc, EliminationKind kind) =>
    switch (kind) {
      EliminationKind.urine => loc.eliminationUrinePreset,
      EliminationKind.stool => loc.eliminationStoolPreset,
      EliminationKind.both => loc.eliminationBothPreset,
    };

String eliminationAmountLabel(AppLocalizations loc, EliminationAmount amount) =>
    switch (amount) {
      EliminationAmount.little => loc.eliminationAmountLittle,
      EliminationAmount.normal => loc.eliminationAmountNormal,
      EliminationAmount.much => loc.eliminationAmountMuch,
    };

String stoolConsistencyLabel(
  AppLocalizations loc,
  StoolConsistency consistency,
) => switch (consistency) {
  StoolConsistency.loose => loc.stoolConsistencyLoose,
  StoolConsistency.normal => loc.stoolConsistencyNormal,
  StoolConsistency.hard => loc.stoolConsistencyHard,
};

String stoolColorLabel(AppLocalizations loc, StoolColor color) =>
    switch (color) {
      StoolColor.yellow => loc.stoolColorYellow,
      StoolColor.brown => loc.stoolColorBrown,
      StoolColor.green => loc.stoolColorGreen,
      StoolColor.black => loc.stoolColorBlack,
      StoolColor.other => loc.stoolColorOther,
    };

String eliminationRecordDetails(
  AppLocalizations loc,
  EliminationRecord record,
) {
  final parts = <String>[
    switch (record.kind) {
      EliminationKind.urine => loc.eliminationUrineDetail,
      EliminationKind.stool => loc.eliminationStoolDetail,
      EliminationKind.both => loc.eliminationBothDetail,
    },
    if (record.stoolAmount != null)
      eliminationAmountLabel(loc, record.stoolAmount!),
    if (record.stoolConsistency != null)
      stoolConsistencyLabel(loc, record.stoolConsistency!),
    if (record.stoolColor != null) stoolColorLabel(loc, record.stoolColor!),
    if (record.note != null && record.note!.trim().isNotEmpty)
      record.note!.trim(),
  ];
  return parts.join(' · ');
}
