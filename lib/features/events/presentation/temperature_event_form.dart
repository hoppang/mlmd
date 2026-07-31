import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/temperature_record.dart';

class TemperatureFormResult {
  const TemperatureFormResult({required this.record, required this.details});

  final TemperatureRecord record;
  final String details;
}

class TemperatureEventForm extends StatefulWidget {
  const TemperatureEventForm({
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
  final ValueChanged<TemperatureFormResult> onSave;
  final TemperatureRecord? initialRecord;

  @override
  State<TemperatureEventForm> createState() => _TemperatureEventFormState();
}

class _TemperatureEventFormState extends State<TemperatureEventForm> {
  late final TextEditingController _temperatureController;
  late final TextEditingController _noteController;
  TemperatureMeasurementSite? _measurementSite;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecord;
    _temperatureController = TextEditingController(
      text: initial?.celsius.toStringAsFixed(1) ?? '',
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
    _measurementSite = initial?.measurementSite;
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final loc = AppLocalizations.of(context)!;
    final celsius = double.tryParse(
      _temperatureController.text.trim().replaceAll(',', '.'),
    );
    if (celsius == null || celsius <= 0) {
      setState(() => _validationError = loc.temperatureValueRequired);
      return;
    }
    final record = TemperatureRecord(
      celsius: double.parse(celsius.toStringAsFixed(1)),
      occurredAt: widget.occurredAt,
      measurementSite: _measurementSite,
      note: _noteController.text.trim(),
    );
    widget.onSave(
      TemperatureFormResult(
        record: record,
        details: temperatureRecordDetails(loc, record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      key: const Key('temperature-event-form'),
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
                tooltip: loc.backToRecordTypes,
                onPressed: widget.saving ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.thermostat_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.temperatureEvent,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('temperature-value'),
            controller: _temperatureController,
            enabled: !widget.saving,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (RegExp(
                  r'^\d{0,2}(?:[.,]\d{0,1})?$',
                ).hasMatch(newValue.text)) {
                  return newValue;
                }
                return oldValue;
              }),
            ],
            onChanged: (_) => setState(() => _validationError = null),
            decoration: InputDecoration(
              labelText: loc.temperatureValueLabel,
              suffixText: '°C',
              errorText: _validationError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            loc.temperatureSiteLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final site in TemperatureMeasurementSite.values)
                ChoiceChip(
                  key: Key('temperature-site-${site.name}'),
                  label: Text(temperatureMeasurementSiteLabel(loc, site)),
                  selected: _measurementSite == site,
                  onSelected: widget.saving
                      ? null
                      : (selected) => setState(
                          () => _measurementSite = selected ? site : null,
                        ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('temperature-note'),
            controller: _noteController,
            enabled: !widget.saving,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(labelText: loc.temperatureNoteLabel),
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
          if (widget.error case final error?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              key: const Key('quick-record-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('save-quick-record'),
            onPressed: widget.saving ? null : _save,
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
}
