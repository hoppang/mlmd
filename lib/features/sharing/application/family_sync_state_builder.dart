import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:objectbox/objectbox.dart' hide SyncChange;
import 'package:uuid/uuid.dart';

import '../../../data/objectbox_helper.dart';
import '../../../models/attachment_entity.dart';
import '../../../models/duplicate_review_edge_entity.dart';
import '../../../models/shared_custom_event_definition_entity.dart';
import '../../../repositories/profile_repository.dart';
import '../../children/application/child_profile_repository.dart';
import '../domain/family_sync_models.dart';
import 'family_sync_payloads.dart';

class FamilySyncBuiltState {
  const FamilySyncBuiltState({
    required this.changes,
    required this.fingerprint,
  });

  final List<SyncChange> changes;
  final String fingerprint;
}

/// Materializes the current provider-independent shared state without writing
/// to the outbox or mutating source records.
class FamilySyncStateBuilder {
  FamilySyncStateBuilder(
    this._objectBox,
    this._profiles, [
    this._childProfiles,
  ]);

  static const _uuid = Uuid();
  final ObjectBoxHelper _objectBox;
  final ProfileRepository _profiles;
  final ChildProfileRepository? _childProfiles;

  FamilySyncBuiltState build(String familySpaceId) {
    final source = _profiles.requireCurrentSource();
    final changes = <SyncChange>[];

    void add({
      required String entityType,
      required String entityId,
      required int entityRevision,
      required SyncOperation operation,
      required Map<String, Object?> payload,
      required DateTime occurredAt,
    }) {
      if (entityId.trim().isEmpty || entityRevision < 1) return;
      changes.add(
        SyncChange(
          changeId: _uuid.v4(),
          familySpaceId: familySpaceId,
          sourceDeviceProfileId: source.deviceProfileId,
          sourceAuthorProfileId: source.authorProfileId,
          entityType: entityType,
          entityId: entityId,
          entityRevision: entityRevision,
          operation: operation,
          payload: Map.unmodifiable(payload),
          occurredAt: occurredAt,
        ),
      );
    }

    for (final author in _objectBox.authorProfileBox.getAll()) {
      add(
        entityType: FamilySyncPayloads.authorProfile,
        entityId: author.authorProfileId,
        entityRevision: FamilySyncPayloads.revisionAt(author.createdAt),
        operation: SyncOperation.create,
        payload: FamilySyncPayloads.forAuthor(author),
        occurredAt: author.createdAt,
      );
    }

    final customEventBox = Box<SharedCustomEventDefinitionEntity>(
      _objectBox.store,
    );
    for (final definition in customEventBox.getAll()) {
      if (definition.familySpaceId != familySpaceId) continue;
      add(
        entityType: FamilySyncPayloads.customEventDefinition,
        entityId: definition.customEventTypeId,
        entityRevision: definition.revision,
        operation: SyncOperation.create,
        payload: FamilySyncPayloads.forCustomEventDefinition(definition),
        occurredAt: definition.updatedAt,
      );
    }

    for (final activity in _objectBox.activityBox.getAll()) {
      final recordId = activity.recordId;
      if (recordId == null) continue;
      add(
        entityType: FamilySyncPayloads.activity,
        entityId: recordId,
        entityRevision: activity.revision,
        operation: SyncOperation.create,
        payload: FamilySyncPayloads.forActivity(activity),
        occurredAt: activity.lastModified,
      );
    }

    for (final task in _objectBox.careTaskBox.getAll()) {
      final occurredAt = task.archivedAt ?? task.createdAt;
      add(
        entityType: FamilySyncPayloads.careTask,
        entityId: task.taskId,
        entityRevision: FamilySyncPayloads.revisionAt(occurredAt),
        operation: SyncOperation.create,
        payload: FamilySyncPayloads.forTask(task),
        occurredAt: occurredAt,
      );
    }

    for (final occurrence in _objectBox.careTaskOccurrenceBox.getAll()) {
      final occurredAt = occurrence.completedAt ?? occurrence.scheduledAt;
      add(
        entityType: FamilySyncPayloads.careTaskOccurrence,
        entityId: occurrence.occurrenceId,
        entityRevision: FamilySyncPayloads.revisionAt(occurredAt),
        operation: SyncOperation.create,
        payload: FamilySyncPayloads.forOccurrence(occurrence),
        occurredAt: occurredAt,
      );
    }

    final attachmentBox = Box<AttachmentEntity>(_objectBox.store);
    for (final entity in attachmentBox.getAll()) {
      final attachment = entity.toDomain();
      if (attachment == null) continue;
      final occurredAt = attachment.deletedAt ?? attachment.createdAt;
      add(
        entityType: FamilySyncPayloads.attachmentMetadata,
        entityId: attachment.attachmentId,
        entityRevision: FamilySyncPayloads.revisionAt(occurredAt),
        operation: SyncOperation.create,
        payload: FamilySyncPayloads.forAttachment(attachment),
        occurredAt: occurredAt,
      );
    }

    for (final edge in _objectBox.duplicateReviewEdgeBox.getAll()) {
      if (edge.status == DuplicateReviewEdgeEntity.statusPending &&
          edge.deferredAt == null &&
          edge.resolvedAt == null) {
        continue;
      }
      final occurredAt = edge.resolvedAt ?? edge.deferredAt ?? edge.detectedAt;
      add(
        entityType: FamilySyncPayloads.duplicateDecision,
        entityId: edge.pairKey,
        entityRevision: FamilySyncPayloads.revisionAt(occurredAt),
        operation: SyncOperation.update,
        payload: FamilySyncPayloads.forDuplicateDecision(edge),
        occurredAt: occurredAt,
      );
    }

    for (final child in _childProfiles?.allChildren ?? const []) {
      if (child.familySpaceId != familySpaceId) continue;
      add(
        entityType: FamilySyncPayloads.childProfile,
        entityId: child.childId,
        entityRevision: child.revision,
        operation: SyncOperation.create,
        payload: FamilySyncPayloads.forChildProfile(child),
        occurredAt: child.updatedAt,
      );
    }

    changes.sort((left, right) {
      final byType = left.entityType.compareTo(right.entityType);
      if (byType != 0) return byType;
      return left.entityId.compareTo(right.entityId);
    });
    final fingerprintInput = changes
        .map(
          (change) => {
            'entityType': change.entityType,
            'entityId': change.entityId,
            'entityRevision': change.entityRevision,
            'operation': change.operation.name,
            'payload': change.payload,
            'occurredAt': change.occurredAt.toUtc().toIso8601String(),
          },
        )
        .toList(growable: false);
    return FamilySyncBuiltState(
      changes: List.unmodifiable(changes),
      fingerprint: sha256
          .convert(utf8.encode(jsonEncode(fingerprintInput)))
          .toString(),
    );
  }
}
