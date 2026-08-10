import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<DateTime?> showDatePickerPage({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => Navigator.of(context).push<DateTime>(
  MaterialPageRoute<DateTime>(
    fullscreenDialog: true,
    builder: (_) => _DatePickerPage(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  ),
);

Future<TimeOfDay?> showTimePickerPage({
  required BuildContext context,
  required TimeOfDay initialTime,
}) => Navigator.of(context).push<TimeOfDay>(
  MaterialPageRoute<TimeOfDay>(
    fullscreenDialog: true,
    builder: (_) => _TimePickerPage(initialTime: initialTime),
  ),
);

class _DatePickerPage extends StatefulWidget {
  const _DatePickerPage({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DatePickerPage> createState() => _DatePickerPageState();
}

class _DatePickerPageState extends State<_DatePickerPage> {
  late DateTime _value = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(material.datePickerHelpText),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          tooltip: material.closeButtonTooltip,
        ),
        actions: [
          TextButton(
            key: const Key('apply-date-picker-page'),
            onPressed: () => Navigator.pop(context, _value),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(material.saveButtonLabel),
          ),
        ],
      ),
      body: SafeArea(
        child: CalendarDatePicker(
          initialDate: widget.initialDate,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          onDateChanged: (value) => setState(() => _value = value),
        ),
      ),
    );
  }
}

class _TimePickerPage extends StatefulWidget {
  const _TimePickerPage({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_TimePickerPage> createState() => _TimePickerPageState();
}

class _TimePickerPageState extends State<_TimePickerPage> {
  late DateTime _value = DateTime(
    2000,
    1,
    1,
    widget.initialTime.hour,
    widget.initialTime.minute,
  );

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(material.timePickerDialHelpText),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          tooltip: material.closeButtonTooltip,
        ),
        actions: [
          TextButton(
            key: const Key('apply-time-picker-page'),
            onPressed: () => Navigator.pop(
              context,
              TimeOfDay(hour: _value.hour, minute: _value.minute),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(material.saveButtonLabel),
          ),
        ],
      ),
      body: SafeArea(
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          initialDateTime: _value,
          onDateTimeChanged: (value) => _value = value,
        ),
      ),
    );
  }
}
