import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/sleep_record.dart';

class SleepFormResult {
  const SleepFormResult({required this.record, required this.details});

  final SleepRecord record;
  final String details;
}

class SleepEventForm extends StatefulWidget {
  const SleepEventForm({
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onSave,
    super.key,
  });

  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final Future<void> Function(SleepFormResult result) onSave;

  @override
  State<SleepEventForm> createState() => _SleepEventFormState();
}

class _SleepEventFormState extends State<SleepEventForm> {
  final _noteController = TextEditingController();
  late DateTime _startedAt;
  late DateTime _endedAt;
  late SleepRecordKind _kind;
  SleepRecordSource _source = SleepRecordSource.suggested;
  final Set<SleepRecordMarker> _markers = {};
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _endedAt = DateTime.now();
    _startedAt = _endedAt.subtract(const Duration(hours: 1));
    _kind = _suggestKind(_startedAt, _endedAt);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _changeStart() async {
    final value = await _pickDateTime(_startedAt);
    if (value == null || !mounted) return;
    setState(() {
      _startedAt = value;
      _timeError = null;
      if (_source == SleepRecordSource.suggested) {
        _kind = _suggestKind(_startedAt, _endedAt);
      }
    });
  }

  Future<void> _changeEnd() async {
    final value = await _pickDateTime(_endedAt);
    if (value == null || !mounted) return;
    setState(() {
      _endedAt = value;
      _timeError = null;
      if (_source == SleepRecordSource.suggested) {
        _kind = _suggestKind(_startedAt, _endedAt);
      }
    });
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    if (!_endedAt.isAfter(_startedAt)) {
      setState(() => _timeError = loc.sleepTimeInvalid);
      return;
    }
    if (_endedAt.isAfter(DateTime.now())) {
      setState(() => _timeError = loc.sleepFutureInvalid);
      return;
    }
    final note = _noteController.text.trim();
    final record = SleepRecord(
      status: SleepRecordStatus.completed,
      kind: _kind,
      source: _source,
      startedAt: _startedAt,
      endedAt: _endedAt,
      markers: _markers.toList(growable: false),
      note: note.isEmpty ? null : note,
    );
    await widget.onSave(
      SleepFormResult(record: record, details: sleepRecordDetails(loc, record)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      key: const Key('sleep-record-form'),
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
              const Icon(Icons.bedtime_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.directSleepEntry,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('sleep-start-time'),
            onPressed: widget.saving ? null : _changeStart,
            icon: const Icon(Icons.bedtime_outlined),
            label: Text(
              '${loc.sleepStartTime} · ${_formatDateTime(context, _startedAt)}',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            key: const Key('sleep-end-time'),
            onPressed: widget.saving ? null : _changeEnd,
            icon: const Icon(Icons.wb_sunny_outlined),
            label: Text(
              '${loc.sleepEndTime} · ${_formatDateTime(context, _endedAt)}',
            ),
          ),
          if (_timeError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _timeError!,
              key: const Key('sleep-time-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(loc.sleepKind, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final kind in SleepRecordKind.values)
                ChoiceChip(
                  key: Key('sleep-kind-${kind.name}'),
                  label: Text(sleepKindLabel(loc, kind)),
                  selected: _kind == kind,
                  onSelected: widget.saving
                      ? null
                      : (_) => setState(() {
                          _kind = kind;
                          _source = SleepRecordSource.user;
                        }),
                ),
            ],
          ),
          if (_source == SleepRecordSource.suggested)
            Text(
              loc.sleepKindSuggested,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            loc.sleepMarkersTitle,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final marker in SleepRecordMarker.values)
                FilterChip(
                  key: Key('sleep-marker-${marker.name}'),
                  label: Text(sleepMarkerLabel(loc, marker)),
                  selected: _markers.contains(marker),
                  onSelected: widget.saving
                      ? null
                      : (selected) => setState(() {
                          selected
                              ? _markers.add(marker)
                              : _markers.remove(marker);
                        }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('sleep-note'),
            controller: _noteController,
            enabled: !widget.saving,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(labelText: loc.sleepNote),
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
            key: const Key('save-sleep-record'),
            onPressed: widget.saving ? null : _save,
            icon: widget.saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.saving ? loc.savingQuickRecord : loc.saveSleep),
          ),
        ],
      ),
    );
  }
}

String formatSleepDuration(AppLocalizations loc, Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return loc.sleepDurationLessThanMinute;
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours > 0 && remaining > 0) {
    return loc.sleepDurationHoursMinutes(hours, remaining);
  }
  if (hours > 0) return loc.sleepDurationHours(hours);
  return loc.sleepDurationMinutes(remaining);
}

String sleepMarkerLabel(AppLocalizations loc, SleepRecordMarker marker) =>
    switch (marker) {
      SleepRecordMarker.restful => loc.sleepMarkerRestful,
      SleepRecordMarker.restless => loc.sleepMarkerRestless,
      SleepRecordMarker.wokeUp => loc.sleepMarkerWokeUp,
      SleepRecordMarker.frequentWaking => loc.sleepMarkerFrequentWaking,
    };

String sleepKindLabel(AppLocalizations loc, SleepRecordKind kind) =>
    switch (kind) {
      SleepRecordKind.nap => loc.sleepKindNap,
      SleepRecordKind.night => loc.sleepKindNight,
      SleepRecordKind.unspecified => loc.sleepKindUnspecified,
    };

String sleepRecordDetails(AppLocalizations loc, SleepRecord record) {
  final endedAt = record.endedAt;
  if (endedAt == null) return '';
  final parts = <String>[
    formatSleepDuration(loc, endedAt.difference(record.startedAt)),
    sleepKindLabel(loc, record.kind),
    for (final marker in record.markers) sleepMarkerLabel(loc, marker),
  ];
  final note = record.note?.trim();
  if (note != null && note.isNotEmpty) parts.add(note);
  return parts.join(' · ');
}

SleepRecordKind _suggestKind(DateTime startedAt, DateTime endedAt) {
  final midpoint = startedAt.add(endedAt.difference(startedAt) ~/ 2);
  return midpoint.hour >= 18 || midpoint.hour < 6
      ? SleepRecordKind.night
      : SleepRecordKind.nap;
}

String _formatDateTime(BuildContext context, DateTime value) {
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(value)} '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
}
