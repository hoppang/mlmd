import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/sharing/application/family_sync_credentials.dart';
import 'package:mlmd/features/sharing/application/family_sync_transport.dart';
import 'package:mlmd/features/sharing/application/home_server_pairing_service.dart';

const _deviceId = '11111111-2222-4333-8444-555555555555';
const _spaceId = '550e8400-e29b-41d4-a716-446655440000';

class _MemoryCredentialStore implements FamilySyncCredentialStore {
  final Map<String, FamilySyncCredentials> values = {};

  @override
  Future<void> delete(String familySpaceId) async {
    values.remove(familySpaceId);
  }

  @override
  Future<FamilySyncCredentials?> load(String familySpaceId) async =>
      values[familySpaceId];

  @override
  Future<void> save(FamilySyncCredentials credentials) async {
    values[credentials.familySpaceId] = credentials;
  }
}

class _LocalState implements HomeServerPairingLocalState {
  @override
  String get currentDeviceId => _deviceId;

  String? connectedSpaceId;
  String? connectedDisplayName;

  @override
  void connect({required String familySpaceId, required String displayName}) {
    connectedSpaceId = familySpaceId;
    connectedDisplayName = displayName;
  }
}

class _FakePairingApi implements HomeServerPairingApi {
  int bootstrapFailures = 0;
  int consumeFailures = 0;
  final List<String> bootstrapSpaceIds = [];
  final List<String> bootstrapSecrets = [];
  final List<String> consumeSecrets = [];
  int revokeFailures = 0;
  final List<String> revokedDeviceIds = [];
  List<HomeServerDevice> devices = const [];

  @override
  Future<BootstrapSpaceResult> bootstrapSpace({
    required Uri serverUrl,
    required String bootstrapToken,
    required String displayName,
    required String familySpaceId,
    required String deviceId,
    required String deviceDisplayName,
    required String deviceSecret,
  }) async {
    bootstrapSpaceIds.add(familySpaceId);
    bootstrapSecrets.add(deviceSecret);
    if (bootstrapFailures > 0) {
      bootstrapFailures--;
      throw const FamilySyncUnavailable('home_server_timeout');
    }
    return BootstrapSpaceResult(
      familySpaceId: familySpaceId,
      deviceId: deviceId,
      role: 'owner',
    );
  }

  @override
  Future<CreatedInvite> createInvite({
    required FamilySyncCredentials credentials,
    required String role,
  }) async => CreatedInvite(
    inviteId: 'invite-1',
    familySpaceId: credentials.familySpaceId,
    inviteToken: 'invite-secret',
    role: role,
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    createdByDeviceId: _deviceId,
  );

  @override
  Future<ConsumedInvite> consumeInvite({
    required Uri serverUrl,
    required String inviteId,
    required String inviteToken,
    required String deviceId,
    required String deviceDisplayName,
    required String deviceSecret,
  }) async {
    consumeSecrets.add(deviceSecret);
    if (consumeFailures > 0) {
      consumeFailures--;
      throw const FamilySyncUnavailable('home_server_timeout');
    }
    return ConsumedInvite(
      familySpaceId: _spaceId,
      deviceId: deviceId,
      role: 'member',
      displayName: '우리 가족',
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<HomeServerDevice>> listDevices({
    required FamilySyncCredentials credentials,
  }) async => devices;

  @override
  Future<RevokedHomeServerDevice> revokeDevice({
    required FamilySyncCredentials credentials,
    required String deviceId,
  }) async {
    revokedDeviceIds.add(deviceId);
    if (revokeFailures > 0) {
      revokeFailures--;
      throw const FamilySyncUnavailable('home_server_timeout');
    }
    return RevokedHomeServerDevice(
      deviceId: deviceId,
      revokedAt: DateTime.utc(2026, 8, 3, 13),
    );
  }
}

FamilyInviteQrPayload _invite({DateTime? expiresAt}) => FamilyInviteQrPayload(
  serverUrl: Uri.parse('http://192.168.0.10:8080'),
  familySpaceId: _spaceId,
  familyDisplayName: '우리 가족',
  inviteId: 'invite-1',
  inviteToken: 'invite-secret',
  inviterDeviceId: 'owner-device',
  role: 'member',
  expiresAt:
      expiresAt ?? DateTime.now().toUtc().add(const Duration(minutes: 10)),
  familyKey: List<int>.generate(32, (index) => index),
);

void main() {
  test('pairing QR payload round-trips all encrypted-space material', () {
    final original = _invite();

    final decoded = FamilyInviteQrPayload.decode(original.encode());

    expect(decoded.serverUrl, original.serverUrl);
    expect(decoded.familySpaceId, original.familySpaceId);
    expect(decoded.familyDisplayName, original.familyDisplayName);
    expect(decoded.inviteId, original.inviteId);
    expect(decoded.inviteToken, original.inviteToken);
    expect(decoded.familyKey, original.familyKey);
    expect(decoded.expiresAt, original.expiresAt);
  });

  test('pairing QR rejects nested paths and user information', () {
    expect(
      () => FamilyInviteQrPayload(
        serverUrl: Uri.parse('http://user:pass@server.local/api'),
        familySpaceId: _spaceId,
        familyDisplayName: '가족',
        inviteId: 'invite-1',
        inviteToken: 'secret',
        inviterDeviceId: _deviceId,
        role: 'member',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        familyKey: List.filled(32, 1),
      ),
      throwsFormatException,
    );
  });

  test('bootstrap retry reuses the same space and device secret', () async {
    final api = _FakePairingApi()..bootstrapFailures = 1;
    final credentials = _MemoryCredentialStore();
    final localState = _LocalState();
    final service = HomeServerPairingService(
      api: api,
      credentialStore: credentials,
      localState: localState,
    );

    final result = await service.bootstrap(
      serverUrl: Uri.parse('http://server.local:8080'),
      bootstrapToken: 'bootstrap-token',
      familyDisplayName: '우리 가족',
      deviceDisplayName: '내 휴대폰',
    );

    expect(api.bootstrapSpaceIds, hasLength(2));
    expect(api.bootstrapSpaceIds.toSet(), hasLength(1));
    expect(api.bootstrapSecrets.toSet(), hasLength(1));
    expect(result.familySpaceId, api.bootstrapSpaceIds.first);
    expect(await credentials.load(result.familySpaceId), same(result));
    expect(localState.connectedSpaceId, result.familySpaceId);
  });

  test(
    'join preserves the pending device secret across a later retry',
    () async {
      final api = _FakePairingApi()..consumeFailures = 2;
      final credentials = _MemoryCredentialStore();
      final localState = _LocalState();
      final service = HomeServerPairingService(
        api: api,
        credentialStore: credentials,
        localState: localState,
      );
      final invite = _invite();

      await expectLater(
        service.join(invite: invite, deviceDisplayName: '새 휴대폰'),
        throwsA(
          isA<FamilySyncUnavailable>().having(
            (error) => error.code,
            'code',
            'home_server_timeout',
          ),
        ),
      );
      final result = await service.join(
        invite: invite,
        deviceDisplayName: '새 휴대폰',
      );

      expect(api.consumeSecrets, hasLength(3));
      expect(api.consumeSecrets.toSet(), hasLength(1));
      expect(result.deviceToken, '$_deviceId.${api.consumeSecrets.first}');
      expect(localState.connectedSpaceId, _spaceId);
    },
  );

  test('device list verifies the server current-device identity', () async {
    final api = _FakePairingApi();
    final credentials = _MemoryCredentialStore();
    await credentials.save(
      FamilySyncCredentials(
        serverUrl: Uri.parse('http://server.local:8080'),
        familySpaceId: _spaceId,
        deviceToken: '$_deviceId.secret',
        familyKey: List.filled(32, 1),
      ),
    );
    api.devices = [
      HomeServerDevice(
        deviceId: _deviceId,
        familySpaceId: _spaceId,
        role: 'owner',
        displayName: '내 휴대폰',
        createdAt: DateTime.utc(2026, 8, 3),
        lastSeenAt: DateTime.utc(2026, 8, 3, 1),
        revokedAt: null,
        isCurrent: true,
      ),
    ];
    final service = HomeServerPairingService(
      api: api,
      credentialStore: credentials,
      localState: _LocalState(),
    );

    final devices = await service.listDevices(familySpaceId: _spaceId);

    expect(devices.single.displayName, '내 휴대폰');
    expect(devices.single.isCurrent, isTrue);
  });

  test(
    'device revocation retries once but rejects the current device',
    () async {
      const otherDeviceId = '66666666-7777-4888-8999-aaaaaaaaaaaa';
      final api = _FakePairingApi()..revokeFailures = 1;
      final credentials = _MemoryCredentialStore();
      await credentials.save(
        FamilySyncCredentials(
          serverUrl: Uri.parse('http://server.local:8080'),
          familySpaceId: _spaceId,
          deviceToken: '$_deviceId.secret',
          familyKey: List.filled(32, 1),
        ),
      );
      final service = HomeServerPairingService(
        api: api,
        credentialStore: credentials,
        localState: _LocalState(),
      );

      final revokedAt = await service.revokeDevice(
        familySpaceId: _spaceId,
        deviceId: otherDeviceId,
      );
      expect(revokedAt, DateTime.utc(2026, 8, 3, 13));
      expect(api.revokedDeviceIds, [otherDeviceId, otherDeviceId]);
      await expectLater(
        service.revokeDevice(familySpaceId: _spaceId, deviceId: _deviceId),
        throwsA(
          isA<FamilySyncUnavailable>().having(
            (error) => error.code,
            'code',
            'cannot_revoke_current_device',
          ),
        ),
      );
    },
  );

  test('IO pairing API lists and revokes devices with bearer auth', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final methods = <String>[];
    final authorizations = <String?>[];
    server.listen((request) async {
      methods.add('${request.method} ${request.uri.path}');
      authorizations.add(
        request.headers.value(HttpHeaders.authorizationHeader),
      );
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'GET') {
        request.response.write(
          jsonEncode({
            'devices': [
              {
                'deviceId': _deviceId,
                'familySpaceId': _spaceId,
                'role': 'owner',
                'displayName': 'Owner phone',
                'createdAt': '2026-08-03T12:00:00Z',
                'lastSeenAt': null,
                'revokedAt': null,
                'isCurrent': true,
              },
            ],
          }),
        );
      } else {
        request.response.write(
          jsonEncode({
            'deviceId': '66666666-7777-4888-8999-aaaaaaaaaaaa',
            'revokedAt': '2026-08-03T13:00:00Z',
          }),
        );
      }
      await request.response.close();
    });
    final api = IoHomeServerPairingApi();
    final credentials = FamilySyncCredentials(
      serverUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      familySpaceId: _spaceId,
      deviceToken: '$_deviceId.secret',
      familyKey: List.filled(32, 1),
    );
    try {
      final devices = await api.listDevices(credentials: credentials);
      final revoked = await api.revokeDevice(
        credentials: credentials,
        deviceId: '66666666-7777-4888-8999-aaaaaaaaaaaa',
      );

      expect(devices.single.isCurrent, isTrue);
      expect(revoked.revokedAt, DateTime.utc(2026, 8, 3, 13));
      expect(methods, [
        'GET /v1/spaces/$_spaceId/devices',
        'DELETE /v1/spaces/$_spaceId/devices/66666666-7777-4888-8999-aaaaaaaaaaaa',
      ]);
      expect(authorizations, [
        'Bearer $_deviceId.secret',
        'Bearer $_deviceId.secret',
      ]);
    } finally {
      api.close();
      await server.close(force: true);
    }
  });

  test('expired invite is rejected without contacting the server', () async {
    final api = _FakePairingApi();
    final service = HomeServerPairingService(
      api: api,
      credentialStore: _MemoryCredentialStore(),
      localState: _LocalState(),
    );

    await expectLater(
      service.join(
        invite: _invite(
          expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
        deviceDisplayName: '휴대폰',
      ),
      throwsA(
        isA<FamilySyncUnavailable>().having(
          (error) => error.code,
          'code',
          'invite_expired',
        ),
      ),
    );
    expect(api.consumeSecrets, isEmpty);
  });

  test(
    'join never overwrites existing credentials from a conflicting QR',
    () async {
      final api = _FakePairingApi();
      final credentials = _MemoryCredentialStore();
      final existing = FamilySyncCredentials(
        serverUrl: Uri.parse('http://trusted.local:8080'),
        familySpaceId: _spaceId,
        deviceToken:
            '$_deviceId.${base64UrlEncode(List.filled(32, 7)).replaceAll('=', '')}',
        familyKey: List.filled(32, 7),
      );
      await credentials.save(existing);
      final service = HomeServerPairingService(
        api: api,
        credentialStore: credentials,
        localState: _LocalState(),
      );

      await expectLater(
        service.join(invite: _invite(), deviceDisplayName: '내 휴대폰'),
        throwsA(
          isA<FamilySyncUnavailable>().having(
            (error) => error.code,
            'code',
            'family_space_credentials_conflict',
          ),
        ),
      );
      expect(await credentials.load(_spaceId), same(existing));
      expect(api.consumeSecrets, isEmpty);
    },
  );

  test('QR decoder rejects a changed protocol version', () {
    final uri = Uri.parse(_invite().encode());
    final json =
        jsonDecode(
              utf8.decode(
                base64Url.decode(
                  base64Url.normalize(uri.queryParameters['payload']!),
                ),
              ),
            )
            as Map<String, Object?>;
    json['protocolVersion'] = 2;
    final changed = Uri(
      scheme: 'mlmd',
      host: 'pair',
      path: '/v1',
      queryParameters: {
        'payload': base64UrlEncode(utf8.encode(jsonEncode(json))),
      },
    );

    expect(
      () => FamilyInviteQrPayload.decode(changed.toString()),
      throwsFormatException,
    );
  });
}
