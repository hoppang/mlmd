import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';

class DateTimeAdjustmentControls extends StatefulWidget {
  const DateTimeAdjustmentControls({
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    required this.keyPrefix,
    required this.showSpinner,
    required this.showDirectInput,
    this.rollFutureTimeToPreviousDay = false,
    super.key,
  });

  final DateTime value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;
  final String keyPrefix;
  final bool showSpinner;
  final bool showDirectInput;
  final bool rollFutureTimeToPreviousDay;

  @override
  State<DateTimeAdjustmentControls> createState() =>
      _DateTimeAdjustmentControlsState();
}

class _DateTimeAdjustmentControlsState
    extends State<DateTimeAdjustmentControls> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late final TextEditingController _hourTextController;
  late final TextEditingController _minuteTextController;

  DateTime get _value => truncateToMinute(widget.value);
  DateTime get _earliestValue => earliestSelectableMinute(widget.firstDate);
  DateTime get _latestValue => truncateToMinute(widget.lastDate);

  @override
  void initState() {
    super.initState();
    _hourController = FixedExtentScrollController(initialItem: _value.hour);
    _minuteController = FixedExtentScrollController(initialItem: _value.minute);
    _hourTextController = TextEditingController(text: _twoDigits(_value.hour));
    _minuteTextController = TextEditingController(
      text: _twoDigits(_value.minute),
    );
  }

  @override
  void didUpdateWidget(covariant DateTimeAdjustmentControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_value == truncateToMinute(oldWidget.value)) return;
    _syncInputs(_value);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourTextController.dispose();
    _minuteTextController.dispose();
    super.dispose();
  }

  void _syncInputs(DateTime value) {
    _hourTextController.text = _twoDigits(value.hour);
    _minuteTextController.text = _twoDigits(value.minute);
    if (_hourController.hasClients &&
        _hourController.selectedItem != value.hour) {
      _hourController.jumpToItem(value.hour);
    }
    if (_minuteController.hasClients &&
        _minuteController.selectedItem != value.minute) {
      _minuteController.jumpToItem(value.minute);
    }
  }

  void _setTime({int? hour, int? minute}) {
    var next = DateTime(
      _value.year,
      _value.month,
      _value.day,
      hour ?? _value.hour,
      minute ?? _value.minute,
    );
    if (widget.rollFutureTimeToPreviousDay && next.isAfter(_latestValue)) {
      final previousDay = next.subtract(const Duration(days: 1));
      if (!previousDay.isBefore(_earliestValue)) next = previousDay;
    }
    if (next == _value) return;
    widget.onChanged(next);
  }

  void _adjust(Duration adjustment) {
    final next = _value.add(adjustment);
    widget.onChanged(
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

  void _applyTypedTime() {
    final hour = int.tryParse(_hourTextController.text);
    final minute = int.tryParse(_minuteTextController.text);
    if (hour == null || hour > 23 || minute == null || minute > 59) {
      _syncInputs(_value);
      return;
    }
    _setTime(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showSpinner)
          SizedBox(
            height: 132,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeWheel(
                  key: Key('${widget.keyPrefix}-hour-wheel'),
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
                  key: Key('${widget.keyPrefix}-minute-wheel'),
                  controller: _minuteController,
                  count: 60,
                  label: material.timePickerMinuteLabel,
                  onChanged: (value) => _setTime(minute: value),
                ),
              ],
            ),
          ),
        if (widget.showDirectInput)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeTextField(
                key: Key('${widget.keyPrefix}-hour-input'),
                controller: _hourTextController,
                label: material.timePickerHourLabel,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(':'),
              ),
              _buildTimeTextField(
                key: Key('${widget.keyPrefix}-minute-input'),
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
                key: Key('adjust-${widget.keyPrefix}-hour-$hours'),
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
            for (final minutes in const [-10, -1, 1, 10])
              Tooltip(
                message: minutes < 0
                    ? loc.sleepAdjustEarlier(-minutes)
                    : loc.sleepAdjustLater(minutes),
                child: OutlinedButton(
                  key: Key('adjust-${widget.keyPrefix}-time-$minutes'),
                  onPressed: _canAdjust(Duration(minutes: minutes))
                      ? () => _adjust(Duration(minutes: minutes))
                      : null,
                  child: Text(
                    '${minutes > 0 ? '+' : '−'}'
                    '${loc.sleepDurationMinutes(minutes.abs())}',
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
  }) => SizedBox(
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
  Widget build(BuildContext context) => Semantics(
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

DateTime truncateToMinute(DateTime value) =>
    DateTime(value.year, value.month, value.day, value.hour, value.minute);

DateTime earliestSelectableMinute(DateTime value) {
  final minute = truncateToMinute(value);
  return minute.isBefore(value)
      ? minute.add(const Duration(minutes: 1))
      : minute;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
