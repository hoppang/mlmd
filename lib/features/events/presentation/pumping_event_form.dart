import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/stt_memo_text_field.dart';
import '../domain/pumping_record.dart';

class PumpingFormResult {
  const PumpingFormResult({required this.record, required this.details});

  final PumpingRecord record;
  final String details;
}

class PumpingEventForm extends StatefulWidget {
  const PumpingEventForm({
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
  final ValueChanged<PumpingFormResult> onSave;
  final PumpingRecord? initialRecord;

  @override
  State<PumpingEventForm> createState() => _PumpingEventFormState();
}

class _PumpingEventFormState extends State<PumpingEventForm> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late PumpingSide _selectedSide;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialRecord?.amountMl?.toString() ?? '',
    );
    _noteController = TextEditingController(
      text: widget.initialRecord?.note ?? '',
    );
    _selectedSide = widget.initialRecord?.side ?? PumpingSide.unknown;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onSideTapped(PumpingSide side) {
    if (widget.saving) return;
    setState(() {
      _selectedSide = _selectedSide == side ? PumpingSide.unknown : side;
    });
  }

  void _save() {
    final loc = AppLocalizations.of(context)!;
    final amountText = _amountController.text.trim();
    int? amountMl;

    if (amountText.isNotEmpty) {
      final parsed = int.tryParse(amountText);
      if (parsed == null || parsed <= 0) {
        setState(() {
          _validationError = loc.exactAmountRequired;
        });
        return;
      }
      amountMl = parsed;
    }

    final noteText = _noteController.text.trim();
    final record = PumpingRecord(
      recordId: widget.initialRecord?.recordId,
      childId: widget.initialRecord?.childId,
      occurredAt: widget.occurredAt,
      amountMl: amountMl,
      side: _selectedSide,
      note: noteText.isNotEmpty ? noteText : null,
      createdByAuthorProfileId: widget.initialRecord?.createdByAuthorProfileId,
      createdByDeviceProfileId: widget.initialRecord?.createdByDeviceProfileId,
      createdAt: widget.initialRecord?.createdAt,
      lastModified: widget.initialRecord?.lastModified,
    );

    final details = record.buildDetails(loc);

    widget.onSave(
      PumpingFormResult(
        record: record,
        details: details,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      key: const Key('pumping-event-form'),
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
              const Icon(Icons.water_drop_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.pumpingEvent,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('pumping-amount-input'),
            controller: _amountController,
            enabled: !widget.saving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: loc.pumpingAmountLabel,
              hintText: loc.pumpingAmountHint,
              suffixText: 'mL',
              errorText: _validationError,
            ),
            onChanged: (_) {
              if (_validationError != null) {
                setState(() => _validationError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            loc.pumpingSideLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  key: const Key('pumping-side-chip-left'),
                  label: Center(child: Text(loc.leftSideOption)),
                  selected: _selectedSide == PumpingSide.left,
                  onSelected: widget.saving ? null : (_) => _onSideTapped(PumpingSide.left),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilterChip(
                  key: const Key('pumping-side-chip-right'),
                  label: Center(child: Text(loc.rightSideOption)),
                  selected: _selectedSide == PumpingSide.right,
                  onSelected: widget.saving ? null : (_) => _onSideTapped(PumpingSide.right),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilterChip(
                  key: const Key('pumping-side-chip-both'),
                  label: Center(child: Text(loc.bothSidesOption)),
                  selected: _selectedSide == PumpingSide.both,
                  onSelected: widget.saving ? null : (_) => _onSideTapped(PumpingSide.both),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SttMemoTextField(
            controller: _noteController,
            labelText: loc.memoOptionalLabel,
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
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('save-pumping-event-button'),
            onPressed: widget.saving ? null : _save,
            icon: widget.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(loc.savePumping),
          ),
        ],
      ),
    );
  }
}
