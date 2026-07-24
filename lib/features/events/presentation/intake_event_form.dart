import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/locale_provider.dart';
import '../domain/event_catalog.dart';
import '../domain/intake_record.dart';

class IntakeFormResult {
  const IntakeFormResult({required this.record, required this.details});

  final IntakeRecord record;
  final String details;
}

class IntakeEventForm extends ConsumerStatefulWidget {
  const IntakeEventForm({
    required this.item,
    required this.occurredAt,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onChangeTime,
    required this.onSave,
    this.initialStructuredDataJson,
    super.key,
  });

  final EventCatalogItem item;
  final DateTime occurredAt;
  final bool saving;
  final String? error;
  final String? initialStructuredDataJson;
  final VoidCallback onBack;
  final VoidCallback onChangeTime;
  final ValueChanged<IntakeFormResult> onSave;

  @override
  ConsumerState<IntakeEventForm> createState() => _IntakeEventFormState();
}

class _IntakeEventFormState extends ConsumerState<IntakeEventForm> {
  static const _cupNoticeKey = 'ux019.waterCupNoticeShown';

  final _exactController = TextEditingController();
  final _foodController = TextEditingController();
  final _memoController = TextEditingController();

  FeedingMethod? _feedingMethod = FeedingMethod.timeOnly;
  BreastSide _breastSide = BreastSide.left;
  BottleContents _bottleContents = BottleContents.formula;
  MealType _mealType = MealType.other;
  IntakeReaction? _reaction;
  AmountExpressionKind _amountKind = AmountExpressionKind.qualitative;
  QualitativeLevel _qualitativeLevel = QualitativeLevel.little;
  double _fraction = 0.5;
  String _unit = 'ml';
  bool _showAmountError = false;

  IntakeRecordKind get _recordKind => switch (widget.item.id) {
    EventTypeId.feeding => IntakeRecordKind.feeding,
    EventTypeId.meal => IntakeRecordKind.meal,
    EventTypeId.water => IntakeRecordKind.water,
    EventTypeId.snack => IntakeRecordKind.snack,
    _ => throw StateError('Not an intake event: ${widget.item.id}'),
  };

  bool get _isFood =>
      widget.item.id == EventTypeId.meal || widget.item.id == EventTypeId.snack;

  @override
  void initState() {
    super.initState();
    _mealType = _suggestedMealType(widget.occurredAt.hour);
    final encoded = widget.initialStructuredDataJson;
    if (encoded != null) _restore(IntakeRecord.decode(encoded));
  }

  @override
  void dispose() {
    _exactController.dispose();
    _foodController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  MealType _suggestedMealType(int hour) {
    if (hour < 11) return MealType.breakfast;
    if (hour < 16) return MealType.lunch;
    if (hour < 22) return MealType.dinner;
    return MealType.other;
  }

  void _restore(IntakeRecord? record) {
    if (record == null || record.kind != _recordKind) return;
    _feedingMethod = record.method;
    _breastSide = record.side ?? _breastSide;
    _bottleContents = record.bottleContents ?? _bottleContents;
    _mealType = record.mealType ?? _mealType;
    _reaction = record.reaction;
    _foodController.text = record.foodName ?? '';
    _memoController.text = record.memo ?? '';
    final amount = record.amountExpression;
    if (amount == null) return;
    _amountKind = amount.kind;
    _qualitativeLevel = amount.qualitativeLevel ?? _qualitativeLevel;
    _fraction = amount.fraction ?? _fraction;
    if (amount.exactValue != null) {
      _exactController.text = _formatNumber(amount.exactValue!);
    }
    _unit = amount.unit ?? _unit;
  }

  Future<void> _selectAmountKind(AmountExpressionKind kind) async {
    setState(() {
      _amountKind = kind;
      _showAmountError = false;
    });
    if (widget.item.id != EventTypeId.water ||
        kind != AmountExpressionKind.fraction) {
      return;
    }
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences.getBool(_cupNoticeKey) == true || !mounted) return;
    await preferences.setBool(_cupNoticeKey, true);
    if (mounted) await _showCupInfo();
  }

  Future<void> _showCupInfo() {
    final loc = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.cupAmountInfoTitle),
        content: Text(loc.cupAmountInfoBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
  }

  AmountExpression? _amount() {
    if (widget.item.id == EventTypeId.feeding &&
        _feedingMethod != FeedingMethod.bottle) {
      return null;
    }
    switch (_amountKind) {
      case AmountExpressionKind.qualitative:
        return AmountExpression.qualitative(_qualitativeLevel);
      case AmountExpressionKind.fraction:
        return AmountExpression.fraction(_fraction);
      case AmountExpressionKind.exact:
        final value = num.tryParse(_exactController.text.trim());
        if (value == null || value <= 0) return null;
        return AmountExpression.exact(exactValue: value, unit: _unit);
    }
  }

  void _submit() {
    final amount = _amount();
    if (_amountKind == AmountExpressionKind.exact &&
        (widget.item.id != EventTypeId.feeding ||
            _feedingMethod == FeedingMethod.bottle) &&
        _exactController.text.trim().isNotEmpty &&
        amount == null) {
      setState(() => _showAmountError = true);
      return;
    }
    final record = IntakeRecord(
      kind: _recordKind,
      amountExpression: amount,
      method: widget.item.id == EventTypeId.feeding
          ? (_feedingMethod ?? FeedingMethod.timeOnly)
          : null,
      side: _feedingMethod == FeedingMethod.breast ? _breastSide : null,
      bottleContents: _feedingMethod == FeedingMethod.bottle
          ? _bottleContents
          : null,
      mealType: widget.item.id == EventTypeId.meal ? _mealType : null,
      foodName: _isFood ? _foodController.text.trim() : null,
      reaction: _isFood ? _reaction : null,
      memo: _memoController.text.trim(),
      startedAt: _feedingMethod == FeedingMethod.breast
          ? widget.occurredAt
          : null,
    );
    widget.onSave(IntakeFormResult(record: record, details: _details(record)));
  }

  String _details(IntakeRecord record) {
    final loc = AppLocalizations.of(context)!;
    final values = <String>[];
    if (record.kind == IntakeRecordKind.feeding) {
      values.add(_feedingMethodLabel(record.method!, loc));
      if (record.side != null) {
        values.add(
          record.side == BreastSide.left
              ? loc.leftSideOption
              : loc.rightSideOption,
        );
      }
      if (record.bottleContents != null) {
        values.add(_bottleContentsLabel(record.bottleContents!, loc));
      }
    }
    if (record.mealType != null) {
      values.add(_mealTypeLabel(record.mealType!, loc));
    }
    if ((record.foodName ?? '').isNotEmpty) values.add(record.foodName!);
    if (record.amountExpression != null) {
      values.add(_amountLabel(record.amountExpression!, loc));
    }
    if (record.reaction != null) {
      values.add(_reactionLabel(record.reaction!, loc));
    }
    if ((record.memo ?? '').isNotEmpty) values.add(record.memo!);
    return values.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final item = widget.item;
    return SingleChildScrollView(
      key: const Key('intake-record-form'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('back-to-record-types'),
                tooltip: loc.backToRecordTypes,
                onPressed: widget.saving ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(item.icon),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  item.label(loc),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (item.id == EventTypeId.feeding) ..._feedingFields(loc),
          if (item.id == EventTypeId.meal) ..._mealFields(loc),
          if (item.id == EventTypeId.water) ..._amountFields(loc),
          if (item.id == EventTypeId.snack) ...[
            TextField(
              key: const Key('intake-food-name'),
              controller: _foodController,
              enabled: !widget.saving,
              decoration: InputDecoration(labelText: loc.snackNameLabel),
            ),
            const SizedBox(height: AppSpacing.md),
            ..._amountFields(loc),
            ..._reactionFields(loc),
          ],
          TextField(
            key: const Key('intake-memo'),
            controller: _memoController,
            enabled: !widget.saving,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(labelText: loc.memoOptionalLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('quick-record-time'),
            onPressed: widget.saving ? null : widget.onChangeTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              '${loc.recordTimeLabel} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(widget.occurredAt))}',
            ),
          ),
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
            key: const Key('save-quick-record'),
            onPressed: widget.saving ? null : _submit,
            icon: widget.saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.saving ? loc.savingQuickRecord : loc.saveRecord),
          ),
        ],
      ),
    );
  }

  List<Widget> _feedingFields(AppLocalizations loc) {
    return [
      _FieldLabel(loc.feedingMethodLabel),
      Wrap(
        spacing: AppSpacing.xs,
        children: [
          for (final method in FeedingMethod.values)
            ChoiceChip(
              key: Key('feeding-method-${method.name}'),
              label: Text(_feedingMethodLabel(method, loc)),
              selected: _feedingMethod == method,
              onSelected: widget.saving
                  ? null
                  : (_) => setState(() {
                      _feedingMethod = method;
                      _amountKind = AmountExpressionKind.exact;
                      _showAmountError = false;
                    }),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      if (_feedingMethod == FeedingMethod.breast) ...[
        _FieldLabel(loc.breastSideLabel),
        _ChoiceWrap<BreastSide>(
          values: BreastSide.values,
          selected: _breastSide,
          label: (value) => value == BreastSide.left
              ? loc.leftSideOption
              : loc.rightSideOption,
          onSelected: (value) => setState(() => _breastSide = value),
          keyPrefix: 'breast-side',
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (_feedingMethod == FeedingMethod.bottle) ...[
        _FieldLabel(loc.bottleContentsLabel),
        _ChoiceWrap<BottleContents>(
          values: BottleContents.values,
          selected: _bottleContents,
          label: (value) => _bottleContentsLabel(value, loc),
          onSelected: (value) => setState(() => _bottleContents = value),
          keyPrefix: 'bottle-contents',
        ),
        const SizedBox(height: AppSpacing.md),
        ..._exactAmountFields(loc),
      ],
    ];
  }

  List<Widget> _mealFields(AppLocalizations loc) {
    return [
      _FieldLabel(loc.mealTypeLabel),
      _ChoiceWrap<MealType>(
        values: MealType.values,
        selected: _mealType,
        label: (value) => _mealTypeLabel(value, loc),
        onSelected: (value) => setState(() => _mealType = value),
        keyPrefix: 'meal-type',
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        key: const Key('intake-food-name'),
        controller: _foodController,
        enabled: !widget.saving,
        decoration: InputDecoration(labelText: loc.foodNameLabel),
      ),
      const SizedBox(height: AppSpacing.md),
      ..._amountFields(loc),
      ..._reactionFields(loc),
    ];
  }

  List<Widget> _amountFields(AppLocalizations loc) {
    return [
      Row(
        children: [
          Expanded(child: _FieldLabel(loc.amountStyleLabel)),
          if (widget.item.id == EventTypeId.water)
            IconButton(
              key: const Key('water-cup-info'),
              tooltip: loc.cupAmountInfoTitle,
              onPressed: _showCupInfo,
              icon: const Icon(Icons.info_outline),
            ),
        ],
      ),
      Wrap(
        spacing: AppSpacing.xs,
        children: [
          ChoiceChip(
            key: const Key('amount-kind-qualitative'),
            label: Text(loc.qualitativeAmountOption),
            selected: _amountKind == AmountExpressionKind.qualitative,
            onSelected: widget.saving
                ? null
                : (_) => _selectAmountKind(AmountExpressionKind.qualitative),
          ),
          ChoiceChip(
            key: const Key('amount-kind-fraction'),
            label: Text(
              widget.item.id == EventTypeId.water
                  ? loc.cupAmountOption
                  : loc.fractionAmountOption,
            ),
            selected: _amountKind == AmountExpressionKind.fraction,
            onSelected: widget.saving
                ? null
                : (_) => _selectAmountKind(AmountExpressionKind.fraction),
          ),
          ChoiceChip(
            key: const Key('amount-kind-exact'),
            label: Text(loc.exactAmountOption),
            selected: _amountKind == AmountExpressionKind.exact,
            onSelected: widget.saving
                ? null
                : (_) => _selectAmountKind(AmountExpressionKind.exact),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      if (_amountKind == AmountExpressionKind.qualitative)
        _ChoiceWrap<QualitativeLevel>(
          values: QualitativeLevel.values,
          selected: _qualitativeLevel,
          label: (value) => _qualitativeLabel(value, loc, food: _isFood),
          onSelected: (value) => setState(() => _qualitativeLevel = value),
          keyPrefix: 'qualitative-amount',
        ),
      if (_amountKind == AmountExpressionKind.fraction)
        _ChoiceWrap<double>(
          values: const [0.25, 0.5, 0.75, 1],
          selected: _fraction,
          label: (value) => _fractionLabel(value, loc),
          onSelected: (value) => setState(() => _fraction = value),
          keyPrefix: 'fraction-amount',
        ),
      if (_amountKind == AmountExpressionKind.exact) ..._exactAmountFields(loc),
      const SizedBox(height: AppSpacing.md),
    ];
  }

  List<Widget> _exactAmountFields(AppLocalizations loc) {
    final units = widget.item.id == EventTypeId.feeding
        ? const ['ml', 'oz']
        : widget.item.id == EventTypeId.water
        ? const ['ml']
        : const ['g', 'ml'];
    if (!units.contains(_unit)) _unit = units.first;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: const Key('exact-amount-value'),
              controller: _exactController,
              enabled: !widget.saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _showAmountError = false),
              decoration: InputDecoration(
                labelText: loc.exactAmountLabel,
                errorText: _showAmountError ? loc.exactAmountRequired : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 96,
            child: DropdownButtonFormField<String>(
              key: const Key('exact-amount-unit'),
              initialValue: _unit,
              decoration: InputDecoration(labelText: loc.amountUnitLabel),
              items: [
                for (final unit in units)
                  DropdownMenuItem(value: unit, child: Text(unit)),
              ],
              onChanged: widget.saving
                  ? null
                  : (value) => setState(() => _unit = value ?? units.first),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _reactionFields(AppLocalizations loc) {
    return [
      const SizedBox(height: AppSpacing.md),
      _FieldLabel(loc.reactionLabel),
      Wrap(
        spacing: AppSpacing.xs,
        children: [
          for (final reaction in IntakeReaction.values)
            FilterChip(
              key: Key('intake-reaction-${reaction.name}'),
              label: Text(_reactionLabel(reaction, loc)),
              selected: _reaction == reaction,
              onSelected: widget.saving
                  ? null
                  : (selected) =>
                        setState(() => _reaction = selected ? reaction : null),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
    ];
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    required this.keyPrefix,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      for (final value in values)
        ChoiceChip(
          key: Key('$keyPrefix-$value'),
          label: Text(label(value)),
          selected: selected == value,
          onSelected: (_) => onSelected(value),
        ),
    ],
  );
}

String _feedingMethodLabel(FeedingMethod method, AppLocalizations loc) =>
    switch (method) {
      FeedingMethod.breast => loc.breastFeedingOption,
      FeedingMethod.bottle => loc.bottleFeedingOption,
      FeedingMethod.timeOnly => loc.feedingTimeOnlyOption,
    };

String _bottleContentsLabel(BottleContents value, AppLocalizations loc) =>
    switch (value) {
      BottleContents.formula => loc.formulaOption,
      BottleContents.expressedMilk => loc.expressedMilkOption,
      BottleContents.other => loc.otherOption,
    };

String _mealTypeLabel(MealType value, AppLocalizations loc) => switch (value) {
  MealType.breakfast => loc.breakfastOption,
  MealType.lunch => loc.lunchOption,
  MealType.dinner => loc.dinnerOption,
  MealType.other => loc.otherOption,
};

String _reactionLabel(IntakeReaction value, AppLocalizations loc) =>
    switch (value) {
      IntakeReaction.ateWell => loc.ateWellOption,
      IntakeReaction.average => loc.averageReactionOption,
      IntakeReaction.refused => loc.refusedOption,
    };

String _qualitativeLabel(
  QualitativeLevel value,
  AppLocalizations loc, {
  required bool food,
}) => switch (value) {
  QualitativeLevel.sip => food ? loc.biteAmountOption : loc.sipAmountOption,
  QualitativeLevel.little => loc.littleAmountOption,
  QualitativeLevel.normal => loc.normalAmountOption,
  QualitativeLevel.much => loc.muchAmountOption,
};

String _fractionLabel(double value, AppLocalizations loc) => switch (value) {
  0.25 => loc.quarterAmountOption,
  0.5 => loc.halfAmountOption,
  0.75 => loc.almostAllAmountOption,
  _ => loc.allAmountOption,
};

String _amountLabel(AmountExpression value, AppLocalizations loc) =>
    switch (value.kind) {
      AmountExpressionKind.qualitative => _qualitativeLabel(
        value.qualitativeLevel!,
        loc,
        food: false,
      ),
      AmountExpressionKind.fraction => _fractionLabel(value.fraction!, loc),
      AmountExpressionKind.exact =>
        '${_formatNumber(value.exactValue!)} ${_displayUnit(value.unit!)}',
    };

String _formatNumber(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String _displayUnit(String unit) => unit == 'ml' ? 'mL' : unit;
