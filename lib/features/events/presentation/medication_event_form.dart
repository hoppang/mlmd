import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/medication_record.dart';

class MedicationFormResult {
  const MedicationFormResult({
    required this.medicationName,
    required this.details,
    required this.record,
  });

  final String medicationName;
  final String details;
  final MedicationRecord record;
}

class MedicationEventForm extends StatefulWidget {
  const MedicationEventForm({
    required this.occurredAt,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onChangeTime,
    required this.onSave,
    super.key,
  });

  final DateTime occurredAt;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onChangeTime;
  final ValueChanged<MedicationFormResult> onSave;

  @override
  State<MedicationEventForm> createState() => _MedicationEventFormState();
}

class _MedicationEventFormState extends State<MedicationEventForm> {
  MedicationCategory _category = MedicationCategory.antipyretic;
  AntipyreticIngredient _ingredient = AntipyreticIngredient.acetaminophen;
  MedicationRoute _route = MedicationRoute.oral;

  final _amountController = TextEditingController();
  final _unitController = TextEditingController(text: 'mL');
  final _siteController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _unitController.dispose();
    _siteController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(MedicationCategory cat) {
    setState(() {
      _category = cat;
      if (cat == MedicationCategory.antipyretic) {
        _route = MedicationRoute.oral;
        _ingredient = AntipyreticIngredient.acetaminophen;
      } else if (cat == MedicationCategory.ointment) {
        _route = MedicationRoute.topical;
      } else {
        _route = MedicationRoute.oral;
      }
    });
  }

  void _submit() {
    final loc = AppLocalizations.of(context)!;
    final medicationName = medicationCategoryLabel(loc, _category);

    final amountText = _amountController.text.trim();
    final amountVal = double.tryParse(amountText);
    final unitVal = amountVal != null ? _unitController.text.trim() : null;

    final siteText = _siteController.text.trim();
    final siteVal = siteText.isNotEmpty ? siteText : null;

    final noteText = _noteController.text.trim();
    final noteVal = noteText.isNotEmpty ? noteText : null;

    final record = MedicationRecord(
      medicationId: 'med_${DateTime.now().microsecondsSinceEpoch}',
      category: _category,
      medicationName: medicationName,
      route: _route,
      administeredAt: widget.occurredAt,
      ingredient: _category == MedicationCategory.antipyretic ? _ingredient : null,
      amount: amountVal,
      unit: unitVal,
      administrationSite: siteVal,
      note: noteVal,
    );

    final details = medicationRecordDetails(loc, record);

    widget.onSave(
      MedicationFormResult(
        medicationName: medicationName,
        details: details,
        record: record,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final timeStr =
        '${widget.occurredAt.hour.toString().padLeft(2, '0')}:${widget.occurredAt.minute.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                key: const Key('medication-back-btn'),
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              Expanded(
                child: Text(
                  loc.medicationEvent,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                key: const Key('medication-time-btn'),
                icon: const Icon(Icons.access_time, size: 18),
                label: Text(timeStr),
                onPressed: widget.onChangeTime,
              ),
            ],
          ),

          if (widget.error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),

          // Medication Type / Category
          Text(
            loc.medicationTypeTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final cat in MedicationCategory.values)
                ChoiceChip(
                  key: Key('medication-cat-${cat.name}'),
                  label: Text(medicationCategoryLabel(loc, cat)),
                  selected: _category == cat,
                  onSelected: (_) => _onCategoryChanged(cat),
                ),
            ],
          ),

          // Antipyretic Ingredient Selection
          if (_category == MedicationCategory.antipyretic) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  loc.antipyreticIngredientTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (_ingredient == AntipyreticIngredient.unknown) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Text(
                      loc.ingredientCheckRequired,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final ing in AntipyreticIngredient.values)
                  ChoiceChip(
                    key: Key('ingredient-${ing.name}'),
                    label: Text(antipyreticIngredientLabel(loc, ing)),
                    selected: _ingredient == ing,
                    onSelected: (_) => setState(() => _ingredient = ing),
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Route selection
          Text(
            loc.medicationRouteTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              ChoiceChip(
                key: const Key('route-oral-chip'),
                label: Text(loc.medicationRouteOral),
                selected: _route == MedicationRoute.oral,
                onSelected: (_) => setState(() => _route = MedicationRoute.oral),
              ),
              ChoiceChip(
                key: const Key('route-suppository-chip'),
                label: Text(loc.medicationRouteSuppository),
                selected: _route == MedicationRoute.suppository,
                onSelected: (_) => setState(() => _route = MedicationRoute.suppository),
              ),
              ChoiceChip(
                key: const Key('route-topical-chip'),
                label: Text(loc.medicationRouteTopical),
                selected: _route == MedicationRoute.topical,
                onSelected: (_) => setState(() => _route = MedicationRoute.topical),
              ),
              ChoiceChip(
                key: const Key('route-inhaled-chip'),
                label: Text(loc.medicationRouteInhaled),
                selected: _route == MedicationRoute.inhaled,
                onSelected: (_) => setState(() => _route = MedicationRoute.inhaled),
              ),
              ChoiceChip(
                key: const Key('route-other-chip'),
                label: Text(loc.medicationRouteOther),
                selected: _route == MedicationRoute.other,
                onSelected: (_) => setState(() => _route = MedicationRoute.other),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Optional Dose & Unit
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  key: const Key('medication-amount-input'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: loc.medicationAmountLabel,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 1,
                child: TextField(
                  key: const Key('medication-unit-input'),
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: '단위',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),

          // Optional Administration Site for Topical / Non-oral
          if (_route == MedicationRoute.topical || _route == MedicationRoute.other) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('medication-site-input'),
              controller: _siteController,
              decoration: InputDecoration(
                labelText: loc.medicationSiteLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),

          // Optional Note
          TextField(
            key: const Key('medication-note-input'),
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: '메모 (선택)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Submit Button
          ElevatedButton(
            key: const Key('save-medication-btn'),
            onPressed: widget.saving ? null : _submit,
            child: widget.saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(loc.saveRecord),
          ),
        ],
      ),
    );
  }
}
