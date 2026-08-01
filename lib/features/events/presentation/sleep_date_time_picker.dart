import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';

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
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late final TextEditingController _hourTextController;
  late final TextEditingController _minuteTextController;

  bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;
  DateTime get _earliestValue {
    final value = _truncateToMinute(widget.firstDate);
    return value.isBefore(widget.firstDate)
        ? value.add(const Duration(minutes: 1))
        : value;
  }

  DateTime get _latestValue => _truncateToMinute(widget.lastDate);
  bool get _isValid =>
      !_value.isBefore(_earliestValue) && !_value.isAfter(_latestValue);

  @override
  void initState() {
    super.initState();
    _value = DateTime(
      widget.initialValue.year,
      widget.initialValue.month,
      widget.initialValue.day,
      widget.initialValue.hour,
      widget.initialValue.minute,
    );
    _showCalendar = _isWindows || !_isTodayOrYesterday(_value);
    _hourController = FixedExtentScrollController(initialItem: _value.hour);
    _minuteController = FixedExtentScrollController(initialItem: _value.minute);
    _hourTextController = TextEditingController(text: _twoDigits(_value.hour));
    _minuteTextController = TextEditingController(
      text: _twoDigits(_value.minute),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourTextController.dispose();
    _minuteTextController.dispose();
    super.dispose();
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

  void _setTime({int? hour, int? minute}) {
    _setValue(
      DateTime(
        _value.year,
        _value.month,
        _value.day,
        hour ?? _value.hour,
        minute ?? _value.minute,
      ),
      syncWheels: false,
    );
  }

  void _adjust(Duration adjustment) {
    final next = _value.add(adjustment);
    _setValue(
      next.isBefore(_earliestValue)
          ? _earliestValue
          : next.isAfter(_latestValue)
          ? _latestValue
          : next,
    );
  }

  bool _canAdjust(Duration adjustment) => adjustment.isNegative
      ? _value.isAfter(_earliestValue)
      : _value.isBefore(_latestValue);

  void _setValue(DateTime value, {bool syncWheels = true}) {
    setState(() => _value = value);
    _hourTextController.text = _twoDigits(value.hour);
    _minuteTextController.text = _twoDigits(value.minute);
    if (!syncWheels) return;
    if (_hourController.hasClients) _hourController.jumpToItem(value.hour);
    if (_minuteController.hasClients) {
      _minuteController.jumpToItem(value.minute);
    }
  }

  void _applyTypedTime() {
    final hour = int.tryParse(_hourTextController.text);
    final minute = int.tryParse(_minuteTextController.text);
    if (hour == null || hour > 23 || minute == null || minute > 59) {
      _hourTextController.text = _twoDigits(_value.hour);
      _minuteTextController.text = _twoDigits(_value.minute);
      return;
    }
    _setTime(hour: hour, minute: minute);
    if (_hourController.hasClients) _hourController.jumpToItem(hour);
    if (_minuteController.hasClients) _minuteController.jumpToItem(minute);
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
    final loc = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    return Column(
      children: [
        if (!_isWindows)
          SizedBox(
            height: 132,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeWheel(
                  key: const Key('sleep-hour-wheel'),
                  controller: _hourController,
                  count: 24,
                  label: material.timePickerHourLabel,
                  onChanged: (value) => _setTime(hour: value),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Text(
                    ':',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                _TimeWheel(
                  key: const Key('sleep-minute-wheel'),
                  controller: _minuteController,
                  count: 60,
                  label: material.timePickerMinuteLabel,
                  onChanged: (value) => _setTime(minute: value),
                ),
              ],
            ),
          ),
        if (_isWindows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeTextField(
                key: const Key('sleep-hour-input'),
                controller: _hourTextController,
                label: material.timePickerHourLabel,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(':'),
              ),
              _buildTimeTextField(
                key: const Key('sleep-minute-input'),
                controller: _minuteTextController,
                label: material.timePickerMinuteLabel,
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final hours in const [-1, 1])
              OutlinedButton(
                key: Key('adjust-sleep-hour-$hours'),
                onPressed: _canAdjust(Duration(hours: hours))
                    ? () => _adjust(Duration(hours: hours))
                    : null,
                child: Text(
                  '${hours > 0 ? '+' : '−'}'
                  '${loc.sleepDurationHours(hours.abs())}',
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final delta in const [-10, -1, 1, 10])
              Tooltip(
                message: delta < 0
                    ? loc.sleepAdjustEarlier(-delta)
                    : loc.sleepAdjustLater(delta),
                child: OutlinedButton(
                  key: Key('adjust-sleep-time-$delta'),
                  onPressed: _canAdjust(Duration(minutes: delta))
                      ? () => _adjust(Duration(minutes: delta))
                      : null,
                  child: Text(
                    '${delta > 0 ? '+' : '−'}'
                    '${loc.sleepDurationMinutes(delta.abs())}',
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeTextField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return SizedBox(
      width: 76,
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: InputDecoration(labelText: label),
        onSubmitted: (_) => _applyTypedTime(),
        onTapOutside: (_) => _applyTypedTime(),
      ),
    );
  }
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    required super.key,
    required this.controller,
    required this.count,
    required this.label,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: controller,
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    diameterRatio: 1.5,
                    perspective: 0.004,
                    onSelectedItemChanged: onChanged,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: count,
                      builder: (context, index) => Center(
                        child: Text(
                          _twoDigits(index),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

DateTime _truncateToMinute(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
);
