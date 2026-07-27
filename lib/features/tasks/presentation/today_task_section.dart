import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/task_notifier.dart';
import 'care_task_card.dart';
import 'care_task_form_dialog.dart';

class TodayTaskSection extends ConsumerWidget {
  const TodayTaskSection({
    super.key,
    required this.selectedDate,
  });

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskNotifierProvider);
    final notifier = ref.read(taskNotifierProvider.notifier);

    final dueItems = taskState.dueItems;
    final scheduledItems = taskState.scheduledItems;
    final completedItems = taskState.completedItems;
    final skippedItems = taskState.skippedItems;

    final hasAnyTasks = taskState.items.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.teal),
                  SizedBox(width: 6),
                  Text(
                    '오늘 할 일',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  CareTaskFormDialog.show(context, initialDate: selectedDate);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('할 일 추가'),
              ),
            ],
          ),
        ),

        if (!hasAnyTasks)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Text(
                '예정된 할 일이 없습니다.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),

        // 1. 지금 할 일 (Due tasks)
        if (dueItems.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 4, bottom: 4),
            child: Text(
              '지금 할 일',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          ...dueItems.map((item) => CareTaskCard(
                task: item.task,
                occurrence: item.occurrence,
                onComplete: () => _handleComplete(context, notifier, item),
                onSkip: () => notifier.skipOccurrence(item.occurrence.occurrenceId),
                onUndo: () => notifier.undoOccurrenceCompletion(item.occurrence.occurrenceId),
              )),
        ],

        // 2. 다음 할 일 (Scheduled tasks)
        if (scheduledItems.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text(
              '다음 할 일',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          ...scheduledItems.map((item) => CareTaskCard(
                task: item.task,
                occurrence: item.occurrence,
                onComplete: () => _handleComplete(context, notifier, item),
                onSkip: () => notifier.skipOccurrence(item.occurrence.occurrenceId),
                onUndo: () => notifier.undoOccurrenceCompletion(item.occurrence.occurrenceId),
              )),
        ],

        // 3. 완료 / 건너뛴 할 일 (Completed / Skipped)
        if (completedItems.isNotEmpty || skippedItems.isNotEmpty) ...[
          ExpansionTile(
            key: const ValueKey('completed_tasks_expansion_tile'),
            title: Text(
              '완료 및 건너뛴 할 일 (${completedItems.length + skippedItems.length}개)',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            children: [
              ...completedItems.map((item) => CareTaskCard(
                    task: item.task,
                    occurrence: item.occurrence,
                    onComplete: () {},
                    onSkip: () {},
                    onUndo: () => notifier.undoOccurrenceCompletion(item.occurrence.occurrenceId),
                  )),
              ...skippedItems.map((item) => CareTaskCard(
                    task: item.task,
                    occurrence: item.occurrence,
                    onComplete: () {},
                    onSkip: () {},
                    onUndo: () => notifier.undoOccurrenceCompletion(item.occurrence.occurrenceId),
                  )),
            ],
          ),
        ],
      ],
    );
  }

  void _handleComplete(
    BuildContext context,
    TaskNotifier notifier,
    TaskItemPair item,
  ) {
    final occurrence = notifier.completeOccurrence(
      occurrenceId: item.occurrence.occurrenceId,
    );

    final hasLinkedRecord = occurrence.linkedRecordId != null;
    final message = hasLinkedRecord
        ? '${item.task.title} 기록을 완료하고 이벤트를 생성했어요'
        : '${item.task.title} 할 일을 완료했어요';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: '실행 취소',
          onPressed: () {
            notifier.undoOccurrenceCompletion(item.occurrence.occurrenceId);
          },
        ),
      ),
    );
  }
}
