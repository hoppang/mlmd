import '../../../models/shared_custom_event_definition_entity.dart';
import '../../../repositories/custom_event_repository.dart';
import '../domain/family_sync_models.dart';

class CustomEventSyncAdapter {
  const CustomEventSyncAdapter(this._repository);

  final CustomEventRepository _repository;

  RemoteApplyResult apply(SyncChange change) {
    if (change.entityType != 'customEventDefinition') {
      return const RemoteApplyResult.ignored();
    }
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
    SharedCustomEventDefinitionEntity? local;
    for (final item in _repository.getDefinitions(includeArchived: true)) {
      if (item.customEventTypeId == incoming.customEventTypeId) {
        local = item;
        break;
      }
    }
    if (local != null) {
      if (local.revision > incoming.revision ||
          (local.revision == incoming.revision &&
              !_sameDefinition(local, incoming))) {
        return RemoteApplyResult.conflict(
          localRevision: local.revision,
          localPayload: _payload(local),
        );
      }
      if (local.revision == incoming.revision) {
        return const RemoteApplyResult.ignored();
      }
    }
    _repository.applySharedDefinition(incoming);
    return const RemoteApplyResult.applied();
  }

  bool _sameDefinition(
    SharedCustomEventDefinitionEntity left,
    SharedCustomEventDefinitionEntity right,
  ) =>
      left.familySpaceId == right.familySpaceId &&
      left.name == right.name &&
      left.revision == right.revision &&
      left.updatedAt.isAtSameMomentAs(right.updatedAt) &&
      _sameNullableDate(left.archivedAt, right.archivedAt);

  bool _sameNullableDate(DateTime? left, DateTime? right) => left == null
      ? right == null
      : right != null && left.isAtSameMomentAs(right);

  Map<String, Object?> _payload(
    SharedCustomEventDefinitionEntity definition,
  ) => {
    'customEventTypeId': definition.customEventTypeId,
    'familySpaceId': definition.familySpaceId,
    'name': definition.name,
    'revision': definition.revision,
    'createdByAuthorProfileId': definition.createdByAuthorProfileId,
    'createdByDeviceProfileId': definition.createdByDeviceProfileId,
    'lastModifiedByAuthorProfileId': definition.lastModifiedByAuthorProfileId,
    'lastModifiedByDeviceProfileId': definition.lastModifiedByDeviceProfileId,
    'createdAt': definition.createdAt.toUtc().toIso8601String(),
    'updatedAt': definition.updatedAt.toUtc().toIso8601String(),
    if (definition.archivedAt != null)
      'archivedAt': definition.archivedAt!.toUtc().toIso8601String(),
  };
}
