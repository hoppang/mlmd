import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/family_sync_repository.dart';
import '../../../repositories/profile_repository.dart';
import 'family_sync_credentials.dart';
import 'family_sync_transport.dart';
import 'home_server_pairing_service.dart';
import 'home_server_sync_transport.dart';

final familySyncCredentialStoreProvider = Provider<FamilySyncCredentialStore>(
  (ref) => const SecureFamilySyncCredentialStore(),
);

final homeServerSyncApiProvider = Provider<IoHomeServerSyncApi>((ref) {
  final api = IoHomeServerSyncApi();
  ref.onDispose(api.close);
  return api;
});

final homeServerPairingApiProvider = Provider<IoHomeServerPairingApi>((ref) {
  final api = IoHomeServerPairingApi();
  ref.onDispose(api.close);
  return api;
});

class _RepositoryPairingLocalState implements HomeServerPairingLocalState {
  const _RepositoryPairingLocalState(this._profiles, this._familySync);

  final ProfileRepository _profiles;
  final FamilySyncRepository _familySync;

  @override
  String get currentDeviceId => _profiles.currentDevice.deviceProfileId;

  @override
  void connect({required String familySpaceId, required String displayName}) {
    _familySync.connect(familySpaceId: familySpaceId, displayName: displayName);
  }
}

final homeServerPairingServiceProvider = Provider<HomeServerPairingService>(
  (ref) => HomeServerPairingService(
    api: ref.watch(homeServerPairingApiProvider),
    credentialStore: ref.watch(familySyncCredentialStoreProvider),
    localState: _RepositoryPairingLocalState(
      ref.watch(profileRepositoryProvider),
      ref.watch(familySyncRepositoryProvider),
    ),
  ),
  dependencies: [
    homeServerPairingApiProvider,
    familySyncCredentialStoreProvider,
    profileRepositoryProvider,
    familySyncRepositoryProvider,
  ],
);

/// The transport stays inert until an active family space has matching
/// credentials in secure storage. Local-only installations never open a
/// network connection.
final familySyncTransportProvider = Provider<FamilySyncTransport>(
  (ref) => HomeServerFamilySyncTransport(
    credentialStore: ref.watch(familySyncCredentialStoreProvider),
    api: ref.watch(homeServerSyncApiProvider),
  ),
  dependencies: [familySyncCredentialStoreProvider, homeServerSyncApiProvider],
);
