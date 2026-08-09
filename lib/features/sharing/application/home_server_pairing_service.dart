import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'family_sync_credentials.dart';
import 'family_sync_transport.dart';

const _pairingProtocolVersion = 1;
const _maxPairingResponseBytes = 256 * 1024;

class BootstrapSpaceResult {
  const BootstrapSpaceResult({
    required this.familySpaceId,
    required this.deviceId,
    required this.role,
  });

  final String familySpaceId;
  final String deviceId;
  final String role;
}

class CreatedInvite {
  const CreatedInvite({
    required this.inviteId,
    required this.familySpaceId,
    required this.inviteToken,
    required this.role,
    required this.expiresAt,
    required this.createdByDeviceId,
  });

  final String inviteId;
  final String familySpaceId;
  final String inviteToken;
  final String role;
  final DateTime expiresAt;
  final String createdByDeviceId;
}

class ConsumedInvite {
  const ConsumedInvite({
    required this.familySpaceId,
    required this.deviceId,
    required this.role,
    required this.displayName,
    required this.createdAt,
  });

  final String familySpaceId;
  final String deviceId;
  final String role;
  final String displayName;
  final DateTime createdAt;
}

class HomeServerDevice {
  const HomeServerDevice({
    required this.deviceId,
    required this.familySpaceId,
    required this.role,
    required this.displayName,
    required this.createdAt,
    required this.lastSeenAt,
    required this.revokedAt,
    required this.isCurrent,
  });

  final String deviceId;
  final String familySpaceId;
  final String role;
  final String displayName;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final DateTime? revokedAt;
  final bool isCurrent;

  bool get isRevoked => revokedAt != null;
}

class RevokedHomeServerDevice {
  const RevokedHomeServerDevice({
    required this.deviceId,
    required this.revokedAt,
  });

  final String deviceId;
  final DateTime revokedAt;
}

abstract interface class HomeServerPairingApi {
  Future<BootstrapSpaceResult> bootstrapSpace({
    required Uri serverUrl,
    required String bootstrapToken,
    required String displayName,
    required String familySpaceId,
    required String deviceId,
    required String deviceDisplayName,
    required String deviceSecret,
  });

  Future<CreatedInvite> createInvite({
    required FamilySyncCredentials credentials,
    required String role,
  });

  Future<ConsumedInvite> consumeInvite({
    required Uri serverUrl,
    required String inviteId,
    required String inviteToken,
    required String deviceId,
    required String deviceDisplayName,
    required String deviceSecret,
  });

  Future<List<HomeServerDevice>> listDevices({
    required FamilySyncCredentials credentials,
  });

  Future<RevokedHomeServerDevice> revokeDevice({
    required FamilySyncCredentials credentials,
    required String deviceId,
  });
}

abstract interface class HomeServerPairingLocalState {
  String get currentDeviceId;

  void connect({required String familySpaceId, required String displayName});
}

class IoHomeServerPairingApi implements HomeServerPairingApi {
  IoHomeServerPairingApi({HttpClient? client})
    : _client = client ?? HttpClient(),
      _ownsClient = client == null;

  final HttpClient _client;
  final bool _ownsClient;

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
    final json = await _post(
      serverUrl.resolve('/v1/bootstrap/spaces'),
      bearerToken: bootstrapToken,
      body: {
        'displayName': displayName,
        'familySpaceId': familySpaceId,
        'deviceId': deviceId,
        'deviceDisplayName': deviceDisplayName,
        'deviceSecret': deviceSecret,
      },
    );
    return BootstrapSpaceResult(
      familySpaceId: _string(json, 'familySpaceId'),
      deviceId: _string(json, 'deviceId'),
      role: _string(json, 'role'),
    );
  }

  @override
  Future<CreatedInvite> createInvite({
    required FamilySyncCredentials credentials,
    required String role,
  }) async {
    final json = await _post(
      credentials.serverUrl.resolve(
        '/v1/spaces/${Uri.encodeComponent(credentials.familySpaceId)}/invites',
      ),
      bearerToken: credentials.deviceToken,
      body: {'role': role},
    );
    return CreatedInvite(
      inviteId: _string(json, 'inviteId'),
      familySpaceId: _string(json, 'familySpaceId'),
      inviteToken: _string(json, 'inviteToken'),
      role: _string(json, 'role'),
      expiresAt: DateTime.parse(_string(json, 'expiresAt')),
      createdByDeviceId: _string(json, 'createdByDeviceId'),
    );
  }

  @override
  Future<ConsumedInvite> consumeInvite({
    required Uri serverUrl,
    required String inviteId,
    required String inviteToken,
    required String deviceId,
    required String deviceDisplayName,
    required String deviceSecret,
  }) async {
    final json = await _post(
      serverUrl.resolve('/v1/invites/${Uri.encodeComponent(inviteId)}/consume'),
      body: {
        'inviteToken': inviteToken,
        'deviceId': deviceId,
        'deviceDisplayName': deviceDisplayName,
        'deviceSecret': deviceSecret,
      },
    );
    return ConsumedInvite(
      familySpaceId: _string(json, 'familySpaceId'),
      deviceId: _string(json, 'deviceId'),
      role: _string(json, 'role'),
      displayName: _string(json, 'displayName'),
      createdAt: DateTime.parse(_string(json, 'createdAt')),
    );
  }

  @override
  Future<List<HomeServerDevice>> listDevices({
    required FamilySyncCredentials credentials,
  }) async {
    final json = await _request(
      'GET',
      credentials.serverUrl.resolve(
        '/v1/spaces/${Uri.encodeComponent(credentials.familySpaceId)}/devices',
      ),
      bearerToken: credentials.deviceToken,
      expectedStatus: HttpStatus.ok,
    );
    final rawDevices = json['devices'];
    if (rawDevices is! List) {
      throw const FamilySyncUnavailable('invalid_server_response');
    }
    return List.unmodifiable(
      rawDevices.map((raw) {
        if (raw is! Map) {
          throw const FormatException('Device must be an object.');
        }
        final device = raw.cast<String, Object?>();
        return HomeServerDevice(
          deviceId: _string(device, 'deviceId'),
          familySpaceId: _string(device, 'familySpaceId'),
          role: _string(device, 'role'),
          displayName: _string(device, 'displayName'),
          createdAt: DateTime.parse(_string(device, 'createdAt')),
          lastSeenAt: _nullableDateTime(device, 'lastSeenAt'),
          revokedAt: _nullableDateTime(device, 'revokedAt'),
          isCurrent: _bool(device, 'isCurrent'),
        );
      }),
    );
  }

  @override
  Future<RevokedHomeServerDevice> revokeDevice({
    required FamilySyncCredentials credentials,
    required String deviceId,
  }) async {
    final json = await _request(
      'DELETE',
      credentials.serverUrl.resolve(
        '/v1/spaces/${Uri.encodeComponent(credentials.familySpaceId)}/devices/${Uri.encodeComponent(deviceId)}',
      ),
      bearerToken: credentials.deviceToken,
      expectedStatus: HttpStatus.ok,
    );
    return RevokedHomeServerDevice(
      deviceId: _string(json, 'deviceId'),
      revokedAt: DateTime.parse(_string(json, 'revokedAt')),
    );
  }

  void close() {
    if (_ownsClient) _client.close(force: true);
  }

  Future<Map<String, Object?>> _post(
    Uri endpoint, {
    String? bearerToken,
    required Map<String, Object?> body,
  }) => _request(
    'POST',
    endpoint,
    bearerToken: bearerToken,
    body: body,
    expectedStatus: HttpStatus.created,
  );

  Future<Map<String, Object?>> _request(
    String method,
    Uri endpoint, {
    String? bearerToken,
    Map<String, Object?>? body,
    required int expectedStatus,
  }) async {
    try {
      final request = await _client.openUrl(method, endpoint);
      if (body != null) request.headers.contentType = ContentType.json;
      if (bearerToken != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $bearerToken',
        );
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final responseBody = await _readLimited(response);
      if (response.statusCode != expectedStatus) {
        throw FamilySyncUnavailable(_serverErrorCode(responseBody));
      }
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) {
        throw const FormatException('Pairing response must be an object.');
      }
      return decoded.cast<String, Object?>();
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

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing $key.');
    }
    return value;
  }

  bool _bool(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('Missing $key.');
    return value;
  }

  DateTime? _nullableDateTime(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid $key.');
    }
    return DateTime.parse(value);
  }

  Future<String> _readLimited(HttpClientResponse response) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > _maxPairingResponseBytes) {
        throw const FamilySyncUnavailable('server_response_too_large');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
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
}

class FamilyInviteQrPayload {
  FamilyInviteQrPayload({
    required this.serverUrl,
    required this.familySpaceId,
    required this.familyDisplayName,
    required this.inviteId,
    required this.inviteToken,
    required this.inviterDeviceId,
    required this.role,
    required this.expiresAt,
    required List<int> familyKey,
  }) : familyKey = List<int>.unmodifiable(familyKey) {
    if (familyKey.length != 32) {
      throw const FormatException('Family key must be 32 bytes.');
    }
    if ((serverUrl.scheme != 'http' && serverUrl.scheme != 'https') ||
        serverUrl.host.isEmpty ||
        serverUrl.userInfo.isNotEmpty ||
        serverUrl.hasQuery ||
        serverUrl.hasFragment ||
        (serverUrl.path.isNotEmpty && serverUrl.path != '/')) {
      throw const FormatException('Invalid server URL.');
    }
  }

  final Uri serverUrl;
  final String familySpaceId;
  final String familyDisplayName;
  final String inviteId;
  final String inviteToken;
  final String inviterDeviceId;
  final String role;
  final DateTime expiresAt;
  final List<int> familyKey;

  String encode() {
    final encoded = base64UrlEncode(
      utf8.encode(
        jsonEncode({
          'protocolVersion': _pairingProtocolVersion,
          'serverUrl': serverUrl.toString(),
          'familySpaceId': familySpaceId,
          'familyDisplayName': familyDisplayName,
          'inviteId': inviteId,
          'inviteToken': inviteToken,
          'inviterDeviceId': inviterDeviceId,
          'role': role,
          'expiresAt': expiresAt.toUtc().toIso8601String(),
          'familyKey': base64UrlEncode(familyKey).replaceAll('=', ''),
        }),
      ),
    ).replaceAll('=', '');
    return 'mlmd://pair/v1?payload=$encoded';
  }

  factory FamilyInviteQrPayload.decode(String value) {
    if (value.length > 8192) {
      throw const FormatException('Pairing payload is too large.');
    }
    final uri = Uri.parse(value);
    if (uri.scheme != 'mlmd' || uri.host != 'pair' || uri.path != '/v1') {
      throw const FormatException('Unsupported pairing URI.');
    }
    final encoded = uri.queryParameters['payload'];
    if (encoded == null || encoded.isEmpty) {
      throw const FormatException('Pairing payload is missing.');
    }
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
    );
    if (decoded is! Map || decoded['protocolVersion'] != 1) {
      throw const FormatException('Unsupported pairing payload.');
    }
    final json = decoded.cast<String, Object?>();
    String requiredString(String key) {
      final item = json[key];
      if (item is! String || item.isEmpty) {
        throw FormatException('Missing $key.');
      }
      return item;
    }

    final key = base64Url.decode(
      base64Url.normalize(requiredString('familyKey')),
    );
    return FamilyInviteQrPayload(
      serverUrl: Uri.parse(requiredString('serverUrl')),
      familySpaceId: requiredString('familySpaceId'),
      familyDisplayName: requiredString('familyDisplayName'),
      inviteId: requiredString('inviteId'),
      inviteToken: requiredString('inviteToken'),
      inviterDeviceId: requiredString('inviterDeviceId'),
      role: requiredString('role'),
      expiresAt: DateTime.parse(requiredString('expiresAt')),
      familyKey: key,
    );
  }
}

class HomeServerPairingService {
  HomeServerPairingService({
    required this.api,
    required this.credentialStore,
    required this.localState,
  });

  static const _uuid = Uuid();
  final HomeServerPairingApi api;
  final FamilySyncCredentialStore credentialStore;
  final HomeServerPairingLocalState localState;

  Future<FamilySyncCredentials> bootstrap({
    required Uri serverUrl,
    required String bootstrapToken,
    required String familyDisplayName,
    required String deviceDisplayName,
  }) async {
    final familySpaceId = _uuid.v4();
    final deviceId = localState.currentDeviceId;
    final deviceSecret =
        await SecureFamilySyncCredentialStore.createRandomSecret();
    final key = SecretKeyData.random(length: 32);
    try {
      final result = await _retryNetworkOnce(
        () => api.bootstrapSpace(
          serverUrl: serverUrl,
          bootstrapToken: bootstrapToken,
          displayName: familyDisplayName,
          familySpaceId: familySpaceId,
          deviceId: deviceId,
          deviceDisplayName: deviceDisplayName,
          deviceSecret: deviceSecret,
        ),
      );
      if (result.familySpaceId != familySpaceId ||
          result.deviceId != deviceId ||
          result.role != 'owner') {
        throw const FamilySyncUnavailable('bootstrap_identity_mismatch');
      }
      final credentials = FamilySyncCredentials(
        serverUrl: serverUrl,
        familySpaceId: familySpaceId,
        deviceToken: '$deviceId.$deviceSecret',
        familyKey: key.bytes,
      );
      await credentialStore.save(credentials);
      localState.connect(
        familySpaceId: familySpaceId,
        displayName: familyDisplayName,
      );
      return credentials;
    } finally {
      key.destroy();
    }
  }

  Future<FamilyInviteQrPayload> createInvite({
    required String familySpaceId,
    required String familyDisplayName,
    String role = 'member',
  }) async {
    final credentials = await credentialStore.load(familySpaceId);
    if (credentials == null) {
      throw const FamilySyncUnavailable('credentials_not_configured');
    }
    final invite = await api.createInvite(credentials: credentials, role: role);
    if (invite.familySpaceId != familySpaceId || invite.role != role) {
      throw const FamilySyncUnavailable('invite_identity_mismatch');
    }
    return FamilyInviteQrPayload(
      serverUrl: credentials.serverUrl,
      familySpaceId: familySpaceId,
      familyDisplayName: familyDisplayName,
      inviteId: invite.inviteId,
      inviteToken: invite.inviteToken,
      inviterDeviceId: invite.createdByDeviceId,
      role: invite.role,
      expiresAt: invite.expiresAt,
      familyKey: credentials.familyKey,
    );
  }

  Future<FamilySyncCredentials> join({
    required FamilyInviteQrPayload invite,
    required String deviceDisplayName,
  }) async {
    if (!invite.expiresAt.isAfter(DateTime.now())) {
      throw const FamilySyncUnavailable('invite_expired');
    }
    final deviceId = localState.currentDeviceId;
    var credentials = await credentialStore.load(invite.familySpaceId);
    if (credentials != null &&
        (credentials.serverUrl != invite.serverUrl ||
            !_bytesEqual(credentials.familyKey, invite.familyKey) ||
            !credentials.deviceToken.startsWith('$deviceId.'))) {
      throw const FamilySyncUnavailable('family_space_credentials_conflict');
    }
    if (credentials == null) {
      final secret = await SecureFamilySyncCredentialStore.createRandomSecret();
      credentials = FamilySyncCredentials(
        serverUrl: invite.serverUrl,
        familySpaceId: invite.familySpaceId,
        deviceToken: '$deviceId.$secret',
        familyKey: invite.familyKey,
      );
      await credentialStore.save(credentials);
    }
    final deviceSecret = credentials.deviceToken.substring(deviceId.length + 1);
    final consumed = await _retryNetworkOnce(
      () => api.consumeInvite(
        serverUrl: invite.serverUrl,
        inviteId: invite.inviteId,
        inviteToken: invite.inviteToken,
        deviceId: deviceId,
        deviceDisplayName: deviceDisplayName,
        deviceSecret: deviceSecret,
      ),
    );
    if (consumed.familySpaceId != invite.familySpaceId ||
        consumed.deviceId != deviceId ||
        consumed.role != invite.role) {
      throw const FamilySyncUnavailable('invite_identity_mismatch');
    }
    localState.connect(
      familySpaceId: invite.familySpaceId,
      displayName: invite.familyDisplayName,
    );
    return credentials;
  }

  Future<List<HomeServerDevice>> listDevices({
    required String familySpaceId,
  }) async {
    final credentials = await _requireCredentials(familySpaceId);
    final devices = await api.listDevices(credentials: credentials);
    if (devices.any((device) => device.familySpaceId != familySpaceId)) {
      throw const FamilySyncUnavailable('device_identity_mismatch');
    }
    final current = devices.where((device) => device.isCurrent).toList();
    if (current.length != 1 ||
        current.single.deviceId != localState.currentDeviceId) {
      throw const FamilySyncUnavailable('device_identity_mismatch');
    }
    return devices;
  }

  Future<DateTime> revokeDevice({
    required String familySpaceId,
    required String deviceId,
  }) async {
    if (deviceId == localState.currentDeviceId) {
      throw const FamilySyncUnavailable('cannot_revoke_current_device');
    }
    final credentials = await _requireCredentials(familySpaceId);
    final result = await _retryNetworkOnce(
      () => api.revokeDevice(credentials: credentials, deviceId: deviceId),
    );
    if (result.deviceId != deviceId) {
      throw const FamilySyncUnavailable('device_identity_mismatch');
    }
    return result.revokedAt;
  }

  Future<FamilySyncCredentials> _requireCredentials(
    String familySpaceId,
  ) async {
    final credentials = await credentialStore.load(familySpaceId);
    if (credentials == null) {
      throw const FamilySyncUnavailable('credentials_not_configured');
    }
    return credentials;
  }

  Future<T> _retryNetworkOnce<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FamilySyncUnavailable catch (error) {
      if (error.code != 'home_server_timeout' &&
          error.code != 'home_server_unreachable') {
        rethrow;
      }
      return operation();
    }
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
