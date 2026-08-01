import 'dart:convert';

import 'package:objectbox/objectbox.dart' hide SyncChange;

import '../../../data/objectbox_helper.dart';
import '../../../models/activity_entity.dart';
import '../../../models/attachment_entity.dart';
import '../../../models/author_profile_entity.dart';
import '../../../models/care_task_entity.dart';
import '../../../models/care_task_occurrence_entity.dart';
import '../../../models/diary_entity.dart';
import '../../../models/duplicate_review_edge_entity.dart';
import '../../../models/shared_custom_event_definition_entity.dart';
import '../../../repositories/custom_event_repository.dart';
import '../../attachments/domain/event_attachment.dart';
import 'family_sync_payloads.dart';
import '../domain/family_sync_models.dart';

class FamilySyncRemoteApplier {
  FamilySyncRemoteApplier(this._objectBox, this._customEvents);

  final ObjectBoxHelper _objectBox;
  final CustomEventRepository _customEvents;

  RemoteApplyResult call(SyncChange change) {
    if (change.familySpaceId != _customEvents.familySpaceId ||
        !_FamilySyncPayloadValidator.isValid(change)) {
      return const RemoteApplyResult.ignored();
    }
    try {
      switch (change.entityType) {
        case 'activity':
          return _applyActivity(change);
        case 'careTask':
          return _applyCareTask(change);
        case 'careTaskOccurrence':
          return _applyOccurrence(change);
        case 'authorProfile':
          return _applyAuthor(change);
        case 'attachmentMetadata':
          return _applyAttachment(change);
        case 'duplicateDecision':
          return _applyDuplicateDecision(change);
        case 'customEventDefinition':
          return _applyCustomEventDefinition(change);
        default:
          return const RemoteApplyResult.ignored();
      }
    } on FormatException {
      return const RemoteApplyResult.ignored();
    } on TypeError {
      return const RemoteApplyResult.ignored();
    }
  }

  RemoteApplyResult _applyActivity(SyncChange change) {
    if (change.operation == SyncOperation.delete) {
      final existing = _findActivity(change.entityId);
      if (existing == null) return const RemoteApplyResult.ignored();
      if (existing.revision > change.entityRevision) {
        return RemoteApplyResult.conflict(
          localRevision: existing.revision,
          localPayload: _activityPayload(existing),
        );
      }
      if (existing.revision >= change.entityRevision) {
        return const RemoteApplyResult.ignored();
      }
      _removeActivity(existing);
      return const RemoteApplyResult.applied();
    }

    final incoming = _activityFromPayload(change);
    final existing = _findActivity(incoming.recordId!);
    if (existing != null) {
      if (existing.revision > change.entityRevision) {
        return RemoteApplyResult.conflict(
          localRevision: existing.revision,
          localPayload: _activityPayload(existing),
        );
      }
      if (existing.revision >= change.entityRevision) {
        return const RemoteApplyResult.ignored();
      }
      incoming.id = existing.id;
    }
    _persistActivity(incoming);
    return const RemoteApplyResult.applied();
  }

  RemoteApplyResult _applyCareTask(SyncChange change) {
    final incoming = _careTaskFromPayload(change);
    final existing = _findCareTask(incoming.taskId);
    if (existing != null) {
      final localMoment = existing.archivedAt ?? existing.createdAt;
      final localRevision = FamilySyncPayloads.revisionAt(localMoment);
      if (localRevision > change.entityRevision) {
        return RemoteApplyResult.conflict(
          localRevision: localRevision,
          localPayload: _careTaskPayload(existing),
        );
      }
      if (localRevision == change.entityRevision) {
        return const RemoteApplyResult.ignored();
      }
      incoming.id = existing.id;
    }
    _objectBox.careTaskBox.put(incoming);
    return const RemoteApplyResult.applied();
  }

  RemoteApplyResult _applyOccurrence(SyncChange change) {
    final incoming = _occurrenceFromPayload(change);
    final existing = _findOccurrence(incoming.occurrenceId);
    if (existing != null) {
      final localMoment = existing.completedAt ?? existing.scheduledAt;
      final localRevision = FamilySyncPayloads.revisionAt(localMoment);
      if (localRevision > change.entityRevision) {
        return RemoteApplyResult.conflict(
          localRevision: localRevision,
          localPayload: _occurrencePayload(existing),
        );
      }
      if (localRevision == change.entityRevision) {
        return const RemoteApplyResult.ignored();
      }
      incoming.id = existing.id;
    }
    _objectBox.careTaskOccurrenceBox.put(incoming);
    return const RemoteApplyResult.applied();
  }

  RemoteApplyResult _applyAuthor(SyncChange change) {
    final incoming = _authorFromPayload(change);
    final existing = _findAuthor(incoming.authorProfileId);
    if (existing != null) {
      final localRevision = FamilySyncPayloads.revisionAt(existing.createdAt);
      if (localRevision > change.entityRevision) {
        return RemoteApplyResult.conflict(
          localRevision: localRevision,
          localPayload: _authorPayload(existing),
        );
      }
      if (localRevision == change.entityRevision) {
        return const RemoteApplyResult.ignored();
      }
      incoming.id = existing.id;
    }
    _objectBox.authorProfileBox.put(incoming);
    return const RemoteApplyResult.applied();
  }

  RemoteApplyResult _applyAttachment(SyncChange change) {
    final incoming = _attachmentFromPayload(change);
    final existing = _findAttachment(incoming.attachmentId);
    if (existing != null) {
      final localMoment = existing.deletedAt ?? existing.createdAt;
      final localRevision = FamilySyncPayloads.revisionAt(localMoment);
      if (localRevision > change.entityRevision) {
        return RemoteApplyResult.conflict(
          localRevision: localRevision,
          localPayload: _attachmentPayload(existing),
        );
      }
      if (localRevision == change.entityRevision) {
        return const RemoteApplyResult.ignored();
      }
      incoming.id = existing.id;
    }
    _attachmentBox.put(incoming);
    return const RemoteApplyResult.applied();
  }

  RemoteApplyResult _applyDuplicateDecision(SyncChange change) {
    final incoming = _duplicateFromPayload(change);
    final existing = _findDuplicate(incoming.pairKey);
    if (existing != null) {
      final localMoment =
          existing.resolvedAt ?? existing.deferredAt ?? existing.detectedAt;
      final localRevision = FamilySyncPayloads.revisionAt(localMoment);
      if (localRevision > change.entityRevision) {
        return RemoteApplyResult.conflict(
          localRevision: localRevision,
          localPayload: _duplicatePayload(existing),
        );
      }
      if (localRevision == change.entityRevision) {
        return const RemoteApplyResult.ignored();
      }
      incoming.id = existing.id;
    }
    _objectBox.duplicateReviewEdgeBox.put(incoming);
    return const RemoteApplyResult.applied();
  }

  RemoteApplyResult _applyCustomEventDefinition(SyncChange change) {
    final payload = change.payload;
    final incoming = SharedCustomEventDefinitionEntity(
      customEventTypeId: payload['customEventTypeId']! as String,
      familySpaceId: payload['familySpaceId']! as String,
      name: payload['name']! as String,
      revision: payload['revision']! as int,
      createdByAuthorProfileId: payload['createdByAuthorProfileId']! as String,
      createdByDeviceProfileId: payload['createdByDeviceProfileId']! as String,
      lastModifiedByAuthorProfileId:
          payload['lastModifiedByAuthorProfileId']! as String,
      lastModifiedByDeviceProfileId:
          payload['lastModifiedByDeviceProfileId']! as String,
      createdAt: DateTime.parse(payload['createdAt']! as String),
      updatedAt: DateTime.parse(payload['updatedAt']! as String),
      archivedAt: payload['archivedAt'] == null
          ? null
          : DateTime.parse(payload['archivedAt']! as String),
    );
    final local = _findCustomEventDefinition(incoming.customEventTypeId);
    if (local != null) {
      if (local.revision > incoming.revision) {
        return RemoteApplyResult.conflict(
          localRevision: local.revision,
          localPayload: _customEventPayload(local),
        );
      }
      if (local.revision >= incoming.revision) {
        return const RemoteApplyResult.ignored();
      }
      incoming.id = local.id;
    }
    _customEvents.applySharedDefinition(incoming);
    return const RemoteApplyResult.applied();
  }

  ActivityEntity? _findActivity(String? recordId) {
    if (recordId == null) return null;
    for (final item in _objectBox.activityBox.getAll()) {
      if (item.recordId == recordId) return item;
    }
    return null;
  }

  void _removeActivity(ActivityEntity activity) {
    final diary = activity.diary.target;
    if (diary != null) {
      diary.activities.remove(activity);
      _objectBox.diaryBox.put(diary);
    }
    _objectBox.activityBox.remove(activity.id);
  }

  void _persistActivity(ActivityEntity incoming) {
    _objectBox.store.runInTransaction(TxMode.write, () {
      final diary = _diaryForDate(incoming.time);
      incoming.diary.target = diary;
      _objectBox.activityBox.put(incoming);
      _objectBox.diaryBox.put(diary);
    });
  }

  DiaryEntity _diaryForDate(DateTime time) {
    final day = time.isUtc
        ? DateTime.utc(time.year, time.month, time.day)
        : DateTime(time.year, time.month, time.day);
    for (final diary in _objectBox.diaryBox.getAll()) {
      if (diary.recordId != null &&
          diary.date.year == day.year &&
          diary.date.month == day.month &&
          diary.date.day == day.day) {
        return diary;
      }
    }
    final diary = DiaryEntity(
      recordId: null,
      date: day,
      title: '',
      content: '',
      summary: '',
      lastModified: time,
      createdAt: time,
    );
    _objectBox.diaryBox.put(diary);
    return diary;
  }

  CareTaskEntity? _findCareTask(String taskId) {
    for (final item in _objectBox.careTaskBox.getAll()) {
      if (item.taskId == taskId) return item;
    }
    return null;
  }

  CareTaskOccurrenceEntity? _findOccurrence(String occurrenceId) {
    for (final item in _objectBox.careTaskOccurrenceBox.getAll()) {
      if (item.occurrenceId == occurrenceId) return item;
    }
    return null;
  }

  AuthorProfileEntity? _findAuthor(String authorProfileId) {
    for (final item in _objectBox.authorProfileBox.getAll()) {
      if (item.authorProfileId == authorProfileId) return item;
    }
    return null;
  }

  AttachmentEntity? _findAttachment(String attachmentId) {
    for (final item in _attachmentBox.getAll()) {
      if (item.attachmentId == attachmentId) return item;
    }
    return null;
  }

  DuplicateReviewEdgeEntity? _findDuplicate(String pairKey) {
    for (final item in _objectBox.duplicateReviewEdgeBox.getAll()) {
      if (item.pairKey == pairKey) return item;
    }
    return null;
  }

  SharedCustomEventDefinitionEntity? _findCustomEventDefinition(
    String customEventTypeId,
  ) {
    for (final item in _customEventBox.getAll()) {
      if (item.customEventTypeId == customEventTypeId) return item;
    }
    return null;
  }

  ActivityEntity _activityFromPayload(SyncChange change) {
    final payload = change.payload;
    return ActivityEntity(
      recordId: payload['recordId'] as String?,
      revision: payload['revision'] as int? ?? change.entityRevision,
      type: payload['type']! as String,
      time: DateTime.parse(payload['time']! as String),
      timePrecision: payload['timePrecision']! as int,
      details: payload['details']! as String,
      structuredDataJson: payload['structuredDataJson'] as String?,
      customEventTypeId: payload['customEventTypeId'] as String?,
      customEventNameSnapshot: payload['customEventNameSnapshot'] as String?,
      lastModified: DateTime.parse(payload['lastModified']! as String),
      createdAt: payload['createdAt'] == null
          ? null
          : DateTime.parse(payload['createdAt']! as String),
      createdByAuthorProfileId: payload['createdByAuthorProfileId'] as String?,
      createdByDeviceProfileId: payload['createdByDeviceProfileId'] as String?,
      lastModifiedByAuthorProfileId:
          payload['lastModifiedByAuthorProfileId'] as String?,
      lastModifiedByDeviceProfileId:
          payload['lastModifiedByDeviceProfileId'] as String?,
    );
  }

  CareTaskEntity _careTaskFromPayload(SyncChange change) {
    final payload = change.payload;
    return CareTaskEntity(
      taskId: payload['taskId']! as String,
      childId: payload['childId'] as String? ?? '',
      title: payload['title']! as String,
      recurrenceRule: payload['recurrenceRule'] as String?,
      assignedToAuthorProfileId:
          payload['assignedToAuthorProfileId'] as String?,
      notificationMode: payload['notificationMode'] as String? ?? 'inAppOnly',
      linkedCategory: payload['linkedCategory'] as String?,
      linkedEventTemplateJson: payload['linkedEventTemplateJson'] as String?,
      createdAt: DateTime.parse(payload['createdAt']! as String),
      archivedAt: payload['archivedAt'] == null
          ? null
          : DateTime.parse(payload['archivedAt']! as String),
      createdByAuthorProfileId:
          payload['createdByAuthorProfileId'] as String? ?? '',
      createdByDeviceProfileId:
          payload['createdByDeviceProfileId'] as String? ?? '',
    );
  }

  CareTaskOccurrenceEntity _occurrenceFromPayload(SyncChange change) {
    final payload = change.payload;
    return CareTaskOccurrenceEntity(
      occurrenceId: payload['occurrenceId']! as String,
      taskId: payload['taskId']! as String,
      scheduledAt: DateTime.parse(payload['scheduledAt']! as String),
      status: payload['status'] as String? ?? 'scheduled',
      completedAt: payload['completedAt'] == null
          ? null
          : DateTime.parse(payload['completedAt']! as String),
      completedByAuthorProfileId:
          payload['completedByAuthorProfileId'] as String?,
      completedOnDeviceProfileId:
          payload['completedOnDeviceProfileId'] as String?,
      linkedRecordId: payload['linkedRecordId'] as String?,
    );
  }

  AuthorProfileEntity _authorFromPayload(SyncChange change) {
    final payload = change.payload;
    return AuthorProfileEntity(
      authorProfileId: payload['authorProfileId']! as String,
      nickname: payload['nickname']! as String,
      colorValue: payload['colorValue']! as int,
      createdAt: DateTime.parse(payload['createdAt']! as String),
      // Device-local selection must never be controlled by a remote peer.
      isCurrent: false,
    );
  }

  AttachmentEntity _attachmentFromPayload(SyncChange change) {
    final payload = change.payload;
    final attachmentType = AttachmentType.values.firstWhere(
      (item) => item.name == payload['attachmentType'],
      orElse: () => AttachmentType.general,
    );
    final sourceKind = AttachmentSourceKind.values.firstWhere(
      (item) => item.name == payload['sourceKind'],
      orElse: () => AttachmentSourceKind.filePicker,
    );
    final attachment = EventAttachment(
      attachmentId: payload['attachmentId']! as String,
      recordId: payload['recordId']! as String,
      attachmentType: attachmentType,
      fileName: payload['fileName']! as String,
      mimeType: payload['mimeType']! as String,
      sourceKind: sourceKind,
      managedOriginalUri: 'sync-metadata://${change.entityId}',
      createdByAuthorProfileId: payload['createdByAuthorProfileId'] as String?,
      createdByDeviceProfileId: payload['createdByDeviceProfileId'] as String?,
      createdAt: DateTime.parse(payload['createdAt']! as String),
      deletedAt: payload['deletedAt'] == null
          ? null
          : DateTime.parse(payload['deletedAt']! as String),
      originalByteSize: payload['originalByteSize'] as int?,
      originalSha256: payload['originalSha256'] as String?,
      missingReason: payload['missingReason'] as String? ?? 'binary_not_shared',
    );
    return AttachmentEntity.fromDomain(attachment);
  }

  DuplicateReviewEdgeEntity _duplicateFromPayload(SyncChange change) {
    final payload = change.payload;
    return DuplicateReviewEdgeEntity(
      pairKey: payload['pairKey']! as String,
      recordAId: payload['recordAId']! as String,
      recordBId: payload['recordBId']! as String,
      status: payload['status']! as String,
      signatureA: payload['signatureA']! as String,
      signatureB: payload['signatureB']! as String,
      revisionA: payload['revisionA']! as int,
      revisionB: payload['revisionB']! as int,
      detectionReasonsJson: payload['detectionReasonsJson']! as String,
      detectedAt: DateTime.parse(payload['detectedAt']! as String),
      detectorVersion: payload['detectorVersion']! as String,
      representativeRecordId: payload['representativeRecordId'] as String?,
      logicalGroupId: payload['logicalGroupId'] as String?,
      deferredAt: payload['deferredAt'] == null
          ? null
          : DateTime.parse(payload['deferredAt']! as String),
      resolvedByAuthorProfileId:
          payload['resolvedByAuthorProfileId'] as String?,
      resolvedByDeviceProfileId:
          payload['resolvedByDeviceProfileId'] as String?,
      resolvedAt: payload['resolvedAt'] == null
          ? null
          : DateTime.parse(payload['resolvedAt']! as String),
    );
  }

  Map<String, Object?> _activityPayload(ActivityEntity activity) => {
    'recordId': activity.recordId,
    'revision': activity.revision,
    'type': activity.type,
    'time': activity.time.toUtc().toIso8601String(),
    'timePrecision': activity.timePrecision,
    'details': activity.details,
    'structuredDataJson': activity.structuredDataJson,
    'customEventTypeId': activity.customEventTypeId,
    'customEventNameSnapshot': activity.customEventNameSnapshot,
    'lastModified': activity.lastModified.toUtc().toIso8601String(),
    'createdAt': activity.createdAt?.toUtc().toIso8601String(),
    'createdByAuthorProfileId': activity.createdByAuthorProfileId,
    'createdByDeviceProfileId': activity.createdByDeviceProfileId,
    'lastModifiedByAuthorProfileId': activity.lastModifiedByAuthorProfileId,
    'lastModifiedByDeviceProfileId': activity.lastModifiedByDeviceProfileId,
  };

  Map<String, Object?> _careTaskPayload(CareTaskEntity entity) => {
    'taskId': entity.taskId,
    'childId': entity.childId,
    'title': entity.title,
    'recurrenceRule': entity.recurrenceRule,
    'assignedToAuthorProfileId': entity.assignedToAuthorProfileId,
    'notificationMode': entity.notificationMode,
    'linkedCategory': entity.linkedCategory,
    'linkedEventTemplateJson': entity.linkedEventTemplateJson,
    'createdAt': entity.createdAt.toUtc().toIso8601String(),
    'archivedAt': entity.archivedAt?.toUtc().toIso8601String(),
    'createdByAuthorProfileId': entity.createdByAuthorProfileId,
    'createdByDeviceProfileId': entity.createdByDeviceProfileId,
  };

  Map<String, Object?> _occurrencePayload(CareTaskOccurrenceEntity entity) => {
    'occurrenceId': entity.occurrenceId,
    'taskId': entity.taskId,
    'scheduledAt': entity.scheduledAt.toUtc().toIso8601String(),
    'status': entity.status,
    'completedAt': entity.completedAt?.toUtc().toIso8601String(),
    'completedByAuthorProfileId': entity.completedByAuthorProfileId,
    'completedOnDeviceProfileId': entity.completedOnDeviceProfileId,
    'linkedRecordId': entity.linkedRecordId,
  };

  Map<String, Object?> _authorPayload(AuthorProfileEntity entity) => {
    'authorProfileId': entity.authorProfileId,
    'nickname': entity.nickname,
    'colorValue': entity.colorValue,
    'createdAt': entity.createdAt.toUtc().toIso8601String(),
    'isCurrent': entity.isCurrent,
  };

  Map<String, Object?> _attachmentPayload(AttachmentEntity entity) => {
    'attachmentId': entity.attachmentId,
    'recordId': entity.recordId,
    'payload': entity.payload,
    'createdAt': entity.createdAt.toUtc().toIso8601String(),
    'deletedAt': entity.deletedAt?.toUtc().toIso8601String(),
  };

  Map<String, Object?> _duplicatePayload(DuplicateReviewEdgeEntity entity) => {
    'pairKey': entity.pairKey,
    'recordAId': entity.recordAId,
    'recordBId': entity.recordBId,
    'status': entity.status,
    'signatureA': entity.signatureA,
    'signatureB': entity.signatureB,
    'revisionA': entity.revisionA,
    'revisionB': entity.revisionB,
    'detectionReasonsJson': entity.detectionReasonsJson,
    'detectedAt': entity.detectedAt.toUtc().toIso8601String(),
    'detectorVersion': entity.detectorVersion,
    'representativeRecordId': entity.representativeRecordId,
    'logicalGroupId': entity.logicalGroupId,
    'deferredAt': entity.deferredAt?.toUtc().toIso8601String(),
    'resolvedByAuthorProfileId': entity.resolvedByAuthorProfileId,
    'resolvedByDeviceProfileId': entity.resolvedByDeviceProfileId,
    'resolvedAt': entity.resolvedAt?.toUtc().toIso8601String(),
  };

  Map<String, Object?> _customEventPayload(
    SharedCustomEventDefinitionEntity entity,
  ) => {
    'customEventTypeId': entity.customEventTypeId,
    'familySpaceId': entity.familySpaceId,
    'name': entity.name,
    'revision': entity.revision,
    'createdByAuthorProfileId': entity.createdByAuthorProfileId,
    'createdByDeviceProfileId': entity.createdByDeviceProfileId,
    'lastModifiedByAuthorProfileId': entity.lastModifiedByAuthorProfileId,
    'lastModifiedByDeviceProfileId': entity.lastModifiedByDeviceProfileId,
    'createdAt': entity.createdAt.toUtc().toIso8601String(),
    'updatedAt': entity.updatedAt.toUtc().toIso8601String(),
    'archivedAt': entity.archivedAt?.toUtc().toIso8601String(),
  };

  Box<AttachmentEntity> get _attachmentBox =>
      Box<AttachmentEntity>(_objectBox.store);

  Box<SharedCustomEventDefinitionEntity> get _customEventBox =>
      Box<SharedCustomEventDefinitionEntity>(_objectBox.store);
}

/// Validates the untrusted provider boundary before it reaches ObjectBox.
/// Unknown fields remain allowed for forwards compatibility, while every
/// field consumed by this client is checked explicitly.
abstract final class _FamilySyncPayloadValidator {
  static const _maxId = 256;
  static const _maxText = 4096;
  static const _maxJson = 65536;

  static bool isValid(SyncChange change) {
    if (!_requiredString(change.changeId, _maxId) ||
        !_requiredString(change.entityId, _maxId) ||
        !_requiredString(change.familySpaceId, _maxId) ||
        !_requiredString(change.sourceDeviceProfileId, _maxId) ||
        !_requiredString(change.sourceAuthorProfileId, _maxId) ||
        change.entityRevision < 1 ||
        change.entityRevision > 0x7fffffffffffffff ||
        change.payload.length > 40) {
      return false;
    }

    if (change.operation == SyncOperation.delete) {
      // Deletion is currently defined only for activities. Requiring an empty
      // payload also prevents hidden, unvalidated data from crossing the edge.
      return change.entityType == FamilySyncPayloads.activity &&
          change.payload.isEmpty;
    }

    final p = change.payload;
    switch (change.entityType) {
      case FamilySyncPayloads.activity:
        return _sameId(p, 'recordId', change.entityId) &&
            _integer(p, 'revision', min: 1) == change.entityRevision &&
            _string(p, 'type', max: 128) &&
            _date(p, 'time') &&
            _enumInt(p, 'timePrecision', const {0, 1}) &&
            _string(p, 'details', max: _maxJson, allowEmpty: true) &&
            _jsonString(p, 'structuredDataJson', optional: true) &&
            _optionalString(p, 'customEventTypeId', _maxId) &&
            _optionalString(p, 'customEventNameSnapshot', _maxText) &&
            _date(p, 'lastModified') &&
            _date(p, 'createdAt', optional: true) &&
            _identityFields(p);
      case FamilySyncPayloads.careTask:
        return _sameId(p, 'taskId', change.entityId) &&
            (p['childId'] == null ||
                _string(p, 'childId', max: _maxId, allowEmpty: true)) &&
            _string(p, 'title', max: _maxText) &&
            _optionalString(p, 'recurrenceRule', _maxText) &&
            _optionalString(p, 'assignedToAuthorProfileId', _maxId) &&
            _enumString(p, 'notificationMode', const {
              'inAppOnly',
              'quietToAssignee',
            }, optional: true) &&
            _optionalString(p, 'linkedCategory', 128) &&
            _jsonString(p, 'linkedEventTemplateJson', optional: true) &&
            _date(p, 'createdAt') &&
            _date(p, 'archivedAt', optional: true) &&
            _identityFields(p);
      case FamilySyncPayloads.careTaskOccurrence:
        return _sameId(p, 'occurrenceId', change.entityId) &&
            _string(p, 'taskId', max: _maxId) &&
            _date(p, 'scheduledAt') &&
            _enumString(p, 'status', const {
              'scheduled',
              'due',
              'completed',
              'skipped',
            }, optional: true) &&
            _date(p, 'completedAt', optional: true) &&
            _optionalString(p, 'completedByAuthorProfileId', _maxId) &&
            _optionalString(p, 'completedOnDeviceProfileId', _maxId) &&
            _optionalString(p, 'linkedRecordId', _maxId);
      case FamilySyncPayloads.authorProfile:
        return _sameId(p, 'authorProfileId', change.entityId) &&
            _string(p, 'nickname', max: 128) &&
            _integer(p, 'colorValue', min: 0, max: 0xffffffff) != null &&
            _date(p, 'createdAt') &&
            (p['isCurrent'] == null || p['isCurrent'] is bool);
      case FamilySyncPayloads.attachmentMetadata:
        return _sameId(p, 'attachmentId', change.entityId) &&
            _string(p, 'recordId', max: _maxId) &&
            _enumString(
              p,
              'attachmentType',
              AttachmentType.values.map((e) => e.name).toSet(),
            ) &&
            _string(p, 'fileName', max: 255) &&
            _string(p, 'mimeType', max: 128) &&
            _enumString(
              p,
              'sourceKind',
              AttachmentSourceKind.values.map((e) => e.name).toSet(),
            ) &&
            _date(p, 'createdAt') &&
            _date(p, 'deletedAt', optional: true) &&
            _integer(p, 'originalByteSize', min: 0, optional: true) != null &&
            _optionalSha256(p, 'originalSha256') &&
            _optionalString(p, 'missingReason', _maxText) &&
            _identityFields(p);
      case FamilySyncPayloads.duplicateDecision:
        return _sameId(p, 'pairKey', change.entityId) &&
            _string(p, 'recordAId', max: _maxId) &&
            _string(p, 'recordBId', max: _maxId) &&
            p['recordAId'] != p['recordBId'] &&
            _enumString(p, 'status', const {
              DuplicateReviewEdgeEntity.statusPending,
              DuplicateReviewEdgeEntity.statusSameEvent,
              DuplicateReviewEdgeEntity.statusDistinctEvents,
            }) &&
            _string(p, 'signatureA', max: _maxText) &&
            _string(p, 'signatureB', max: _maxText) &&
            _integer(p, 'revisionA', min: 1) != null &&
            _integer(p, 'revisionB', min: 1) != null &&
            _jsonString(p, 'detectionReasonsJson') &&
            _date(p, 'detectedAt') &&
            _string(p, 'detectorVersion', max: 128) &&
            _optionalString(p, 'representativeRecordId', _maxId) &&
            _optionalString(p, 'logicalGroupId', _maxId) &&
            _date(p, 'deferredAt', optional: true) &&
            _optionalString(p, 'resolvedByAuthorProfileId', _maxId) &&
            _optionalString(p, 'resolvedByDeviceProfileId', _maxId) &&
            _date(p, 'resolvedAt', optional: true);
      case FamilySyncPayloads.customEventDefinition:
        return _sameId(p, 'customEventTypeId', change.entityId) &&
            p['familySpaceId'] == change.familySpaceId &&
            _string(p, 'familySpaceId', max: _maxId) &&
            _string(p, 'name', max: 128) &&
            _integer(p, 'revision', min: 1) == change.entityRevision &&
            _string(p, 'createdByAuthorProfileId', max: _maxId) &&
            _string(p, 'createdByDeviceProfileId', max: _maxId) &&
            _string(p, 'lastModifiedByAuthorProfileId', max: _maxId) &&
            _string(p, 'lastModifiedByDeviceProfileId', max: _maxId) &&
            _date(p, 'createdAt') &&
            _date(p, 'updatedAt') &&
            _date(p, 'archivedAt', optional: true);
      default:
        return false;
    }
  }

  static bool _sameId(Map<String, Object?> p, String key, String id) =>
      _string(p, key, max: _maxId) && p[key] == id;

  static bool _identityFields(Map<String, Object?> p) =>
      _optionalString(p, 'createdByAuthorProfileId', _maxId) &&
      _optionalString(p, 'createdByDeviceProfileId', _maxId) &&
      _optionalString(p, 'lastModifiedByAuthorProfileId', _maxId) &&
      _optionalString(p, 'lastModifiedByDeviceProfileId', _maxId);

  static bool _requiredString(String value, int max) =>
      value.isNotEmpty && value.length <= max;

  static bool _string(
    Map<String, Object?> p,
    String key, {
    required int max,
    bool allowEmpty = false,
  }) {
    final value = p[key];
    return value is String &&
        value.length <= max &&
        (allowEmpty || value.isNotEmpty);
  }

  static bool _optionalString(Map<String, Object?> p, String key, int max) =>
      p[key] == null || _string(p, key, max: max);

  static int? _integer(
    Map<String, Object?> p,
    String key, {
    int? min,
    int? max,
    bool optional = false,
  }) {
    final value = p[key];
    if (value == null && optional) return 0;
    if (value is! int ||
        (min != null && value < min) ||
        (max != null && value > max)) {
      return null;
    }
    return value;
  }

  static bool _enumInt(Map<String, Object?> p, String key, Set<int> values) =>
      p[key] is int && values.contains(p[key]);

  static bool _enumString(
    Map<String, Object?> p,
    String key,
    Set<String> values, {
    bool optional = false,
  }) =>
      (optional && p[key] == null) ||
      (p[key] is String && values.contains(p[key]));

  static bool _date(
    Map<String, Object?> p,
    String key, {
    bool optional = false,
  }) {
    final value = p[key];
    if (value == null) return optional;
    if (value is! String || value.isEmpty || value.length > 64) return false;
    return DateTime.tryParse(value) != null;
  }

  static bool _jsonString(
    Map<String, Object?> p,
    String key, {
    bool optional = false,
  }) {
    final value = p[key];
    if (value == null) return optional;
    if (value is! String || value.isEmpty || value.length > _maxJson) {
      return false;
    }
    try {
      jsonDecode(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  static bool _optionalSha256(Map<String, Object?> p, String key) {
    final value = p[key];
    return value == null ||
        (value is String && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value));
  }
}
