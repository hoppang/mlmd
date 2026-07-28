import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/profile_repository.dart';
import '../application/task_notifier.dart';
import '../domain/care_task_model.dart';

class CareTaskFormDialog extends ConsumerStatefulWidget {
  const CareTaskFormDialog({
    super.key,
    this.initialDate,
  });

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
      title: const Text('새 할 일 추가'),
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
                  labelText: '할 일 제목',
                  hintText: '예: 오후 6:30 해열제 먹이기',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '제목을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('예정 시각'),
                subtitle: Text(
                  '${_scheduledDate.year}-${_scheduledDate.month}-${_scheduledDate.day} '
                  '${_scheduledTime.format(context)}',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: _pickTime,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _selectedAssigneeAuthorId,
                decoration: const InputDecoration(labelText: '담당자'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('누구나 (기본)'),
                  ),
                  ...authorProfiles.map((author) => DropdownMenuItem<String?>(
                        value: author.authorProfileId,
                        child: Text(author.nickname),
                      )),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedAssigneeAuthorId = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('알림 설정', style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<TaskNotificationMode>(
                contentPadding: EdgeInsets.zero,
                title: const Text('앱에서만 표시 (기본)'),
                value: TaskNotificationMode.inAppOnly,
                groupValue: _notificationMode,
                onChanged: (val) {
                  if (val != null) setState(() => _notificationMode = val);
                },
              ),
              RadioListTile<TaskNotificationMode>(
                contentPadding: EdgeInsets.zero,
                title: const Text('담당자에게 조용한 알림'),
                value: TaskNotificationMode.quietToAssignee,
                groupValue: _notificationMode,
                onChanged: (val) {
                  if (val != null) setState(() => _notificationMode = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _recurrenceRule,
                decoration: const InputDecoration(labelText: '반복 일정'),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('한 번만'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'daily',
                    child: Text('매일 반복'),
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
                value: _linkedCategory,
                decoration: const InputDecoration(
                  labelText: '실제 이벤트 연결',
                  helperText: '완료 시 관련 이벤트를 자동으로 생성합니다.',
                ),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('연결 없음 (일반 할 일)'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'medication',
                    child: Text('투약 (해열제 등)'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'temperature',
                    child: Text('체온 측정'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'bath',
                    child: Text('목욕'),
                  ),
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
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('저장'),
        ),
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

    ref.read(taskNotifierProvider.notifier).createTask(
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
