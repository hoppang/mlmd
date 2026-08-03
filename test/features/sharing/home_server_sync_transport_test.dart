import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/sharing/application/family_sync_credentials.dart';
import 'package:mlmd/features/sharing/application/family_sync_transport.dart';
import 'package:mlmd/features/sharing/application/home_server_sync_transport.dart';
import 'package:mlmd/features/sharing/domain/family_sync_models.dart';

const _spaceId = '550e8400-e29b-41d4-a716-446655440000';
const _deviceId = '11111111-2222-4333-8444-555555555555';
const _remoteDeviceId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

class _MemoryCredentialStore implements FamilySyncCredentialStore {
  _MemoryCredentialStore(this.credentials);

  FamilySyncCredentials? credentials;

  @override
  Future<void> delete(String familySpaceId) async {
    credentials = null;
  }

  @override
  Future<FamilySyncCredentials?> load(String familySpaceId) async =>
      credentials?.familySpaceId == familySpaceId ? credentials : null;

  @override
  Future<void> save(FamilySyncCredentials credentials) async {
    this.credentials = credentials;
  }
}

class _LoopbackApi implements HomeServerSyncApi {
  _LoopbackApi({
    required this.codec,
    required this.familyKey,
    required this.remoteChange,
  });

  final FamilySyncEnvelopeCodec codec;
  final List<int> familyKey;
  final SyncChange remoteChange;
  List<OpaqueSyncEnvelope> receivedOutgoing = const [];

  @override
  Future<OpaqueSyncExchange> exchange({
    required FamilySyncCredentials credentials,
    required String deviceProfileId,
    required String? afterCursor,
    required List<OpaqueSyncEnvelope> outgoing,
  }) async {
    receivedOutgoing = outgoing;
    final encryptedRemote = await codec.encrypt(remoteChange, familyKey);
    return OpaqueSyncExchange(
      acknowledgedChangeIds: outgoing.map((item) => item.changeId).toSet(),
      incoming: [
        OpaqueSyncEnvelope(
          envelopeVersion: encryptedRemote.envelopeVersion,
          changeId: encryptedRemote.changeId,
          sourceDeviceId: encryptedRemote.sourceDeviceId,
          nonce: encryptedRemote.nonce,
          ciphertext: encryptedRemote.ciphertext,
          serverSeq: 1,
          receivedAt: DateTime.utc(2026, 8, 3, 1, 2, 3),
        ),
      ],
      nextCursor: '1',
      hasMore: false,
    );
  }
}

void main() {
  final familyKey = List<int>.generate(32, (index) => index);

  test('secure credential store round-trips and deletes secrets', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureFamilySyncCredentialStore();
    final credentials = FamilySyncCredentials(
      serverUrl: Uri.parse('http://192.168.1.10:8080'),
      familySpaceId: _spaceId,
      deviceToken:
          '$_deviceId.${base64UrlEncode(List.filled(32, 9)).replaceAll('=', '')}',
      familyKey: familyKey,
    );

    await store.save(credentials);
    final restored = await store.load(_spaceId);

    expect(restored?.serverUrl, credentials.serverUrl);
    expect(restored?.deviceToken, credentials.deviceToken);
    expect(restored?.familyKey, familyKey);
    await store.delete(_spaceId);
    expect(await store.load(_spaceId), isNull);
  });

  test('random pairing secrets are 32-byte unpadded base64url', () async {
    final first = await SecureFamilySyncCredentialStore.createRandomSecret();
    final second = await SecureFamilySyncCredentialStore.createRandomSecret();

    expect(first, hasLength(43));
    expect(base64Url.decode(base64Url.normalize(first)), hasLength(32));
    expect(second, isNot(first));
  });

  test(
    'transport encrypts outgoing changes and decrypts incoming changes',
    () async {
      final codec = FamilySyncEnvelopeCodec();
      final credentials = FamilySyncCredentials(
        serverUrl: Uri.parse('http://127.0.0.1:8080'),
        familySpaceId: _spaceId,
        deviceToken:
            '$_deviceId.${base64UrlEncode(List.filled(32, 1)).replaceAll('=', '')}',
        familyKey: familyKey,
      );
      final localChange = _change(
        changeId: '550e8400-e29b-41d4-a716-446655440010',
        deviceId: _deviceId,
        text: 'local private memo',
      );
      final remoteChange = _change(
        changeId: '550e8400-e29b-41d4-a716-446655440011',
        deviceId: _remoteDeviceId,
        text: 'remote private memo',
      );
      final api = _LoopbackApi(
        codec: codec,
        familyKey: familyKey,
        remoteChange: remoteChange,
      );
      final transport = HomeServerFamilySyncTransport(
        credentialStore: _MemoryCredentialStore(credentials),
        api: api,
        codec: codec,
      );

      final result = await transport.exchange(
        familySpaceId: _spaceId,
        deviceProfileId: _deviceId,
        afterCursor: null,
        outgoingChanges: [localChange],
      );

      expect(result.acknowledgedChangeIds, {localChange.changeId});
      expect(result.nextCursor, '1');
      expect(
        result.incomingChanges.single.payload['text'],
        'remote private memo',
      );
      expect(
        result.incomingChanges.single.serverReceivedAt,
        DateTime.utc(2026, 8, 3, 1, 2, 3),
      );
      expect(api.receivedOutgoing.single.changeId, localChange.changeId);
      expect(
        api.receivedOutgoing.single.ciphertext,
        isNot(contains('local private memo')),
      );
    },
  );

  test('AAD metadata tampering fails authentication', () async {
    final codec = FamilySyncEnvelopeCodec();
    final encrypted = await codec.encrypt(
      _change(
        changeId: '550e8400-e29b-41d4-a716-446655440012',
        deviceId: _deviceId,
        text: 'authenticated memo',
      ),
      familyKey,
    );
    final tampered = OpaqueSyncEnvelope(
      envelopeVersion: encrypted.envelopeVersion,
      changeId: '550e8400-e29b-41d4-a716-446655440013',
      sourceDeviceId: encrypted.sourceDeviceId,
      nonce: encrypted.nonce,
      ciphertext: encrypted.ciphertext,
      serverSeq: 1,
      receivedAt: DateTime.now(),
    );

    await expectLater(
      codec.decrypt(
        familySpaceId: _spaceId,
        envelope: tampered,
        familyKey: familyKey,
      ),
      throwsA(
        isA<FamilySyncUnavailable>().having(
          (error) => error.code,
          'code',
          'e2ee_authentication_failed',
        ),
      ),
    );
  });

  test(
    'encrypted resolution metadata and server sequence round-trip',
    () async {
      final codec = FamilySyncEnvelopeCodec();
      final encrypted = await codec.encrypt(
        _change(
          changeId: '550e8400-e29b-41d4-a716-446655440014',
          deviceId: _deviceId,
          text: 'selected resolution',
          resolutionMetadata: const SyncResolutionMetadata(
            sourceConflictId: 'conflict-1',
            parentChangeIds: ['change-a', 'change-b'],
            selectedResolution: SyncConflictResolution.keepLocal,
          ),
        ),
        familyKey,
      );

      final restored = await codec.decrypt(
        familySpaceId: _spaceId,
        envelope: OpaqueSyncEnvelope(
          envelopeVersion: encrypted.envelopeVersion,
          changeId: encrypted.changeId,
          sourceDeviceId: encrypted.sourceDeviceId,
          nonce: encrypted.nonce,
          ciphertext: encrypted.ciphertext,
          serverSeq: 42,
          receivedAt: DateTime.utc(2026, 8, 3, 2),
        ),
        familyKey: familyKey,
      );

      expect(restored.serverSequence, 42);
      expect(restored.resolutionMetadata?.sourceConflictId, 'conflict-1');
      expect(
        restored.resolutionMetadata?.selectedResolution,
        SyncConflictResolution.keepLocal,
      );
    },
  );

  test('IO API sends bearer auth and protocol v1 exchange JSON', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    late String authorization;
    late Map<String, Object?> requestJson;
    server.listen((request) async {
      authorization = request.headers.value(HttpHeaders.authorizationHeader)!;
      requestJson = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
          .cast<String, Object?>();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'acknowledgedChangeIds': <String>[],
            'incoming': <Object?>[],
            'nextCursor': '0',
            'hasMore': false,
          }),
        );
      await request.response.close();
    });
    final secret = base64UrlEncode(List.filled(32, 2)).replaceAll('=', '');
    final credentials = FamilySyncCredentials(
      serverUrl: Uri.parse('http://${server.address.address}:${server.port}'),
      familySpaceId: _spaceId,
      deviceToken: '$_deviceId.$secret',
      familyKey: familyKey,
    );
    final api = IoHomeServerSyncApi();
    addTearDown(api.close);

    final result = await api.exchange(
      credentials: credentials,
      deviceProfileId: _deviceId,
      afterCursor: null,
      outgoing: const [],
    );

    expect(result.nextCursor, '0');
    expect(authorization, 'Bearer ${credentials.deviceToken}');
    expect(requestJson['protocolVersion'], 1);
    expect(requestJson['afterCursor'], isNull);
    expect(requestJson['outgoing'], isEmpty);
  });
}

SyncChange _change({
  required String changeId,
  required String deviceId,
  required String text,
  SyncResolutionMetadata? resolutionMetadata,
}) => SyncChange(
  changeId: changeId,
  familySpaceId: _spaceId,
  sourceDeviceProfileId: deviceId,
  sourceAuthorProfileId: '550e8400-e29b-41d4-a716-446655440099',
  entityType: 'memo',
  entityId: '550e8400-e29b-41d4-a716-446655440088',
  entityRevision: 1,
  operation: SyncOperation.create,
  payload: {'text': text},
  occurredAt: DateTime.utc(2026, 8, 3),
  resolutionMetadata: resolutionMetadata,
);
