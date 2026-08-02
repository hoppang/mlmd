import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../repositories/task_repository.dart';
import '../domain/care_task_model.dart';

class TaskItemPair {
  const TaskItemPair({required this.task, required this.occurrence});

  final CareTask task;
  final CareTaskOccurrence occurrence;
}

class TaskListState {
  const TaskListState({required this.selectedDate, required this.items});

  final DateTime selectedDate;
  final List<TaskItemPair> items;

  List<TaskItemPair> get dueItems => items
      .where(
        (item) =>
            item.occurrence.computedStatusAt(DateTime.now()) ==
                TaskStatus.due &&
            !item.occurrence.isDone,
      )
      .toList();

  List<TaskItemPair> get scheduledItems => items
      .where(
        (item) =>
            item.occurrence.computedStatusAt(DateTime.now()) ==
                TaskStatus.scheduled &&
            !item.occurrence.isDone,
      )
      .toList();

  List<TaskItemPair> get completedItems =>
      items.where((item) => item.occurrence.isCompleted).toList();

  List<TaskItemPair> get skippedItems =>
      items.where((item) => item.occurrence.isSkipped).toList();
}

class TaskNotifier extends Notifier<TaskListState> {
  @override
  TaskListState build() {
    final now = DateTime.now();
    return TaskListState(selectedDate: now, items: _fetchItemsForDate(now));
  }

  void selectDate(DateTime date) {
    state = TaskListState(selectedDate: date, items: _fetchItemsForDate(date));
  }

  void refresh() {
    selectDate(state.selectedDate);
  }

  CareTask createTask({
    required String title,
    String childId = '',
    String? recurrenceRule,
    String? assignedToAuthorProfileId,
    TaskNotificationMode notificationMode = TaskNotificationMode.inAppOnly,
    String? linkedCategory,
    String? linkedEventTemplateJson,
    required DateTime firstScheduledAt,
  }) {
    final taskRepo = ref.read(taskRepositoryProvider);
    final task = taskRepo.createTask(
      title: title,
      childId: childId,
      recurrenceRule: recurrenceRule,
      assignedToAuthorProfileId: assignedToAuthorProfileId,
      notificationMode: notificationMode,
      linkedCategory: linkedCategory,
      linkedEventTemplateJson: linkedEventTemplateJson,
      firstScheduledAt: firstScheduledAt,
    );
    refresh();
    return task;
  }

  CareTaskOccurrence completeOccurrence({
    required String occurrenceId,
    DateTime? completedAt,
    String? authorProfileId,
    String? deviceProfileId,
    bool createLinkedEvent = true,
  }) {
    final taskRepo = ref.read(taskRepositoryProvider);
    final occurrence = taskRepo.completeOccurrence(
      occurrenceId: occurrenceId,
      completedAt: completedAt,
      authorProfileId: authorProfileId,
      deviceProfileId: deviceProfileId,
      createLinkedEvent: createLinkedEvent,
    );
    refresh();
    return occurrence;
  }

  CareTaskOccurrence skipOccurrence(String occurrenceId) {
    final taskRepo = ref.read(taskRepositoryProvider);
    final occurrence = taskRepo.skipOccurrence(occurrenceId);
    refresh();
    return occurrence;
  }

  CareTaskOccurrence undoOccurrenceCompletion(String occurrenceId) {
    final taskRepo = ref.read(taskRepositoryProvider);
    final occurrence = taskRepo.undoOccurrenceCompletion(occurrenceId);
    refresh();
    return occurrence;
  }

  List<TaskItemPair> _fetchItemsForDate(DateTime date) {
    final taskRepo = ref.read(taskRepositoryProvider);
    final occurrences = taskRepo.getOccurrencesForDate(date);

    final pairs = <TaskItemPair>[];
    for (final occurrence in occurrences) {
      final task = taskRepo.getTaskById(occurrence.taskId);
      if (task != null) {
        pairs.add(TaskItemPair(task: task, occurrence: occurrence));
      }
    }
    return pairs;
  }
}

final taskNotifierProvider = NotifierProvider<TaskNotifier, TaskListState>(
  TaskNotifier.new,
  dependencies: [taskRepositoryProvider],
);
