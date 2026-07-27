import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/stt_memo_text_field.dart';
import '../domain/tummy_time_record.dart';

class TummyTimeFormResult {
  const TummyTimeFormResult({required this.record, required this.details});

  final TummyTimeRecord record;
  final String details;
}

class TummyTimeEventForm extends StatefulWidget {
  const TummyTimeEventForm({
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
  final ValueChanged<TummyTimeFormResult> onSave;
  final TummyTimeRecord? initialRecord;

  @override
  State<TummyTimeEventForm> createState() => _TummyTimeEventFormState();
}

class _TummyTimeEventFormState extends State<TummyTimeEventForm> {
  late final TextEditingController _durationController;
  late final TextEditingController _noteController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.initialRecord?.durationMinutes?.toString() ?? '',
    );
    _noteController = TextEditingController(
      text: widget.initialRecord?.note ?? '',
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final loc = AppLocalizations.of(context)!;
    final durationText = _durationController.text.trim();
    int? durationMinutes;

    if (durationText.isNotEmpty) {
      final parsed = int.tryParse(durationText);
      if (parsed == null || parsed <= 0 || parsed > 999) {
        setState(() {
          _validationError = loc.tummyTimeDurationInvalidError;
        });
        return;
      }
      durationMinutes = parsed;
    }

    final noteText = _noteController.text.trim();
    final record = TummyTimeRecord(
      recordId: widget.initialRecord?.recordId,
      childId: widget.initialRecord?.childId,
      occurredAt: widget.occurredAt,
      durationMinutes: durationMinutes,
      note: noteText.isNotEmpty ? noteText : null,
      createdByAuthorProfileId:
          widget.initialRecord?.createdByAuthorProfileId,
      createdByDeviceProfileId:
          widget.initialRecord?.createdByDeviceProfileId,
      createdAt: widget.initialRecord?.createdAt,
      lastModified: widget.initialRecord?.lastModified,
    );

    final details = record.buildDetails(loc);

    widget.onSave(TummyTimeFormResult(record: record, details: details));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      key: const Key('tummy-time-event-form'),
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
              const Icon(Icons.child_care_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.tummyTimeFormTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Infant recommendation card (UX-031: growth stage tip).
          // Shown for all children until child birthday model is available;
          // at that point this card will be hidden once the infant stage passes.
          Card(
            key: const Key('tummy-time-recommendation-card'),
            margin: EdgeInsets.zero,
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          loc.tummyTimeInfantRecommendation,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    loc.tummyTimeInfantRecommendationSource,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer
                          .withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
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
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('tummy-time-duration-input'),
            controller: _durationController,
            enabled: !widget.saving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: loc.tummyTimeDurationLabel,
              hintText: loc.tummyTimeDurationHint,
              suffixText: 'min',
              errorText: _validationError,
            ),
            onChanged: (_) {
              if (_validationError != null) {
                setState(() => _validationError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SttMemoTextField(
            key: const Key('tummy-time-note-field'),
            controller: _noteController,
            labelText: loc.memoOptionalLabel,
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
            key: const Key('save-tummy-time-button'),
            onPressed: widget.saving ? null : _save,
            icon: widget.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(loc.saveTummyTimeRecord),
          ),
        ],
      ),
    );
  }
}
