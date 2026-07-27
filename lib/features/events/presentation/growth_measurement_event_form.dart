import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/stt_memo_text_field.dart';
import '../domain/growth_measurement_record.dart';

class GrowthMeasurementFormResult {
  const GrowthMeasurementFormResult({
    required this.record,
    required this.details,
  });

  final GrowthMeasurementRecord record;
  final String details;
}

class GrowthMeasurementEventForm extends StatefulWidget {
  const GrowthMeasurementEventForm({
    required this.occurredAt,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onChangeTime,
    required this.onSave,
    this.initialRecord,
    super.key,
  });

  final DateTime occurredAt;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onChangeTime;
  final ValueChanged<GrowthMeasurementFormResult> onSave;
  final GrowthMeasurementRecord? initialRecord;

  @override
  State<GrowthMeasurementEventForm> createState() =>
      _GrowthMeasurementEventFormState();
}

class _GrowthMeasurementEventFormState
    extends State<GrowthMeasurementEventForm> {
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _headController;
  late final TextEditingController _noteController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final init = widget.initialRecord;
    _heightController = TextEditingController(
      text: init?.heightCm != null ? _formatDecimal(init!.heightCm!, 1) : '',
    );
    _weightController = TextEditingController(
      text: init?.weightKg != null ? _formatDecimal(init!.weightKg!, 2) : '',
    );
    _headController = TextEditingController(
      text: init?.headCm != null ? _formatDecimal(init!.headCm!, 1) : '',
    );
    _noteController = TextEditingController(text: init?.note ?? '');
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _headController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Formats [value] to exactly [decimals] decimal places, stripping trailing
  /// zeros only beyond the minimum required digits.
  String _formatDecimal(double value, int decimals) {
    return value.toStringAsFixed(decimals);
  }

  /// Parses a decimal text field; returns null on empty input.
  /// Returns a negative sentinel (-1) on parse failure.
  double? _parsePositiveDecimal(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed <= 0) return -1;
    return parsed;
  }

  void _save() {
    final loc = AppLocalizations.of(context)!;

    final heightRaw = _parsePositiveDecimal(_heightController.text);
    final weightRaw = _parsePositiveDecimal(_weightController.text);
    final headRaw = _parsePositiveDecimal(_headController.text);

    // -1 means invalid input in a filled field.
    if (heightRaw == -1 || weightRaw == -1 || headRaw == -1) {
      setState(() {
        _validationError = loc.growthMeasurementAtLeastOneError;
      });
      return;
    }

    // At least one measurement required.
    if (heightRaw == null && weightRaw == null && headRaw == null) {
      setState(() {
        _validationError = loc.growthMeasurementAtLeastOneError;
      });
      return;
    }

    final noteText = _noteController.text.trim();
    final record = GrowthMeasurementRecord(
      recordId: widget.initialRecord?.recordId,
      childId: widget.initialRecord?.childId,
      occurredAt: widget.occurredAt,
      heightCm: heightRaw,
      weightKg: weightRaw,
      headCm: headRaw,
      note: noteText.isNotEmpty ? noteText : null,
      createdByAuthorProfileId:
          widget.initialRecord?.createdByAuthorProfileId,
      createdByDeviceProfileId:
          widget.initialRecord?.createdByDeviceProfileId,
      createdAt: widget.initialRecord?.createdAt,
      lastModified: widget.initialRecord?.lastModified,
    );

    final details = record.buildDetails(loc);
    widget.onSave(GrowthMeasurementFormResult(record: record, details: details));
  }

  void _clearValidationError() {
    if (_validationError != null) {
      setState(() => _validationError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      key: const Key('growth-measurement-event-form'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row with back button and title.
          Row(
            children: [
              IconButton(
                key: const Key('back-to-record-types'),
                tooltip: loc.backToRecordTypes,
                onPressed: widget.saving ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.straighten_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.growthMeasurementFormTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Time picker button.
          OutlinedButton.icon(
            key: const Key('quick-record-time'),
            onPressed: widget.saving ? null : widget.onChangeTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              '${loc.recordTimeLabel} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(widget.occurredAt))}',
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Height field.
          _DecimalField(
            fieldKey: const Key('growth-measurement-height-input'),
            controller: _heightController,
            enabled: !widget.saving,
            labelText: loc.growthMeasurementHeightLabel,
            hintText: loc.growthMeasurementHeightHint,
            suffixText: 'cm',
            onChanged: (_) => _clearValidationError(),
          ),
          const SizedBox(height: AppSpacing.md),

          // Weight field.
          _DecimalField(
            fieldKey: const Key('growth-measurement-weight-input'),
            controller: _weightController,
            enabled: !widget.saving,
            labelText: loc.growthMeasurementWeightLabel,
            hintText: loc.growthMeasurementWeightHint,
            suffixText: 'kg',
            onChanged: (_) => _clearValidationError(),
          ),
          const SizedBox(height: AppSpacing.md),

          // Head circumference field.
          _DecimalField(
            fieldKey: const Key('growth-measurement-head-input'),
            controller: _headController,
            enabled: !widget.saving,
            labelText: loc.growthMeasurementHeadLabel,
            hintText: loc.growthMeasurementHeadHint,
            suffixText: 'cm',
            onChanged: (_) => _clearValidationError(),
          ),
          const SizedBox(height: AppSpacing.md),

          // Optional memo with STT support.
          SttMemoTextField(
            key: const Key('growth-measurement-note-field'),
            controller: _noteController,
            labelText: loc.memoOptionalLabel,
          ),

          // Validation error (at-least-one / invalid value).
          if (_validationError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _validationError!,
              key: const Key('growth-measurement-validation-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],

          // Save error from parent.
          if (widget.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.error!,
              key: const Key('quick-record-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          FilledButton.icon(
            key: const Key('save-growth-measurement-button'),
            onPressed: widget.saving ? null : _save,
            icon: widget.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(loc.saveGrowthMeasurementRecord),
          ),
        ],
      ),
    );
  }
}

/// A shared decimal text field that accepts digits and a single decimal point.
class _DecimalField extends StatelessWidget {
  const _DecimalField({
    required this.fieldKey,
    required this.controller,
    required this.enabled,
    required this.labelText,
    required this.hintText,
    required this.suffixText,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final bool enabled;
  final String labelText;
  final String hintText;
  final String suffixText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Allow digits and at most one decimal point.
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        suffixText: suffixText,
      ),
      onChanged: onChanged,
    );
  }
}
