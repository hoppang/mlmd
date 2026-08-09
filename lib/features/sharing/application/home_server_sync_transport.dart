import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../domain/family_sync_models.dart';
import 'family_sync_credentials.dart';
import 'family_sync_transport.dart';

const _protocolVersion = 1;
const _envelopeVersion = 1;
const _maxResponseBytes = 2 * 1024 * 1024;

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

abstract interface class HomeServerSyncApi {
  Future<OpaqueSyncExchange> exchange({
    required FamilySyncCredentials credentials,
    required String deviceProfileId,
    required String? afterCursor,
    required List<OpaqueSyncEnvelope> outgoing,
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

class HomeServerFamilySyncTransport implements FamilySyncTransport {
  HomeServerFamilySyncTransport({
    required this.credentialStore,
    HomeServerSyncApi? api,
    FamilySyncEnvelopeCodec? codec,
  }) : _api = api ?? IoHomeServerSyncApi(),
       _codec = codec ?? FamilySyncEnvelopeCodec();

  final FamilySyncCredentialStore credentialStore;
  final HomeServerSyncApi _api;
  final FamilySyncEnvelopeCodec _codec;

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
}
