import '../domain/family_sync_models.dart';

abstract interface class FamilySyncTransport {
  Future<SyncExchange> exchange({
    required String familySpaceId,
    required String deviceProfileId,
    required String? afterCursor,
    required List<SyncChange> outgoingChanges,
  });
}

class FamilySyncUnavailable implements Exception {
  const FamilySyncUnavailable(this.code);

  final String code;

  @override
  String toString() => 'FamilySyncUnavailable($code)';
}

/// Used until an authenticated provider adapter is configured.
class UnconfiguredFamilySyncTransport implements FamilySyncTransport {
  const UnconfiguredFamilySyncTransport();

  @override
  Future<SyncExchange> exchange({
    required String familySpaceId,
    required String deviceProfileId,
    required String? afterCursor,
    required List<SyncChange> outgoingChanges,
  }) {
    throw const FamilySyncUnavailable('transport_not_configured');
  }
}
