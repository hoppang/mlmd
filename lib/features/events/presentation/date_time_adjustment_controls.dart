import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';

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
    this.onTab,
  });

  static const itemExtent = 36.0;
  static const viewportHeight = itemExtent * 5;

  final FixedExtentScrollController controller;
  final int count;
  final int value;
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
      _inputController.text = _twoDigits(widget.value);
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
    if (value != null && value >= 0 && value < widget.count) {
      widget.controller.jumpToItem(value);
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
                    onSelectedItemChanged: widget.onChanged,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.count,
                      builder: (context, index) => Center(
                        child: index == widget.value && _editing
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
                                      LengthLimitingTextInputFormatter(2),
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
                                key: index == widget.value
                                    ? widget.selectedKey
                                    : null,
                                behavior: HitTestBehavior.opaque,
                                onTap: index == widget.value
                                    ? _startEditing
                                    : null,
                                child: SizedBox(
                                  width: 64,
                                  height: _TimeWheel.itemExtent,
                                  child: Center(
                                    child: Text(
                                      _twoDigits(index),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                ),
                              ),
                      ),
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

String _twoDigits(int value) => value.toString().padLeft(2, '0');
