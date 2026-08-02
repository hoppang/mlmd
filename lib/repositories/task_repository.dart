import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/objectbox_helper.dart';
import '../features/sharing/application/family_sync_payloads.dart';
import '../features/sharing/domain/family_sync_models.dart';
import '../features/tasks/domain/care_task_model.dart';
import '../models/activity_entity.dart';
import '../models/care_task_entity.dart';
import '../models/care_task_occurrence_entity.dart';
import '../objectbox.g.dart';
import 'family_sync_repository.dart';
import 'profile_repository.dart';

abstract interface class TaskRepository {
  List<CareTask> getTasks({bool includeArchived = false});
  CareTask? getTaskById(String taskId);

  CareTask createTask({
    required String title,
    String childId = '',
    String? recurrenceRule,
    String? assignedToAuthorProfileId,
    TaskNotificationMode notificationMode = TaskNotificationMode.inAppOnly,
    String? linkedCategory,
    String? linkedEventTemplateJson,
    required DateTime firstScheduledAt,
  });

  CareTask updateTask({
    required String taskId,
    required String title,
    String? recurrenceRule,
    String? assignedToAuthorProfileId,
    TaskNotificationMode? notificationMode,
    String? linkedCategory,
    String? linkedEventTemplateJson,
  });

  void archiveTask(String taskId);

  List<CareTaskOccurrence> getOccurrencesForDate(DateTime date);

  CareTaskOccurrence completeOccurrence({
    required String occurrenceId,
    DateTime? completedAt,
    String? authorProfileId,
    String? deviceProfileId,
    bool createLinkedEvent = true,
  });

  CareTaskOccurrence skipOccurrence(String occurrenceId);

  CareTaskOccurrence undoOccurrenceCompletion(String occurrenceId);
}

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(
    this._objectBox,
    this._profileRepository, {
    FamilySyncRepository? familySyncRepository,
  }) : // Public name keeps construction sites independent of the field name.
       // ignore: prefer_initializing_formals
       _familySyncRepository = familySyncRepository;

  static const _uuid = Uuid();
  final ObjectBoxHelper _objectBox;
  final ProfileRepository _profileRepository;
  final FamilySyncRepository? _familySyncRepository;

  @override
  List<CareTask> getTasks({bool includeArchived = false}) {
    final entities = _objectBox.careTaskBox.getAll();
    return entities
        .where((e) => includeArchived || e.archivedAt == null)
        .map(_toDomainTask)
        .toList();
  }

  @override
  CareTask? getTaskById(String taskId) {
    final query = _objectBox.careTaskBox
        .query(CareTaskEntity_.taskId.equals(taskId))
        .build();
    final entity = query.findFirst();
    query.close();
    return entity != null ? _toDomainTask(entity) : null;
  }

  @override
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
    final source = _profileRepository.requireCurrentSource();
    final taskId = _uuid.v4();
    final now = DateTime.now();

    final taskEntity = CareTaskEntity(
      taskId: taskId,
      childId: childId,
      title: title.trim(),
      recurrenceRule: recurrenceRule,
      assignedToAuthorProfileId: assignedToAuthorProfileId,
      notificationMode: notificationMode.toDbString(),
      linkedCategory: linkedCategory,
      linkedEventTemplateJson: linkedEventTemplateJson,
      createdAt: now,
      createdByAuthorProfileId: source.authorProfileId,
      createdByDeviceProfileId: source.deviceProfileId,
    );

    final occurrenceId = _uuid.v4();
    final occurrenceEntity = CareTaskOccurrenceEntity(
      occurrenceId: occurrenceId,
      taskId: taskId,
      scheduledAt: firstScheduledAt,
      status: TaskStatus.scheduled.toDbString(),
    );

    _objectBox.store.runInTransaction(TxMode.write, () {
      _objectBox.careTaskBox.put(taskEntity);
      _objectBox.careTaskOccurrenceBox.put(occurrenceEntity);
    });
    _queueTask(taskEntity, SyncOperation.create, now);
    _queueOccurrence(occurrenceEntity, SyncOperation.create, firstScheduledAt);

    return _toDomainTask(taskEntity);
  }

  @override
  CareTask updateTask({
    required String taskId,
    required String title,
    String? recurrenceRule,
    String? assignedToAuthorProfileId,
    TaskNotificationMode? notificationMode,
    String? linkedCategory,
    String? linkedEventTemplateJson,
  }) {
    final query = _objectBox.careTaskBox
        .query(CareTaskEntity_.taskId.equals(taskId))
        .build();
    final entity = query.findFirst();
    query.close();

    if (entity == null) {
      throw StateError('Task with id $taskId does not exist.');
    }

    entity.title = title.trim();
    entity.recurrenceRule = recurrenceRule;
    entity.assignedToAuthorProfileId = assignedToAuthorProfileId;
    if (notificationMode != null) {
      entity.notificationMode = notificationMode.toDbString();
    }
    entity.linkedCategory = linkedCategory;
    entity.linkedEventTemplateJson = linkedEventTemplateJson;

    _objectBox.careTaskBox.put(entity);
    _queueTask(entity, SyncOperation.update, DateTime.now());
    return _toDomainTask(entity);
  }

  @override
  void archiveTask(String taskId) {
    final query = _objectBox.careTaskBox
        .query(CareTaskEntity_.taskId.equals(taskId))
        .build();
    final entity = query.findFirst();
    query.close();

    if (entity != null) {
      entity.archivedAt = DateTime.now();
      _objectBox.careTaskBox.put(entity);
      _queueTask(entity, SyncOperation.delete, entity.archivedAt!);
    }
  }

  @override
  List<CareTaskOccurrence> getOccurrencesForDate(DateTime date) {
    _ensureOccurrencesGeneratedForDate(date);

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final query = _objectBox.careTaskOccurrenceBox
        .query(
          CareTaskOccurrenceEntity_.scheduledAt.betweenDate(
            startOfDay,
            endOfDay,
          ),
        )
        .build();
    final entities = query.find();
    query.close();

    entities.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return entities.map(_toDomainOccurrence).toList();
  }

  @override
  CareTaskOccurrence completeOccurrence({
    required String occurrenceId,
    DateTime? completedAt,
    String? authorProfileId,
    String? deviceProfileId,
    bool createLinkedEvent = true,
  }) {
    final query = _objectBox.careTaskOccurrenceBox
        .query(CareTaskOccurrenceEntity_.occurrenceId.equals(occurrenceId))
        .build();
    final occurrenceEntity = query.findFirst();
    query.close();

    if (occurrenceEntity == null) {
      throw StateError('Occurrence with id $occurrenceId does not exist.');
    }

    final task = getTaskById(occurrenceEntity.taskId);
    if (task == null) {
      throw StateError('Associated task missing for occurrence $occurrenceId.');
    }

    final source = _profileRepository.requireCurrentSource();
    final finalCompletedAt = completedAt ?? DateTime.now();
    final finalAuthorId = authorProfileId ?? source.authorProfileId;
    final finalDeviceId = deviceProfileId ?? source.deviceProfileId;

    String? linkedRecordId;
    ActivityEntity? linkedActivity;

    _objectBox.store.runInTransaction(TxMode.write, () {
      if (createLinkedEvent &&
          task.linkedCategory != null &&
          task.linkedCategory!.isNotEmpty) {
        final recordId = _uuid.v4();
        final details = task.title;

        final activity = ActivityEntity(
          recordId: recordId,
          revision: 1,
          type: task.linkedCategory!,
          time: finalCompletedAt,
          timePrecision: ActivityEntity.timePrecisionExact,
          details: details,
          structuredDataJson: task.linkedEventTemplateJson,
          lastModified: DateTime.now(),
          createdAt: DateTime.now(),
          createdByAuthorProfileId: finalAuthorId,
          createdByDeviceProfileId: finalDeviceId,
        );

        _objectBox.activityBox.put(activity);
        linkedRecordId = recordId;
        linkedActivity = activity;
      }

      occurrenceEntity
        ..status = TaskStatus.completed.toDbString()
        ..completedAt = finalCompletedAt
        ..completedByAuthorProfileId = finalAuthorId
        ..completedOnDeviceProfileId = finalDeviceId
        ..linkedRecordId = linkedRecordId;

      _objectBox.careTaskOccurrenceBox.put(occurrenceEntity);
    });
    if (linkedActivity != null) {
      _queueActivity(linkedActivity!, SyncOperation.create);
    }
    _queueOccurrence(occurrenceEntity, SyncOperation.update, finalCompletedAt);

    return _toDomainOccurrence(occurrenceEntity);
  }

  @override
  CareTaskOccurrence skipOccurrence(String occurrenceId) {
    final query = _objectBox.careTaskOccurrenceBox
        .query(CareTaskOccurrenceEntity_.occurrenceId.equals(occurrenceId))
        .build();
    final occurrenceEntity = query.findFirst();
    query.close();

    if (occurrenceEntity == null) {
      throw StateError('Occurrence with id $occurrenceId does not exist.');
    }

    occurrenceEntity.status = TaskStatus.skipped.toDbString();
    _objectBox.careTaskOccurrenceBox.put(occurrenceEntity);
    _queueOccurrence(occurrenceEntity, SyncOperation.update, DateTime.now());

    return _toDomainOccurrence(occurrenceEntity);
  }

  @override
  CareTaskOccurrence undoOccurrenceCompletion(String occurrenceId) {
    final query = _objectBox.careTaskOccurrenceBox
        .query(CareTaskOccurrenceEntity_.occurrenceId.equals(occurrenceId))
        .build();
    final occurrenceEntity = query.findFirst();
    query.close();

    if (occurrenceEntity == null) {
      throw StateError('Occurrence with id $occurrenceId does not exist.');
    }

    ActivityEntity? removedActivity;
    _objectBox.store.runInTransaction(TxMode.write, () {
      if (occurrenceEntity.linkedRecordId != null) {
        final activityQuery = _objectBox.activityBox
            .query(
              ActivityEntity_.recordId.equals(occurrenceEntity.linkedRecordId!),
            )
            .build();
        final activity = activityQuery.findFirst();
        activityQuery.close();

        if (activity != null) {
          removedActivity = activity;
          _objectBox.activityBox.remove(activity.id);
        }
        occurrenceEntity.linkedRecordId = null;
      }

      final now = DateTime.now();
      occurrenceEntity.status = occurrenceEntity.scheduledAt.isBefore(now)
          ? TaskStatus.due.toDbString()
          : TaskStatus.scheduled.toDbString();
      occurrenceEntity.completedAt = null;
      occurrenceEntity.completedByAuthorProfileId = null;
      occurrenceEntity.completedOnDeviceProfileId = null;

      _objectBox.careTaskOccurrenceBox.put(occurrenceEntity);
    });
    if (removedActivity != null) {
      _queueActivity(removedActivity!, SyncOperation.delete);
    }
    _queueOccurrence(occurrenceEntity, SyncOperation.update, DateTime.now());

    return _toDomainOccurrence(occurrenceEntity);
  }

  void _ensureOccurrencesGeneratedForDate(DateTime date) {
    final activeTasks = _objectBox.careTaskBox
        .getAll()
        .where(
          (t) =>
              t.archivedAt == null &&
              t.recurrenceRule != null &&
              t.recurrenceRule!.isNotEmpty,
        )
        .toList();

    if (activeTasks.isEmpty) return;

    final targetDateStart = DateTime(date.year, date.month, date.day);
    final targetDateEnd = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    );

    final generated = <CareTaskOccurrenceEntity>[];
    _objectBox.store.runInTransaction(TxMode.write, () {
      for (final task in activeTasks) {
        final existingQuery = _objectBox.careTaskOccurrenceBox
            .query(
              CareTaskOccurrenceEntity_.taskId
                  .equals(task.taskId)
                  .and(
                    CareTaskOccurrenceEntity_.scheduledAt.betweenDate(
                      targetDateStart,
                      targetDateEnd,
                    ),
                  ),
            )
            .build();
        final existing = existingQuery.find();
        existingQuery.close();

        if (existing.isNotEmpty) continue;

        // Generate occurrence for target date based on recurrence rule
        final scheduledTime = _calculateScheduledTimeForDate(task, date);
        if (scheduledTime != null) {
          final occurrence = CareTaskOccurrenceEntity(
            occurrenceId: _uuid.v4(),
            taskId: task.taskId,
            scheduledAt: scheduledTime,
            status: TaskStatus.scheduled.toDbString(),
          );
          _objectBox.careTaskOccurrenceBox.put(occurrence);
          generated.add(occurrence);
        }
      }
    });
    for (final occurrence in generated) {
      _queueOccurrence(
        occurrence,
        SyncOperation.create,
        occurrence.scheduledAt,
      );
    }
  }

  DateTime? _calculateScheduledTimeForDate(
    CareTaskEntity task,
    DateTime targetDate,
  ) {
    final rule = task.recurrenceRule ?? '';
    if (rule == 'daily') {
      final initialQuery = _objectBox.careTaskOccurrenceBox
          .query(CareTaskOccurrenceEntity_.taskId.equals(task.taskId))
          .build();
      final occurrences = initialQuery.find();
      initialQuery.close();

      final firstScheduled = occurrences.isNotEmpty
          ? occurrences.first.scheduledAt
          : task.createdAt;

      return DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        firstScheduled.hour,
        firstScheduled.minute,
      );
    }
    return null;
  }

  CareTask _toDomainTask(CareTaskEntity e) {
    return CareTask(
      taskId: e.taskId,
      childId: e.childId,
      title: e.title,
      recurrenceRule: e.recurrenceRule,
      assignedToAuthorProfileId: e.assignedToAuthorProfileId,
      notificationMode: TaskNotificationMode.fromString(e.notificationMode),
      linkedCategory: e.linkedCategory,
      linkedEventTemplateJson: e.linkedEventTemplateJson,
      createdAt: e.createdAt,
      archivedAt: e.archivedAt,
      createdByAuthorProfileId: e.createdByAuthorProfileId,
      createdByDeviceProfileId: e.createdByDeviceProfileId,
    );
  }

  CareTaskOccurrence _toDomainOccurrence(CareTaskOccurrenceEntity e) {
    return CareTaskOccurrence(
      occurrenceId: e.occurrenceId,
      taskId: e.taskId,
      scheduledAt: e.scheduledAt,
      status: TaskStatus.fromString(e.status),
      completedAt: e.completedAt,
      completedByAuthorProfileId: e.completedByAuthorProfileId,
      completedOnDeviceProfileId: e.completedOnDeviceProfileId,
      linkedRecordId: e.linkedRecordId,
    );
  }

  void _queueTask(
    CareTaskEntity task,
    SyncOperation operation,
    DateTime occurredAt,
  ) {
    _familySyncRepository?.enqueue(
      entityType: FamilySyncPayloads.careTask,
      entityId: task.taskId,
      entityRevision: FamilySyncPayloads.revisionAt(occurredAt),
      operation: operation,
      payload: FamilySyncPayloads.forTask(task),
      occurredAt: occurredAt,
    );
  }

  void _queueOccurrence(
    CareTaskOccurrenceEntity occurrence,
    SyncOperation operation,
    DateTime occurredAt,
  ) {
    _familySyncRepository?.enqueue(
      entityType: FamilySyncPayloads.careTaskOccurrence,
      entityId: occurrence.occurrenceId,
      entityRevision: FamilySyncPayloads.revisionAt(occurredAt),
      operation: operation,
      payload: FamilySyncPayloads.forOccurrence(occurrence),
      occurredAt: occurredAt,
    );
  }

  void _queueActivity(ActivityEntity activity, SyncOperation operation) {
    final recordId = activity.recordId;
    if (recordId == null) return;
    _familySyncRepository?.enqueue(
      entityType: FamilySyncPayloads.activity,
      entityId: recordId,
      entityRevision: operation == SyncOperation.delete
          ? activity.revision + 1
          : activity.revision,
      operation: operation,
      payload: FamilySyncPayloads.forActivity(activity),
      occurredAt: activity.lastModified,
    );
  }
}

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) {
    return TaskRepositoryImpl(
      ref.watch(objectBoxProvider),
      ref.watch(profileRepositoryProvider),
      familySyncRepository: ref.watch(familySyncRepositoryProvider),
    );
  },
  dependencies: [
    objectBoxProvider,
    profileRepositoryProvider,
    familySyncRepositoryProvider,
  ],
);
