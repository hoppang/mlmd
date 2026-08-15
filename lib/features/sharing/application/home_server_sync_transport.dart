import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../domain/family_sync_models.dart';
import 'family_sync_credentials.dart';
import 'family_sync_transport.dart';

const _protocolVersion = 1;
const _envelopeVersion = 1;
const _maxResponseBytes = 2 * 1024 * 1024;
const _snapshotVersion = 1;
const _maxSnapshotResponseBytes = 12 * 1024 * 1024;

class OpaqueSyncEnvelope {
  const OpaqueSyncEnvelope({
    required this.envelopeVersion,
    required this.changeId,
    required this.sourceDeviceId,
    required this.nonce,
    required this.ciphertext,
    this.serverSeq,
    this.receivedAt,
  });

  final int envelopeVersion;
  final String changeId;
  final String sourceDeviceId;
  final String nonce;
  final String ciphertext;
  final int? serverSeq;
  final DateTime? receivedAt;

  Map<String, Object?> toJson() => {
    'envelopeVersion': envelopeVersion,
    'changeId': changeId,
    'sourceDeviceId': sourceDeviceId,
    'nonce': nonce,
    'ciphertext': ciphertext,
  };

  factory OpaqueSyncEnvelope.fromJson(Map<String, Object?> json) {
    final envelopeVersion = json['envelopeVersion'];
    final changeId = json['changeId'];
    final sourceDeviceId = json['sourceDeviceId'];
    final nonce = json['nonce'];
    final ciphertext = json['ciphertext'];
    final serverSeq = json['serverSeq'];
    final receivedAt = json['receivedAt'];
    if (envelopeVersion is! int ||
        changeId is! String ||
        sourceDeviceId is! String ||
        nonce is! String ||
        ciphertext is! String ||
        serverSeq is! int ||
        receivedAt is! String) {
      throw const FormatException('Invalid incoming sync envelope.');
    }
    return OpaqueSyncEnvelope(
      envelopeVersion: envelopeVersion,
      changeId: changeId,
      sourceDeviceId: sourceDeviceId,
      nonce: nonce,
      ciphertext: ciphertext,
      serverSeq: serverSeq,
      receivedAt: DateTime.parse(receivedAt),
    );
  }
}

class OpaqueSyncExchange {
  const OpaqueSyncExchange({
    required this.acknowledgedChangeIds,
    required this.incoming,
    required this.nextCursor,
    required this.hasMore,
  });

  final Set<String> acknowledgedChangeIds;
  final List<OpaqueSyncEnvelope> incoming;
  final String nextCursor;
  final bool hasMore;
}

class OpaqueSyncSnapshot {
  const OpaqueSyncSnapshot({
    required this.snapshotId,
    required this.baseServerSeq,
    required this.sourceDeviceId,
    required this.snapshotVersion,
    required this.nonce,
    required this.ciphertext,
    this.createdAt,
  });

  final String snapshotId;
  final int baseServerSeq;
  final String sourceDeviceId;
  final int snapshotVersion;
  final String nonce;
  final String ciphertext;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => {
    'snapshotId': snapshotId,
    'baseServerSeq': baseServerSeq,
    'sourceDeviceId': sourceDeviceId,
    'snapshotVersion': snapshotVersion,
    'nonce': nonce,
    'ciphertext': ciphertext,
  };

  factory OpaqueSyncSnapshot.fromJson(Map<String, Object?> json) {
    final snapshotId = json['snapshotId'];
    final baseServerSeq = json['baseServerSeq'];
    final sourceDeviceId = json['sourceDeviceId'];
    final snapshotVersion = json['snapshotVersion'];
    final nonce = json['nonce'];
    final ciphertext = json['ciphertext'];
    final createdAt = json['createdAt'];
    if (snapshotId is! String ||
        baseServerSeq is! int ||
        sourceDeviceId is! String ||
        snapshotVersion is! int ||
        nonce is! String ||
        ciphertext is! String ||
        createdAt is! String) {
      throw const FormatException('Invalid sync snapshot.');
    }
    return OpaqueSyncSnapshot(
      snapshotId: snapshotId,
      baseServerSeq: baseServerSeq,
      sourceDeviceId: sourceDeviceId,
      snapshotVersion: snapshotVersion,
      nonce: nonce,
      ciphertext: ciphertext,
      createdAt: DateTime.parse(createdAt),
    );
  }
}

abstract interface class HomeServerSyncApi {
  Future<OpaqueSyncExchange> exchange({
    required FamilySyncCredentials credentials,
    required String deviceProfileId,
    required String? afterCursor,
    required List<OpaqueSyncEnvelope> outgoing,
  });

  Future<OpaqueSyncSnapshot> putSnapshot({
    required FamilySyncCredentials credentials,
    required String deviceProfileId,
    required OpaqueSyncSnapshot snapshot,
  });

  Future<OpaqueSyncSnapshot?> getSnapshot({
    required FamilySyncCredentials credentials,
    required String deviceProfileId,
  });
}

class IoHomeServerSyncApi implements HomeServerSyncApi {
  IoHomeServerSyncApi({HttpClient? client})
    : _client = client ?? HttpClient(),
      _ownsClient = client == null;

  final HttpClient _client;
  final bool _ownsClient;

  @override
  Future<OpaqueSyncExchange> exchange({
    required FamilySyncCredentials credentials,
    required String deviceProfileId,
    required String? afterCursor,
    required List<OpaqueSyncEnvelope> outgoing,
  }) async {
    if (!credentials.deviceToken.startsWith('$deviceProfileId.')) {
      throw const FamilySyncUnavailable('device_identity_mismatch');
    }
    final endpoint = credentials.serverUrl.resolve(
      '/v1/spaces/${Uri.encodeComponent(credentials.familySpaceId)}/exchange',
    );
    try {
      final request = await _client.postUrl(endpoint);
      request.headers
        ..contentType = ContentType.json
        ..set(
          HttpHeaders.authorizationHeader,
          'Bearer ${credentials.deviceToken}',
        );
      request.write(
        jsonEncode({
          'protocolVersion': _protocolVersion,
          'afterCursor': afterCursor,
          'limit': 200,
          'outgoing': outgoing.map((item) => item.toJson()).toList(),
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final responseBody = await _readLimited(response, _maxResponseBytes);
      if (response.statusCode != HttpStatus.ok) {
        throw FamilySyncUnavailable(_serverErrorCode(responseBody));
      }
      return _decodeExchange(responseBody);
    } on FamilySyncUnavailable {
      rethrow;
    } on TimeoutException {
      throw const FamilySyncUnavailable('home_server_timeout');
    } on SocketException {
      throw const FamilySyncUnavailable('home_server_unreachable');
    } on HandshakeException {
      throw const FamilySyncUnavailable('home_server_tls_error');
    } on FormatException {
      throw const FamilySyncUnavailable('invalid_server_response');
    }
  }

  @override
  Future<OpaqueSyncSnapshot> putSnapshot({
    required FamilySyncCredentials credentials,
    required String deviceProfileId,
    required OpaqueSyncSnapshot snapshot,
  }) async {
    _validateDeviceIdentity(credentials, deviceProfileId);
    final endpoint = _snapshotEndpoint(credentials);
    try {
      final request = await _client.putUrl(endpoint);
      _authorize(request, credentials);
      request.write(jsonEncode(snapshot.toJson()));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await _readLimited(
        response,
        _maxSnapshotResponseBytes,
      );
      if (response.statusCode != HttpStatus.created) {
        throw FamilySyncUnavailable(_serverErrorCode(responseBody));
      }
      return _decodeSnapshot(responseBody);
    } on FamilySyncUnavailable {
      rethrow;
    } on TimeoutException {
      throw const FamilySyncUnavailable('home_server_timeout');
    } on SocketException {
      throw const FamilySyncUnavailable('home_server_unreachable');
    } on HandshakeException {
      throw const FamilySyncUnavailable('home_server_tls_error');
    } on FormatException {
      throw const FamilySyncUnavailable('invalid_server_response');
    }
  }

  @override
  Future<OpaqueSyncSnapshot?> getSnapshot({
    required FamilySyncCredentials credentials,
    required String deviceProfileId,
  }) async {
    _validateDeviceIdentity(credentials, deviceProfileId);
    try {
      final request = await _client.getUrl(_snapshotEndpoint(credentials));
      _authorize(request, credentials);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await _readLimited(
        response,
        _maxSnapshotResponseBytes,
      );
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw FamilySyncUnavailable(_serverErrorCode(responseBody));
      }
      return _decodeSnapshot(responseBody);
    } on FamilySyncUnavailable {
      rethrow;
    } on TimeoutException {
      throw const FamilySyncUnavailable('home_server_timeout');
    } on SocketException {
      throw const FamilySyncUnavailable('home_server_unreachable');
    } on HandshakeException {
      throw const FamilySyncUnavailable('home_server_tls_error');
    } on FormatException {
      throw const FamilySyncUnavailable('invalid_server_response');
    }
  }

  void close() {
    if (_ownsClient) _client.close(force: true);
  }

  OpaqueSyncExchange _decodeExchange(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Exchange response must be an object.');
    }
    final json = decoded.cast<String, Object?>();
    final acknowledged = json['acknowledgedChangeIds'];
    final incoming = json['incoming'];
    final nextCursor = json['nextCursor'];
    final hasMore = json['hasMore'];
    if (acknowledged is! List ||
        incoming is! List ||
        nextCursor is! String ||
        hasMore is! bool) {
      throw const FormatException('Invalid exchange response.');
    }
    return OpaqueSyncExchange(
      acknowledgedChangeIds: acknowledged.map((item) {
        if (item is! String) throw const FormatException('Invalid ack ID.');
        return item;
      }).toSet(),
      incoming: incoming
          .map((item) {
            if (item is! Map) {
              throw const FormatException('Invalid incoming envelope.');
            }
            return OpaqueSyncEnvelope.fromJson(item.cast<String, Object?>());
          })
          .toList(growable: false),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  OpaqueSyncSnapshot _decodeSnapshot(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Snapshot response must be an object.');
    }
    return OpaqueSyncSnapshot.fromJson(decoded.cast<String, Object?>());
  }

  Uri _snapshotEndpoint(FamilySyncCredentials credentials) =>
      credentials.serverUrl.resolve(
        '/v1/spaces/${Uri.encodeComponent(credentials.familySpaceId)}/snapshot',
      );

  void _validateDeviceIdentity(
    FamilySyncCredentials credentials,
    String deviceProfileId,
  ) {
    if (!credentials.deviceToken.startsWith('$deviceProfileId.')) {
      throw const FamilySyncUnavailable('device_identity_mismatch');
    }
  }

  void _authorize(
    HttpClientRequest request,
    FamilySyncCredentials credentials,
  ) {
    request.headers
      ..contentType = ContentType.json
      ..set(
        HttpHeaders.authorizationHeader,
        'Bearer ${credentials.deviceToken}',
      );
  }

  String _serverErrorCode(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map && decoded['error'] is Map) {
        final code = (decoded['error'] as Map)['code'];
        if (code is String && code.isNotEmpty) return 'server_$code';
      }
    } on FormatException {
      // Fall through to the stable generic code.
    }
    return 'server_error';
  }

  Future<String> _readLimited(HttpClientResponse response, int limit) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > limit) {
        throw const FamilySyncUnavailable('server_response_too_large');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }
}

class FamilySyncEnvelopeCodec {
  FamilySyncEnvelopeCodec({Xchacha20? algorithm})
    : _algorithm = algorithm ?? Xchacha20.poly1305Aead();

  final Xchacha20 _algorithm;

  Future<OpaqueSyncEnvelope> encrypt(
    SyncChange change,
    List<int> familyKey,
  ) async {
    _validateKey(familyKey);
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(jsonEncode({'schemaVersion': 1, 'change': change.toJson()})),
      secretKey: SecretKey(familyKey),
      nonce: nonce,
      aad: _aad(
        change.familySpaceId,
        change.changeId,
        change.sourceDeviceProfileId,
      ),
    );
    return OpaqueSyncEnvelope(
      envelopeVersion: _envelopeVersion,
      changeId: change.changeId,
      sourceDeviceId: change.sourceDeviceProfileId,
      nonce: base64UrlEncode(nonce).replaceAll('=', ''),
      ciphertext: base64UrlEncode([
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]).replaceAll('=', ''),
    );
  }

  Future<SyncChange> decrypt({
    required String familySpaceId,
    required OpaqueSyncEnvelope envelope,
    required List<int> familyKey,
  }) async {
    _validateKey(familyKey);
    if (envelope.envelopeVersion != _envelopeVersion) {
      throw const FamilySyncUnavailable('unsupported_envelope_version');
    }
    try {
      final nonce = base64Url.decode(base64Url.normalize(envelope.nonce));
      final combined = base64Url.decode(
        base64Url.normalize(envelope.ciphertext),
      );
      if (nonce.length != 24 || combined.length < 16) {
        throw const FormatException('Invalid encrypted envelope sizes.');
      }
      final macOffset = combined.length - 16;
      final clearText = await _algorithm.decrypt(
        SecretBox(
          combined.sublist(0, macOffset),
          nonce: nonce,
          mac: Mac(combined.sublist(macOffset)),
        ),
        secretKey: SecretKey(familyKey),
        aad: _aad(familySpaceId, envelope.changeId, envelope.sourceDeviceId),
      );
      final decoded = jsonDecode(utf8.decode(clearText));
      if (decoded is! Map || decoded['schemaVersion'] != 1) {
        throw const FormatException('Invalid encrypted change schema.');
      }
      final inner = decoded['change'];
      if (inner is! Map) {
        throw const FormatException('Encrypted change must be an object.');
      }
      final changeJson = inner.cast<String, Object?>();
      if (envelope.receivedAt != null) {
        changeJson['serverReceivedAt'] = envelope.receivedAt!
            .toUtc()
            .toIso8601String();
      }
      if (envelope.serverSeq != null) {
        changeJson['serverSequence'] = envelope.serverSeq;
      }
      final change = SyncChange.fromJson(changeJson);
      if (change.familySpaceId != familySpaceId ||
          change.changeId != envelope.changeId ||
          change.sourceDeviceProfileId != envelope.sourceDeviceId) {
        throw const FamilySyncUnavailable('encrypted_metadata_mismatch');
      }
      return change;
    } on FamilySyncUnavailable {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const FamilySyncUnavailable('e2ee_authentication_failed');
    } on FormatException {
      throw const FamilySyncUnavailable('invalid_encrypted_change');
    }
  }

  List<int> _aad(
    String familySpaceId,
    String changeId,
    String sourceDeviceId,
  ) => utf8.encode(
    [
      'mlmd-sync-envelope',
      '$_envelopeVersion',
      familySpaceId,
      changeId,
      sourceDeviceId,
    ].join('\u0000'),
  );

  void _validateKey(List<int> familyKey) {
    if (familyKey.length != 32) {
      throw const FamilySyncUnavailable('family_key_invalid');
    }
  }
}

class FamilySyncSnapshotCodec {
  FamilySyncSnapshotCodec({Xchacha20? algorithm})
    : _algorithm = algorithm ?? Xchacha20.poly1305Aead();

  final Xchacha20 _algorithm;

  Future<OpaqueSyncSnapshot> encrypt(
    String familySpaceId,
    FamilySyncStateSnapshot snapshot,
    List<int> familyKey,
  ) async {
    _validateKey(familyKey);
    if (snapshot.baseServerSequence < 0) {
      throw const FamilySyncUnavailable('snapshot_base_invalid');
    }
    for (final change in snapshot.changes) {
      if (change.familySpaceId != familySpaceId ||
          change.serverSequence != null) {
        throw const FamilySyncUnavailable('snapshot_change_invalid');
      }
    }
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(
        jsonEncode({
          'schemaVersion': 1,
          'changes': snapshot.changes
              .map((change) => change.toJson())
              .toList(growable: false),
        }),
      ),
      secretKey: SecretKey(familyKey),
      nonce: nonce,
      aad: _aad(
        familySpaceId,
        snapshot.snapshotId,
        snapshot.sourceDeviceProfileId,
        snapshot.baseServerSequence,
      ),
    );
    return OpaqueSyncSnapshot(
      snapshotId: snapshot.snapshotId,
      baseServerSeq: snapshot.baseServerSequence,
      sourceDeviceId: snapshot.sourceDeviceProfileId,
      snapshotVersion: _snapshotVersion,
      nonce: base64UrlEncode(nonce).replaceAll('=', ''),
      ciphertext: base64UrlEncode([
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]).replaceAll('=', ''),
    );
  }

  Future<FamilySyncStateSnapshot> decrypt({
    required String familySpaceId,
    required OpaqueSyncSnapshot snapshot,
    required List<int> familyKey,
  }) async {
    _validateKey(familyKey);
    if (snapshot.snapshotVersion != _snapshotVersion) {
      throw const FamilySyncUnavailable('unsupported_snapshot_version');
    }
    try {
      final nonce = base64Url.decode(base64Url.normalize(snapshot.nonce));
      final combined = base64Url.decode(
        base64Url.normalize(snapshot.ciphertext),
      );
      if (nonce.length != 24 || combined.length < 16) {
        throw const FormatException('Invalid encrypted snapshot sizes.');
      }
      final macOffset = combined.length - 16;
      final clearText = await _algorithm.decrypt(
        SecretBox(
          combined.sublist(0, macOffset),
          nonce: nonce,
          mac: Mac(combined.sublist(macOffset)),
        ),
        secretKey: SecretKey(familyKey),
        aad: _aad(
          familySpaceId,
          snapshot.snapshotId,
          snapshot.sourceDeviceId,
          snapshot.baseServerSeq,
        ),
      );
      final decoded = jsonDecode(utf8.decode(clearText));
      if (decoded is! Map || decoded['schemaVersion'] != 1) {
        throw const FormatException('Invalid encrypted snapshot schema.');
      }
      final encodedChanges = decoded['changes'];
      if (encodedChanges is! List) {
        throw const FormatException('Snapshot changes must be a list.');
      }
      final changes = encodedChanges
          .map((encoded) {
            if (encoded is! Map) {
              throw const FormatException('Invalid snapshot change.');
            }
            final change = SyncChange.fromJson(encoded.cast<String, Object?>());
            if (change.familySpaceId != familySpaceId ||
                change.serverSequence != null) {
              throw const FormatException('Snapshot change identity mismatch.');
            }
            return change;
          })
          .toList(growable: false);
      return FamilySyncStateSnapshot(
        snapshotId: snapshot.snapshotId,
        baseServerSequence: snapshot.baseServerSeq,
        sourceDeviceProfileId: snapshot.sourceDeviceId,
        changes: List.unmodifiable(changes),
        createdAt: snapshot.createdAt,
      );
    } on FamilySyncUnavailable {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const FamilySyncUnavailable('snapshot_authentication_failed');
    } on FormatException {
      throw const FamilySyncUnavailable('invalid_encrypted_snapshot');
    }
  }

  List<int> _aad(
    String familySpaceId,
    String snapshotId,
    String sourceDeviceId,
    int baseServerSeq,
  ) => utf8.encode(
    [
      'mlmd-sync-snapshot',
      '$_snapshotVersion',
      familySpaceId,
      snapshotId,
      sourceDeviceId,
      '$baseServerSeq',
    ].join('\u0000'),
  );

  void _validateKey(List<int> familyKey) {
    if (familyKey.length != 32) {
      throw const FamilySyncUnavailable('family_key_invalid');
    }
  }
}

class HomeServerFamilySyncTransport
    implements FamilySyncTransport, FamilySyncSnapshotTransport {
  HomeServerFamilySyncTransport({
    required this.credentialStore,
    HomeServerSyncApi? api,
    FamilySyncEnvelopeCodec? codec,
    FamilySyncSnapshotCodec? snapshotCodec,
  }) : _api = api ?? IoHomeServerSyncApi(),
       _codec = codec ?? FamilySyncEnvelopeCodec(),
       _snapshotCodec = snapshotCodec ?? FamilySyncSnapshotCodec();

  final FamilySyncCredentialStore credentialStore;
  final HomeServerSyncApi _api;
  final FamilySyncEnvelopeCodec _codec;
  final FamilySyncSnapshotCodec _snapshotCodec;

  @override
  Future<bool> canUploadSnapshot({
    required String familySpaceId,
    required String deviceProfileId,
  }) async {
    final credentials = await _credentials(familySpaceId, deviceProfileId);
    return credentials.canUploadSnapshots;
  }

  @override
  Future<SyncExchange> exchange({
    required String familySpaceId,
    required String deviceProfileId,
    required String? afterCursor,
    required List<SyncChange> outgoingChanges,
  }) async {
    final credentials = await credentialStore.load(familySpaceId);
    if (credentials == null) {
      throw const FamilySyncUnavailable('credentials_not_configured');
    }
    if (credentials.familySpaceId != familySpaceId) {
      throw const FamilySyncUnavailable('credential_space_mismatch');
    }
    final outgoing = <OpaqueSyncEnvelope>[];
    for (final change in outgoingChanges) {
      if (change.familySpaceId != familySpaceId ||
          change.sourceDeviceProfileId != deviceProfileId) {
        throw const FamilySyncUnavailable('outgoing_identity_mismatch');
      }
      outgoing.add(await _codec.encrypt(change, credentials.familyKey));
    }
    final result = await _api.exchange(
      credentials: credentials,
      deviceProfileId: deviceProfileId,
      afterCursor: afterCursor,
      outgoing: outgoing,
    );
    final incoming = <SyncChange>[];
    for (final envelope in result.incoming) {
      incoming.add(
        await _codec.decrypt(
          familySpaceId: familySpaceId,
          envelope: envelope,
          familyKey: credentials.familyKey,
        ),
      );
    }
    return SyncExchange(
      acknowledgedChangeIds: result.acknowledgedChangeIds,
      incomingChanges: incoming,
      nextCursor: result.nextCursor,
    );
  }

  @override
  Future<FamilySyncStateSnapshot> uploadSnapshot({
    required String familySpaceId,
    required String deviceProfileId,
    required int baseServerSequence,
    required List<SyncChange> changes,
  }) async {
    final credentials = await _credentials(familySpaceId, deviceProfileId);
    if (!credentials.canUploadSnapshots) {
      throw const FamilySyncUnavailable('snapshot_owner_required');
    }
    final snapshot = FamilySyncStateSnapshot(
      snapshotId: const Uuid().v4(),
      baseServerSequence: baseServerSequence,
      sourceDeviceProfileId: deviceProfileId,
      changes: List.unmodifiable(changes),
    );
    final encrypted = await _snapshotCodec.encrypt(
      familySpaceId,
      snapshot,
      credentials.familyKey,
    );
    late final OpaqueSyncSnapshot stored;
    try {
      stored = await _api.putSnapshot(
        credentials: credentials,
        deviceProfileId: deviceProfileId,
        snapshot: encrypted,
      );
    } on FamilySyncUnavailable catch (error) {
      if (credentials.role == null && error.code == 'server_owner_required') {
        await credentialStore.save(credentials.withRole('member'));
      }
      rethrow;
    }
    if (credentials.role == null) {
      await credentialStore.save(credentials.withRole('owner'));
    }
    return _snapshotCodec.decrypt(
      familySpaceId: familySpaceId,
      snapshot: stored,
      familyKey: credentials.familyKey,
    );
  }

  @override
  Future<FamilySyncStateSnapshot?> downloadSnapshot({
    required String familySpaceId,
    required String deviceProfileId,
  }) async {
    final credentials = await _credentials(familySpaceId, deviceProfileId);
    final encrypted = await _api.getSnapshot(
      credentials: credentials,
      deviceProfileId: deviceProfileId,
    );
    if (encrypted == null) return null;
    return _snapshotCodec.decrypt(
      familySpaceId: familySpaceId,
      snapshot: encrypted,
      familyKey: credentials.familyKey,
    );
  }

  Future<FamilySyncCredentials> _credentials(
    String familySpaceId,
    String deviceProfileId,
  ) async {
    final credentials = await credentialStore.load(familySpaceId);
    if (credentials == null) {
      throw const FamilySyncUnavailable('credentials_not_configured');
    }
    if (credentials.familySpaceId != familySpaceId) {
      throw const FamilySyncUnavailable('credential_space_mismatch');
    }
    if (!credentials.deviceToken.startsWith('$deviceProfileId.')) {
      throw const FamilySyncUnavailable('device_identity_mismatch');
    }
    return credentials;
  }
}
