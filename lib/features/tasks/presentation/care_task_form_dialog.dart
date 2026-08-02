import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/profile_repository.dart';
import '../application/task_notifier.dart';
import '../domain/care_task_model.dart';

class CareTaskFormDialog extends ConsumerStatefulWidget {
  const CareTaskFormDialog({super.key, this.initialDate});

  final DateTime? initialDate;

  static Future<void> show(BuildContext context, {DateTime? initialDate}) {
    return showDialog<void>(
      context: context,
      builder: (context) => CareTaskFormDialog(initialDate: initialDate),
    );
  }

  @override
  ConsumerState<CareTaskFormDialog> createState() => _CareTaskFormDialogState();
}

class _CareTaskFormDialogState extends ConsumerState<CareTaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  late DateTime _scheduledDate;
  TimeOfDay _scheduledTime = TimeOfDay.now();

  String? _selectedAssigneeAuthorId;
  TaskNotificationMode _notificationMode = TaskNotificationMode.inAppOnly;
  String? _recurrenceRule;
  String? _linkedCategory;

  @override
  void initState() {
    super.initState();
    _scheduledDate = widget.initialDate ?? DateTime.now();
    _scheduledTime = TimeOfDay.fromDateTime(_scheduledDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authorProfiles = ref.watch(authorProfileListProvider);

    return AlertDialog(
      title: const Text('Add Care Task'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Example: take medicine at 6:30 PM',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Scheduled time'),
                subtitle: Text(
                  '${_scheduledDate.year}-${_scheduledDate.month}-${_scheduledDate.day} '
                  '${_scheduledTime.format(context)}',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: _pickTime,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedAssigneeAuthorId,
                decoration: const InputDecoration(labelText: 'Assignee'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No assignee (default)'),
                  ),
                  ...authorProfiles.map(
                    (author) => DropdownMenuItem<String?>(
                      value: author.authorProfileId,
                      child: Text(author.nickname),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedAssigneeAuthorId = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Notification',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              RadioGroup<TaskNotificationMode>(
                groupValue: _notificationMode,
                onChanged: (val) {
                  if (val != null) setState(() => _notificationMode = val);
                },
                child: Column(
                  children: [
                    RadioListTile<TaskNotificationMode>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('App only (default)'),
                      value: TaskNotificationMode.inAppOnly,
                    ),
                    RadioListTile<TaskNotificationMode>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Quiet to assignee'),
                      value: TaskNotificationMode.quietToAssignee,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _recurrenceRule,
                decoration: const InputDecoration(labelText: 'Recurrence'),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('One time'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'daily',
                    child: Text('Daily'),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _recurrenceRule = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _linkedCategory,
                decoration: const InputDecoration(
                  labelText: 'Linked event',
                  helperText: 'A matching event will be created automatically.',
                ),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('None')),
                  DropdownMenuItem<String?>(
                    value: 'medication',
                    child: Text('Medication'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'temperature',
                    child: Text('Temperature'),
                  ),
                  DropdownMenuItem<String?>(value: 'bath', child: Text('Bath')),
                ],
                onChanged: (val) {
                  setState(() {
                    _linkedCategory = val;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (pickedTime != null) {
      setState(() {
        _scheduledTime = pickedTime;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final firstScheduledAt = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );

    ref
        .read(taskNotifierProvider.notifier)
        .createTask(
          title: _titleController.text.trim(),
          assignedToAuthorProfileId: _selectedAssigneeAuthorId,
          notificationMode: _notificationMode,
          recurrenceRule: _recurrenceRule,
          linkedCategory: _linkedCategory,
          firstScheduledAt: firstScheduledAt,
        );

    Navigator.of(context).pop();
  }
}
