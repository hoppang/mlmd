import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'date_time_adjustment_controls.dart';

Future<DateTime?> showSleepDateTimePicker({
  required BuildContext context,
  required String title,
  required DateTime initialValue,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  Widget content(BuildContext pickerContext) => _SleepDateTimePicker(
    title: title,
    initialValue: initialValue,
    firstDate: firstDate,
    lastDate: lastDate,
  );

  if (defaultTargetPlatform == TargetPlatform.windows) {
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const Key('sleep-date-time-dialog'),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
          child: content(dialogContext),
        ),
      ),
    );
  }

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.92,
      ),
      child: content(sheetContext),
    ),
  );
}

class _SleepDateTimePicker extends StatefulWidget {
  const _SleepDateTimePicker({
    required this.title,
    required this.initialValue,
    required this.firstDate,
    required this.lastDate,
  });

  final String title;
  final DateTime initialValue;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_SleepDateTimePicker> createState() => _SleepDateTimePickerState();
}

class _SleepDateTimePickerState extends State<_SleepDateTimePicker> {
  late DateTime _value;
  late bool _showCalendar;

  bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;
  DateTime get _earliestValue => earliestSelectableMinute(widget.firstDate);

  DateTime get _latestValue => truncateToMinute(widget.lastDate);
  bool get _isValid =>
      !_value.isBefore(_earliestValue) && !_value.isAfter(_latestValue);

  @override
  void initState() {
    super.initState();
    _value = truncateToMinute(widget.initialValue);
    _showCalendar = _isWindows || !_isTodayOrYesterday(_value);
  }

  bool _isTodayOrYesterday(DateTime value) {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = DateUtils.dateOnly(value);
    return date == today || date == today.subtract(const Duration(days: 1));
  }

  void _setDate(DateTime date) {
    _setValue(
      DateTime(date.year, date.month, date.day, _value.hour, _value.minute),
    );
  }

  void _setValue(DateTime value) {
    setState(() => _value = value);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final selectedDate = DateUtils.dateOnly(_value);
    final isToday = selectedDate == today;
    final isYesterday = selectedDate == yesterday;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: material.closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        ChoiceChip(
                          key: const Key('sleep-date-today'),
                          label: Text(loc.searchToday),
                          selected: isToday,
                          onSelected: (_) {
                            _setDate(today);
                            if (!_isWindows) {
                              setState(() => _showCalendar = false);
                            }
                          },
                        ),
                        ChoiceChip(
                          key: const Key('sleep-date-yesterday'),
                          label: Text(loc.sleepDateYesterday),
                          selected: isYesterday,
                          onSelected: (_) {
                            _setDate(yesterday);
                            if (!_isWindows) {
                              setState(() => _showCalendar = false);
                            }
                          },
                        ),
                        ChoiceChip(
                          key: const Key('sleep-date-other'),
                          avatar: const Icon(Icons.calendar_month_outlined),
                          label: Text(loc.sleepDateOther),
                          selected: !isToday && !isYesterday,
                          onSelected: (_) =>
                              setState(() => _showCalendar = !_showCalendar),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_isWindows)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildCalendar()),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(child: _buildTimePanel()),
                        ],
                      )
                    else ...[
                      if (_showCalendar) ...[
                        _buildCalendar(),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _buildTimePanel(),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${material.formatMediumDate(_value)} · '
                      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(_value))}',
                      key: const Key('sleep-date-time-summary'),
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (!_isValid) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        loc.sleepFutureInvalid,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(loc.cancel),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton(
                    key: const Key('apply-sleep-date-time'),
                    onPressed: _isValid
                        ? () => Navigator.pop(context, _value)
                        : null,
                    child: Text(material.okButtonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDate = DateUtils.dateOnly(widget.firstDate);
    final lastDate = DateUtils.dateOnly(widget.lastDate);
    final selectedDate = DateUtils.dateOnly(_value);
    final initialDate = selectedDate.isBefore(firstDate)
        ? firstDate
        : selectedDate.isAfter(lastDate)
        ? lastDate
        : selectedDate;
    return CalendarDatePicker(
      key: const Key('sleep-date-calendar'),
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: DateTime.now(),
      onDateChanged: _setDate,
    );
  }

  Widget _buildTimePanel() {
    return DateTimeAdjustmentControls(
      value: _value,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      onChanged: _setValue,
      keyPrefix: 'sleep',
      showSpinner: !_isWindows,
      showDirectInput: _isWindows,
    );
  }
}
