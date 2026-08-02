enum TaskStatus {
  scheduled,
  due,
  completed,
  skipped;

  static TaskStatus fromString(String value) {
    switch (value) {
      case 'due':
        return TaskStatus.due;
      case 'completed':
        return TaskStatus.completed;
      case 'skipped':
        return TaskStatus.skipped;
      case 'scheduled':
      default:
        return TaskStatus.scheduled;
    }
  }

  String toDbString() => name;
}

enum TaskNotificationMode {
  inAppOnly,
  quietToAssignee;

  static TaskNotificationMode fromString(String value) {
    switch (value) {
      case 'quietToAssignee':
        return TaskNotificationMode.quietToAssignee;
      case 'inAppOnly':
      default:
        return TaskNotificationMode.inAppOnly;
    }
  }

  String toDbString() => name;
}

class CareTask {
  CareTask({
    required this.taskId,
    this.childId = '',
    required this.title,
    this.recurrenceRule,
    this.assignedToAuthorProfileId,
    this.notificationMode = TaskNotificationMode.inAppOnly,
    this.linkedCategory,
    this.linkedEventTemplateJson,
    required this.createdAt,
    this.archivedAt,
    required this.createdByAuthorProfileId,
    required this.createdByDeviceProfileId,
  });

  final String taskId;
  final String childId;
  final String title;
  final String? recurrenceRule;
  final String? assignedToAuthorProfileId;
  final TaskNotificationMode notificationMode;
  final String? linkedCategory;
  final String? linkedEventTemplateJson;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final String createdByAuthorProfileId;
  final String createdByDeviceProfileId;

  bool get isArchived => archivedAt != null;
  bool get isAssignedToAnyone =>
      assignedToAuthorProfileId == null || assignedToAuthorProfileId!.isEmpty;
}

class CareTaskOccurrence {
  CareTaskOccurrence({
    required this.occurrenceId,
    required this.taskId,
    required this.scheduledAt,
    this.status = TaskStatus.scheduled,
    this.completedAt,
    this.completedByAuthorProfileId,
    this.completedOnDeviceProfileId,
    this.linkedRecordId,
  });

  final String occurrenceId;
  final String taskId;
  final DateTime scheduledAt;
  final TaskStatus status;
  final DateTime? completedAt;
  final String? completedByAuthorProfileId;
  final String? completedOnDeviceProfileId;
  final String? linkedRecordId;

  bool get isCompleted => status == TaskStatus.completed;
  bool get isSkipped => status == TaskStatus.skipped;
  bool get isDone => isCompleted || isSkipped;

  TaskStatus computedStatusAt(DateTime now) {
    if (isDone) return status;
    if (now.isAfter(scheduledAt) || now.isAtSameMomentAs(scheduledAt)) {
      return TaskStatus.due;
    }
    return TaskStatus.scheduled;
  }

  int getMinutesOverdueAt(DateTime now) {
    if (now.isBefore(scheduledAt)) return 0;
    return now.difference(scheduledAt).inMinutes;
  }
}
