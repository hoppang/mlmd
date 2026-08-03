import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'family_sync_transport.dart';

class FamilySyncCredentials {
  FamilySyncCredentials({
    required this.serverUrl,
    required this.familySpaceId,
    required this.deviceToken,
    required List<int> familyKey,
  }) : familyKey = List<int>.unmodifiable(familyKey) {
    if ((serverUrl.scheme != 'http' && serverUrl.scheme != 'https') ||
        serverUrl.host.isEmpty ||
        serverUrl.userInfo.isNotEmpty ||
        serverUrl.hasFragment ||
        serverUrl.hasQuery ||
        (serverUrl.path.isNotEmpty && serverUrl.path != '/')) {
      throw ArgumentError.value(serverUrl, 'serverUrl', 'Invalid server URL.');
    }
    if (familySpaceId.trim().isEmpty || deviceToken.trim().isEmpty) {
      throw ArgumentError('Family space and device token are required.');
    }
    if (familyKey.length != 32) {
      throw ArgumentError.value(
        familyKey.length,
        'familyKey',
        'Must be 32 bytes.',
      );
    }
  }

  final Uri serverUrl;
  final String familySpaceId;
  final String deviceToken;
  final List<int> familyKey;
}

abstract interface class FamilySyncCredentialStore {
  Future<FamilySyncCredentials?> load(String familySpaceId);
  Future<void> save(FamilySyncCredentials credentials);
  Future<void> delete(String familySpaceId);
}

class SecureFamilySyncCredentialStore implements FamilySyncCredentialStore {
  const SecureFamilySyncCredentialStore({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;

  @override
  Future<FamilySyncCredentials?> load(String familySpaceId) async {
    final prefix = _prefix(familySpaceId);
    final values = await Future.wait([
      storage.read(key: '$prefix.serverUrl'),
      storage.read(key: '$prefix.deviceToken'),
      storage.read(key: '$prefix.familyKey'),
    ]);
    if (values.every((value) => value == null)) return null;
    if (values.any((value) => value == null)) {
      throw const FamilySyncUnavailable('credentials_incomplete');
    }
    try {
      final key = base64Url.decode(base64Url.normalize(values[2]!));
      return FamilySyncCredentials(
        serverUrl: Uri.parse(values[0]!),
        familySpaceId: familySpaceId,
        deviceToken: values[1]!,
        familyKey: key,
      );
    } on FormatException {
      throw const FamilySyncUnavailable('credentials_invalid');
    } on ArgumentError {
      throw const FamilySyncUnavailable('credentials_invalid');
    }
  }

  @override
  Future<void> save(FamilySyncCredentials credentials) async {
    final prefix = _prefix(credentials.familySpaceId);
    await storage.write(
      key: '$prefix.serverUrl',
      value: credentials.serverUrl.toString(),
    );
    await storage.write(
      key: '$prefix.deviceToken',
      value: credentials.deviceToken,
    );
    await storage.write(
      key: '$prefix.familyKey',
      value: base64UrlEncode(credentials.familyKey).replaceAll('=', ''),
    );
  }

  @override
  Future<void> delete(String familySpaceId) async {
    final prefix = _prefix(familySpaceId);
    await Future.wait([
      storage.delete(key: '$prefix.serverUrl'),
      storage.delete(key: '$prefix.deviceToken'),
      storage.delete(key: '$prefix.familyKey'),
    ]);
  }

  static Future<String> createRandomSecret() async {
    final secret = SecretKeyData.random(length: 32);
    try {
      return base64UrlEncode(secret.bytes).replaceAll('=', '');
    } finally {
      secret.destroy();
    }
  }

  String _prefix(String familySpaceId) {
    final normalized = familySpaceId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(familySpaceId, 'familySpaceId');
    }
    return 'mlmd.familySync.$normalized';
  }
}
