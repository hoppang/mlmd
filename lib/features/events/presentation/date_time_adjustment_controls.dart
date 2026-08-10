import 'package:flutter/gestures.dart';
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
    this.rollFutureTimeToPreviousDay = false,
    super.key,
  });

  final DateTime value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;
  final String keyPrefix;
  final bool rollFutureTimeToPreviousDay;

  @override
  State<DateTimeAdjustmentControls> createState() =>
      _DateTimeAdjustmentControlsState();
}

class SplitDecimalWheel extends StatefulWidget {
  const SplitDecimalWheel({
    required this.value,
    required this.minWhole,
    required this.maxWhole,
    required this.onChanged,
    required this.keyPrefix,
    this.enabled = true,
    super.key,
  });

  final double value;
  final int minWhole;
  final int maxWhole;
  final ValueChanged<double> onChanged;
  final String keyPrefix;
  final bool enabled;

  @override
  State<SplitDecimalWheel> createState() => _SplitDecimalWheelState();
}

class _SplitDecimalWheelState extends State<SplitDecimalWheel> {
  late final FixedExtentScrollController _wholeController;
  late final FixedExtentScrollController _tenthController;
  final _wholeWheelKey = GlobalKey<_TimeWheelState>();
  final _tenthWheelKey = GlobalKey<_TimeWheelState>();

  int get _whole =>
      widget.value.floor().clamp(widget.minWhole, widget.maxWhole);
  int get _tenth =>
      ((widget.value - widget.value.floor()) * 10).round().clamp(0, 9);

  @override
  void initState() {
    super.initState();
    _wholeController = FixedExtentScrollController(
      initialItem: _whole - widget.minWhole,
    );
    _tenthController = FixedExtentScrollController(initialItem: _tenth);
  }

  @override
  void didUpdateWidget(covariant SplitDecimalWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_wholeController.hasClients &&
        _wholeController.selectedItem != _whole - widget.minWhole) {
      _wholeController.jumpToItem(_whole - widget.minWhole);
    }
    if (_tenthController.hasClients &&
        _tenthController.selectedItem != _tenth) {
      _tenthController.jumpToItem(_tenth);
    }
  }

  @override
  void dispose() {
    _wholeController.dispose();
    _tenthController.dispose();
    super.dispose();
  }

  void _setValue({int? whole, int? tenth}) {
    if (!widget.enabled) return;
    final next = (whole ?? _whole) + (tenth ?? _tenth) / 10;
    if ((next - widget.value).abs() < 0.001) return;
    widget.onChanged(next);
  }

  void _moveToTenthInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tenthWheelKey.currentState?._startEditing();
    });
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.enabled,
    child: Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: SizedBox(
        height: _TimeWheel.viewportHeight + 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            KeyedSubtree(
              key: Key('${widget.keyPrefix}-whole-wheel'),
              child: _TimeWheel(
                key: _wholeWheelKey,
                controller: _wholeController,
                firstValue: widget.minWhole,
                count: widget.maxWhole - widget.minWhole + 1,
                value: _whole,
                label: '1℃',
                inputKey: Key('${widget.keyPrefix}-whole-wheel-input'),
                selectedKey: Key('${widget.keyPrefix}-whole-wheel-selected'),
                viewportKey: Key('${widget.keyPrefix}-whole-wheel-viewport'),
                onEditingStarted: () =>
                    _tenthWheelKey.currentState?._finishEditing(),
                onTab: _moveToTenthInput,
                onChanged: (value) => _setValue(whole: value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                '.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            KeyedSubtree(
              key: Key('${widget.keyPrefix}-tenth-wheel'),
              child: _TimeWheel(
                key: _tenthWheelKey,
                controller: _tenthController,
                count: 10,
                value: _tenth,
                digits: 1,
                label: '0.1℃',
                inputKey: Key('${widget.keyPrefix}-tenth-wheel-input'),
                selectedKey: Key('${widget.keyPrefix}-tenth-wheel-selected'),
                viewportKey: Key('${widget.keyPrefix}-tenth-wheel-viewport'),
                onEditingStarted: () =>
                    _wholeWheelKey.currentState?._finishEditing(),
                onChanged: (value) => _setValue(tenth: value),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DateTimeAdjustmentControlsState
    extends State<DateTimeAdjustmentControls> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  final _hourWheelKey = GlobalKey<_TimeWheelState>();
  final _minuteWheelKey = GlobalKey<_TimeWheelState>();

  DateTime get _value => truncateToMinute(widget.value);
  DateTime get _earliestValue => earliestSelectableMinute(widget.firstDate);
  DateTime get _latestValue => truncateToMinute(widget.lastDate);

  @override
  void initState() {
    super.initState();
    _hourController = FixedExtentScrollController(initialItem: _value.hour);
    _minuteController = FixedExtentScrollController(initialItem: _value.minute);
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
    super.dispose();
  }

  void _syncInputs(DateTime value) {
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

  void _startHourEditing() {
    _minuteWheelKey.currentState?._finishEditing();
  }

  void _startMinuteEditing() {
    _hourWheelKey.currentState?._finishEditing();
  }

  void _moveToMinuteInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _minuteWheelKey.currentState?._startEditing();
    });
  }

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _TimeWheel.viewportHeight + 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              KeyedSubtree(
                key: Key('${widget.keyPrefix}-hour-wheel'),
                child: _TimeWheel(
                  key: _hourWheelKey,
                  controller: _hourController,
                  count: 24,
                  value: _value.hour,
                  label: material.timePickerHourLabel,
                  inputKey: Key('${widget.keyPrefix}-hour-wheel-input'),
                  selectedKey: Key('${widget.keyPrefix}-hour-wheel-selected'),
                  viewportKey: Key('${widget.keyPrefix}-hour-wheel-viewport'),
                  onEditingStarted: _startHourEditing,
                  onTab: _moveToMinuteInput,
                  onChanged: (value) => _setTime(hour: value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Text(
                  ':',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              KeyedSubtree(
                key: Key('${widget.keyPrefix}-minute-wheel'),
                child: _TimeWheel(
                  key: _minuteWheelKey,
                  controller: _minuteController,
                  count: 60,
                  value: _value.minute,
                  label: material.timePickerMinuteLabel,
                  inputKey: Key('${widget.keyPrefix}-minute-wheel-input'),
                  selectedKey: Key('${widget.keyPrefix}-minute-wheel-selected'),
                  viewportKey: Key('${widget.keyPrefix}-minute-wheel-viewport'),
                  onEditingStarted: _startMinuteEditing,
                  onChanged: (value) => _setTime(minute: value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class InlineDateTimeEditor extends StatefulWidget {
  const InlineDateTimeEditor({
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    required this.keyPrefix,
    required this.label,
    required this.displayKey,
    this.enabled = true,
    super.key,
  });

  final DateTime value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;
  final String keyPrefix;
  final String label;
  final Key displayKey;
  final bool enabled;

  @override
  State<InlineDateTimeEditor> createState() => _InlineDateTimeEditorState();
}

class _InlineDateTimeEditorState extends State<InlineDateTimeEditor> {
  late DateTime _draftValue;
  late DateTime _initialValue;
  bool _editing = false;
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _draftValue = truncateToMinute(widget.value);
    _initialValue = _draftValue;
  }

  @override
  void didUpdateWidget(covariant InlineDateTimeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _editing = false;
      _showCalendar = false;
    }
    if (!_editing && widget.value != oldWidget.value) {
      _draftValue = truncateToMinute(widget.value);
      _initialValue = _draftValue;
    }
  }

  void _startEditing() {
    if (!widget.enabled) return;
    setState(() {
      _draftValue = truncateToMinute(widget.value);
      _initialValue = _draftValue;
      _editing = true;
      _showCalendar = false;
    });
  }

  void _setDate(DateTime date) {
    _applyDraft(
      DateTime(
        date.year,
        date.month,
        date.day,
        _draftValue.hour,
        _draftValue.minute,
      ),
    );
  }

  void _applyDraft(DateTime value) {
    if (!widget.enabled) return;
    final earliest = earliestSelectableMinute(widget.firstDate);
    final latest = truncateToMinute(widget.lastDate);
    final next = value.isBefore(earliest)
        ? earliest
        : value.isAfter(latest)
        ? latest
        : truncateToMinute(value);
    setState(() => _draftValue = next);
    widget.onChanged(next);
  }

  void _cancel() {
    widget.onChanged(_initialValue);
    setState(() {
      _draftValue = _initialValue;
      _editing = false;
      _showCalendar = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    if (!_editing) {
      return OutlinedButton.icon(
        key: widget.displayKey,
        onPressed: widget.enabled ? _startEditing : null,
        icon: const Icon(Icons.schedule),
        label: Text(
          '${widget.label} · '
          '${material.formatMediumDate(widget.value)} · '
          '${material.formatTimeOfDay(TimeOfDay.fromDateTime(widget.value))}',
        ),
      );
    }

    final loc = AppLocalizations.of(context)!;
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final selectedDate = DateUtils.dateOnly(_draftValue);
    final isToday = selectedDate == today;
    final isYesterday = selectedDate == yesterday;
    final firstDate = DateUtils.dateOnly(widget.firstDate);
    final lastDate = DateUtils.dateOnly(widget.lastDate);
    final calendarInitialDate = selectedDate.isBefore(firstDate)
        ? firstDate
        : selectedDate.isAfter(lastDate)
        ? lastDate
        : selectedDate;

    return Card(
      key: Key('${widget.keyPrefix}-date-time-editor'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  key: Key('${widget.keyPrefix}-date-today'),
                  label: Text(loc.searchToday),
                  selected: isToday,
                  onSelected: widget.enabled
                      ? (_) {
                          _setDate(today);
                          setState(() => _showCalendar = false);
                        }
                      : null,
                ),
                ChoiceChip(
                  key: Key('${widget.keyPrefix}-date-yesterday'),
                  label: Text(loc.sleepDateYesterday),
                  selected: isYesterday,
                  onSelected: widget.enabled
                      ? (_) {
                          _setDate(yesterday);
                          setState(() => _showCalendar = false);
                        }
                      : null,
                ),
                ChoiceChip(
                  key: Key('${widget.keyPrefix}-date-other'),
                  avatar: const Icon(Icons.calendar_month_outlined),
                  label: Text(loc.sleepDateOther),
                  selected: !isToday && !isYesterday,
                  onSelected: widget.enabled
                      ? (_) => setState(() => _showCalendar = !_showCalendar)
                      : null,
                ),
              ],
            ),
            if (_showCalendar) ...[
              const SizedBox(height: AppSpacing.sm),
              CalendarDatePicker(
                key: Key('${widget.keyPrefix}-date-calendar'),
                initialDate: calendarInitialDate,
                firstDate: firstDate,
                lastDate: lastDate,
                currentDate: DateTime.now(),
                onDateChanged: _setDate,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              material.formatMediumDate(_draftValue),
              key: Key('${widget.keyPrefix}-selected-date'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            DateTimeAdjustmentControls(
              key: Key('${widget.keyPrefix}-date-time-controls'),
              value: _draftValue,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onChanged: _applyDraft,
              keyPrefix: widget.keyPrefix,
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key('cancel-${widget.keyPrefix}-date-time'),
                onPressed: widget.enabled ? _cancel : null,
                child: Text(loc.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeWheel extends StatefulWidget {
  const _TimeWheel({
    required super.key,
    required this.controller,
    required this.count,
    required this.value,
    required this.label,
    required this.inputKey,
    required this.selectedKey,
    required this.viewportKey,
    required this.onEditingStarted,
    required this.onChanged,
    this.firstValue = 0,
    this.digits = 2,
    this.onTab,
  });

  static const itemExtent = 36.0;
  static const viewportHeight = itemExtent * 5;

  final FixedExtentScrollController controller;
  final int count;
  final int firstValue;
  final int value;
  final int digits;
  final String label;
  final Key inputKey;
  final Key selectedKey;
  final Key viewportKey;
  final VoidCallback onEditingStarted;
  final ValueChanged<int> onChanged;
  final VoidCallback? onTab;

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  late final TextEditingController _inputController;
  late final FocusNode _inputFocusNode;
  bool _editing = false;
  int? _pendingPointerTarget;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _inputFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    widget.onEditingStarted();
    setState(() {
      _editing = true;
      _inputController.text = _formatWheelValue(widget.value, widget.digits);
      _inputController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _inputController.text.length,
      );
    });
    _inputFocusNode.requestFocus();
  }

  void _finishEditing() {
    if (!_editing) return;
    final value = int.tryParse(_inputController.text);
    if (value != null &&
        value >= widget.firstValue &&
        value < widget.firstValue + widget.count) {
      widget.controller.jumpToItem(value - widget.firstValue);
      widget.onChanged(value);
    }
    setState(() => _editing = false);
  }

  KeyEventResult _handleInputKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.tab ||
        HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _finishEditing();
    widget.onTab?.call();
    return KeyEventResult.handled;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        !widget.controller.hasClients ||
        _pendingPointerTarget != null) {
      return;
    }
    final direction = event.scrollDelta.dy > 0 ? 1 : -1;
    _pendingPointerTarget = (widget.controller.selectedItem + direction).clamp(
      0,
      widget.count - 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.controller.hasClients) return;
      final target = _pendingPointerTarget;
      _pendingPointerTarget = null;
      if (target == null) return;
      widget.controller.animateToItem(
        target,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: SizedBox(
      width: 88,
      child: Column(
        children: [
          SizedBox(
            key: widget.viewportKey,
            height: _TimeWheel.viewportHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Container(
                    height: _TimeWheel.itemExtent,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                  ),
                ),
                Listener(
                  onPointerSignal: _handlePointerSignal,
                  child: ListWheelScrollView.useDelegate(
                    controller: widget.controller,
                    itemExtent: _TimeWheel.itemExtent,
                    physics: const FixedExtentScrollPhysics(),
                    diameterRatio: 1.5,
                    perspective: 0.004,
                    onSelectedItemChanged: (index) =>
                        widget.onChanged(index + widget.firstValue),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.count,
                      builder: (context, index) {
                        final itemValue = index + widget.firstValue;
                        return Center(
                          child: itemValue == widget.value && _editing
                              ? Focus(
                                  onKeyEvent: _handleInputKey,
                                  child: SizedBox(
                                    width: 64,
                                    child: TextField(
                                      key: widget.inputKey,
                                      controller: _inputController,
                                      focusNode: _inputFocusNode,
                                      autofocus: true,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(
                                          widget.digits,
                                        ),
                                      ],
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                      ),
                                      onSubmitted: (_) => _finishEditing(),
                                      onTapOutside: (_) => _finishEditing(),
                                    ),
                                  ),
                                )
                              : GestureDetector(
                                  key: itemValue == widget.value
                                      ? widget.selectedKey
                                      : null,
                                  behavior: HitTestBehavior.opaque,
                                  onTap: itemValue == widget.value
                                      ? _startEditing
                                      : null,
                                  child: SizedBox(
                                    width: 64,
                                    height: _TimeWheel.itemExtent,
                                    child: Center(
                                      child: Text(
                                        _formatWheelValue(
                                          itemValue,
                                          widget.digits,
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(widget.label, style: Theme.of(context).textTheme.labelSmall),
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

String _formatWheelValue(int value, int digits) =>
    value.toString().padLeft(digits, '0');
