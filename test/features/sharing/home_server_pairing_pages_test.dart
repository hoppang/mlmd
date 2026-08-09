import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/sharing/application/family_sync_credentials.dart';
import 'package:mlmd/features/sharing/application/family_sync_transport_provider.dart';
import 'package:mlmd/features/sharing/application/home_server_pairing_service.dart';
import 'package:mlmd/features/sharing/presentation/home_server_pairing_pages.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

Widget _localized(Widget home) => MaterialApp(
  locale: const Locale('ko'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

class _CredentialStore implements FamilySyncCredentialStore {
  _CredentialStore(this.credentials);

  final FamilySyncCredentials credentials;

  @override
  Future<void> delete(String familySpaceId) async {}

  @override
  Future<FamilySyncCredentials?> load(String familySpaceId) async =>
      familySpaceId == credentials.familySpaceId ? credentials : null;

  @override
  Future<void> save(FamilySyncCredentials credentials) async {}
}

class _LocalState implements HomeServerPairingLocalState {
  @override
  String get currentDeviceId => '11111111-2222-4333-8444-555555555555';

  @override
  void connect({required String familySpaceId, required String displayName}) {}
}

class _DeviceApi implements HomeServerPairingApi {
  static const spaceId = '550e8400-e29b-41d4-a716-446655440000';
  static const currentId = '11111111-2222-4333-8444-555555555555';
  static const otherId = '66666666-7777-4888-8999-aaaaaaaaaaaa';
  DateTime? revokedAt;

  @override
  Future<List<HomeServerDevice>> listDevices({
    required FamilySyncCredentials credentials,
  }) async => [
    HomeServerDevice(
      deviceId: currentId,
      familySpaceId: spaceId,
      role: 'owner',
      displayName: '내 휴대폰',
      createdAt: DateTime.utc(2026, 8, 3),
      lastSeenAt: DateTime.utc(2026, 8, 3, 1),
      revokedAt: null,
      isCurrent: true,
    ),
    HomeServerDevice(
      deviceId: otherId,
      familySpaceId: spaceId,
      role: 'member',
      displayName: '가족 태블릿',
      createdAt: DateTime.utc(2026, 8, 3),
      lastSeenAt: null,
      revokedAt: revokedAt,
      isCurrent: false,
    ),
  ];

  @override
  Future<RevokedHomeServerDevice> revokeDevice({
    required FamilySyncCredentials credentials,
    required String deviceId,
  }) async {
    revokedAt = DateTime.utc(2026, 8, 3, 13);
    return RevokedHomeServerDevice(deviceId: deviceId, revokedAt: revokedAt!);
  }

  @override
  Future<BootstrapSpaceResult> bootstrapSpace({
    required Uri serverUrl,
    required String bootstrapToken,
    required String displayName,
    required String familySpaceId,
    required String deviceId,
    required String deviceDisplayName,
    required String deviceSecret,
  }) => throw UnimplementedError();

  @override
  Future<ConsumedInvite> consumeInvite({
    required Uri serverUrl,
    required String inviteId,
    required String inviteToken,
    required String deviceId,
    required String deviceDisplayName,
    required String deviceSecret,
  }) => throw UnimplementedError();

  @override
  Future<CreatedInvite> createInvite({
    required FamilySyncCredentials credentials,
    required String role,
  }) => throw UnimplementedError();
}

void main() {
  testWidgets('bootstrap page validates server and required pairing fields', (
    tester,
  ) async {
    await tester.pumpWidget(_localized(const HomeServerBootstrapPage()));

    expect(find.byKey(const Key('home-server-url')), findsOneWidget);
    expect(
      find.byKey(const Key('home-server-bootstrap-token')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('home-server-connect')));
    await tester.pump();

    expect(find.text('필수 항목입니다.'), findsNWidgets(3));
    expect(find.text('http 또는 https로 시작하는 홈서버 주소를 입력하세요.'), findsOneWidget);
  });

  testWidgets('invite page renders the secret-bearing QR and warning', (
    tester,
  ) async {
    final invite = FamilyInviteQrPayload(
      serverUrl: Uri.parse('http://192.168.0.10:8080'),
      familySpaceId: '550e8400-e29b-41d4-a716-446655440000',
      familyDisplayName: '우리 가족',
      inviteId: '550e8400-e29b-41d4-a716-446655440100',
      inviteToken:
          '550e8400-e29b-41d4-a716-446655440100.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      inviterDeviceId: '11111111-2222-4333-8444-555555555555',
      role: 'member',
      expiresAt: DateTime.utc(2026, 8, 3, 12, 10),
      familyKey: List.filled(32, 1),
    );

    await tester.pumpWidget(_localized(HomeServerInvitePage(invite: invite)));

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('암호화 키'), findsOneWidget);
  });

  testWidgets('device page protects current device and revokes another', (
    tester,
  ) async {
    final api = _DeviceApi();
    final credentials = FamilySyncCredentials(
      serverUrl: Uri.parse('http://server.local:8080'),
      familySpaceId: _DeviceApi.spaceId,
      deviceToken: '${_DeviceApi.currentId}.secret',
      familyKey: List.filled(32, 1),
    );
    final service = HomeServerPairingService(
      api: api,
      credentialStore: _CredentialStore(credentials),
      localState: _LocalState(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeServerPairingServiceProvider.overrideWithValue(service),
        ],
        child: _localized(
          const HomeServerDevicesPage(familySpaceId: _DeviceApi.spaceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('현재 기기'), findsOneWidget);
    expect(
      find.byKey(const Key('revoke-device-${_DeviceApi.currentId}')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('revoke-device-${_DeviceApi.otherId}')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('revoke-device-${_DeviceApi.otherId}')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('원격으로 지울 수는 없습니다'), findsOneWidget);
    await tester.tap(find.text('기기 연결 해제'));
    await tester.pumpAndSettle();

    expect(find.textContaining('연결 해제됨'), findsOneWidget);
    expect(
      find.byKey(const Key('revoke-device-${_DeviceApi.otherId}')),
      findsNothing,
    );
  });
}
