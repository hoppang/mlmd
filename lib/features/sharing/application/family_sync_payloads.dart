import '../../../models/activity_entity.dart';
import '../../../models/author_profile_entity.dart';
import '../../../models/care_task_entity.dart';
import '../../../models/care_task_occurrence_entity.dart';
import '../../../models/duplicate_review_edge_entity.dart';
import '../../attachments/domain/event_attachment.dart';

/// Stable entity names and JSON payloads used at the provider-independent sync
/// boundary. Managed file paths are deliberately excluded from attachment
/// payloads because UX-037 only shares text metadata.
abstract final class FamilySyncPayloads {
  static const activity = 'activity';
  static const authorProfile = 'authorProfile';
  static const careTask = 'careTask';
  static const careTaskOccurrence = 'careTaskOccurrence';
  static const attachmentMetadata = 'attachmentMetadata';
  static const duplicateDecision = 'duplicateDecision';
  static const customEventDefinition = 'customEventDefinition';

  static int revisionAt(DateTime value) =>
      value.toUtc().microsecondsSinceEpoch.clamp(1, 0x7fffffffffffffff);

  static Map<String, Object?> forActivity(ActivityEntity value) => {
    'recordId': value.recordId,
    'revision': value.revision,
    'type': value.type,
    'time': value.time.toUtc().toIso8601String(),
    'timePrecision': value.timePrecision,
    'details': value.details,
    if (value.structuredDataJson != null)
      'structuredDataJson': value.structuredDataJson,
    if (value.customEventTypeId != null)
      'customEventTypeId': value.customEventTypeId,
    if (value.customEventNameSnapshot != null)
      'customEventNameSnapshot': value.customEventNameSnapshot,
    'lastModified': value.lastModified.toUtc().toIso8601String(),
    if (value.createdAt != null)
      'createdAt': value.createdAt!.toUtc().toIso8601String(),
    if (value.createdByAuthorProfileId != null)
      'createdByAuthorProfileId': value.createdByAuthorProfileId,
    if (value.createdByDeviceProfileId != null)
      'createdByDeviceProfileId': value.createdByDeviceProfileId,
    if (value.lastModifiedByAuthorProfileId != null)
      'lastModifiedByAuthorProfileId': value.lastModifiedByAuthorProfileId,
    if (value.lastModifiedByDeviceProfileId != null)
      'lastModifiedByDeviceProfileId': value.lastModifiedByDeviceProfileId,
  };

  static Map<String, Object?> forAuthor(AuthorProfileEntity value) => {
    'authorProfileId': value.authorProfileId,
    'nickname': value.nickname,
    'colorValue': value.colorValue,
    'createdAt': value.createdAt.toUtc().toIso8601String(),
  };

  static Map<String, Object?> forTask(CareTaskEntity value) => {
    'taskId': value.taskId,
    'childId': value.childId,
    'title': value.title,
    if (value.recurrenceRule != null) 'recurrenceRule': value.recurrenceRule,
    if (value.assignedToAuthorProfileId != null)
      'assignedToAuthorProfileId': value.assignedToAuthorProfileId,
    'notificationMode': value.notificationMode,
    if (value.linkedCategory != null) 'linkedCategory': value.linkedCategory,
    if (value.linkedEventTemplateJson != null)
      'linkedEventTemplateJson': value.linkedEventTemplateJson,
    'createdAt': value.createdAt.toUtc().toIso8601String(),
    if (value.archivedAt != null)
      'archivedAt': value.archivedAt!.toUtc().toIso8601String(),
    'createdByAuthorProfileId': value.createdByAuthorProfileId,
    'createdByDeviceProfileId': value.createdByDeviceProfileId,
  };

  static Map<String, Object?> forOccurrence(CareTaskOccurrenceEntity value) => {
    'occurrenceId': value.occurrenceId,
    'taskId': value.taskId,
    'scheduledAt': value.scheduledAt.toUtc().toIso8601String(),
    'status': value.status,
    if (value.completedAt != null)
      'completedAt': value.completedAt!.toUtc().toIso8601String(),
    if (value.completedByAuthorProfileId != null)
      'completedByAuthorProfileId': value.completedByAuthorProfileId,
    if (value.completedOnDeviceProfileId != null)
      'completedOnDeviceProfileId': value.completedOnDeviceProfileId,
    if (value.linkedRecordId != null) 'linkedRecordId': value.linkedRecordId,
  };

  static Map<String, Object?> forAttachment(EventAttachment value) => {
    'attachmentId': value.attachmentId,
    'recordId': value.recordId,
    'attachmentType': value.attachmentType.name,
    'fileName': value.fileName,
    'mimeType': value.mimeType,
    'sourceKind': value.sourceKind.name,
    if (value.createdByAuthorProfileId != null)
      'createdByAuthorProfileId': value.createdByAuthorProfileId,
    if (value.createdByDeviceProfileId != null)
      'createdByDeviceProfileId': value.createdByDeviceProfileId,
    'createdAt': value.createdAt.toUtc().toIso8601String(),
    if (value.deletedAt != null)
      'deletedAt': value.deletedAt!.toUtc().toIso8601String(),
    if (value.originalByteSize != null)
      'originalByteSize': value.originalByteSize,
    if (value.originalSha256 != null) 'originalSha256': value.originalSha256,
    if (value.missingReason != null) 'missingReason': value.missingReason,
  };

  static Map<String, Object?> forDuplicateDecision(
    DuplicateReviewEdgeEntity value,
  ) => {
    'pairKey': value.pairKey,
    'recordAId': value.recordAId,
    'recordBId': value.recordBId,
    'status': value.status,
    'signatureA': value.signatureA,
    'signatureB': value.signatureB,
    'revisionA': value.revisionA,
    'revisionB': value.revisionB,
    'detectionReasonsJson': value.detectionReasonsJson,
    'detectedAt': value.detectedAt.toUtc().toIso8601String(),
    'detectorVersion': value.detectorVersion,
    if (value.representativeRecordId != null)
      'representativeRecordId': value.representativeRecordId,
    if (value.logicalGroupId != null) 'logicalGroupId': value.logicalGroupId,
    if (value.deferredAt != null)
      'deferredAt': value.deferredAt!.toUtc().toIso8601String(),
    if (value.resolvedByAuthorProfileId != null)
      'resolvedByAuthorProfileId': value.resolvedByAuthorProfileId,
    if (value.resolvedByDeviceProfileId != null)
      'resolvedByDeviceProfileId': value.resolvedByDeviceProfileId,
    if (value.resolvedAt != null)
      'resolvedAt': value.resolvedAt!.toUtc().toIso8601String(),
  };
}
