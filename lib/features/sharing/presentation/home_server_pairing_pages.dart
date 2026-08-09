import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/family_sync_transport.dart';
import '../application/family_sync_transport_provider.dart';
import '../application/home_server_pairing_service.dart';

class HomeServerBootstrapPage extends ConsumerStatefulWidget {
  const HomeServerBootstrapPage({super.key});

  @override
  ConsumerState<HomeServerBootstrapPage> createState() =>
      _HomeServerBootstrapPageState();
}

class _HomeServerBootstrapPageState
    extends ConsumerState<HomeServerBootstrapPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrl = TextEditingController();
  final _bootstrapToken = TextEditingController();
  final _familyName = TextEditingController();
  final _deviceName = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _serverUrl.dispose();
    _bootstrapToken.dispose();
    _familyName.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.homeServerConnectTitle)),
      body: AdaptiveContentFrame(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppInsets.page,
            children: [
              Text(
                loc.homeServerConnectDescription,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('home-server-url'),
                controller: _serverUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: loc.homeServerUrlLabel,
                  hintText: 'http://192.168.0.10:8080',
                ),
                validator: (value) =>
                    _validServerUrl(value) ? null : loc.homeServerInvalidUrl,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const Key('home-server-bootstrap-token'),
                controller: _bootstrapToken,
                autocorrect: false,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: loc.homeServerBootstrapTokenLabel,
                ),
                validator: (value) => (value?.trim().isNotEmpty ?? false)
                    ? null
                    : loc.homeServerRequiredField,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const Key('home-server-family-name'),
                controller: _familyName,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: loc.homeServerFamilyNameLabel,
                ),
                validator: (value) => (value?.trim().isNotEmpty ?? false)
                    ? null
                    : loc.homeServerRequiredField,
              ),
              TextFormField(
                key: const Key('home-server-device-name'),
                controller: _deviceName,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: loc.homeServerDeviceNameLabel,
                ),
                validator: (value) => (value?.trim().isNotEmpty ?? false)
                    ? null
                    : loc.homeServerRequiredField,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const Key('home-server-connect'),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.dns_outlined),
                label: Text(loc.homeServerConnectAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _validServerUrl(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.path.isEmpty || uri.path == '/');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(homeServerPairingServiceProvider)
          .bootstrap(
            serverUrl: Uri.parse(_serverUrl.text.trim()),
            bootstrapToken: _bootstrapToken.text.trim(),
            familyDisplayName: _familyName.text.trim(),
            deviceDisplayName: _deviceName.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on FamilySyncUnavailable catch (error) {
      if (mounted) _showPairingError(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class HomeServerJoinPage extends ConsumerStatefulWidget {
  const HomeServerJoinPage({super.key});

  @override
  ConsumerState<HomeServerJoinPage> createState() => _HomeServerJoinPageState();
}

class _HomeServerJoinPageState extends ConsumerState<HomeServerJoinPage> {
  final _deviceName = TextEditingController();
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handling = false;
  bool _completed = false;

  @override
  void dispose() {
    _deviceName.dispose();
    unawaited(_scanner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.homeServerJoinTitle)),
      body: AdaptiveContentFrame(
        child: ListView(
          padding: AppInsets.page,
          children: [
            Text(loc.homeServerJoinDescription),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('home-server-join-device-name'),
              controller: _deviceName,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: loc.homeServerDeviceNameLabel,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: SizedBox(
                height: 360,
                child: MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Center(child: Text(loc.homeServerCameraError)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              loc.homeServerQrSecurityNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;
    setState(() => _handling = true);
    await _scanner.stop();
    try {
      final invite = FamilyInviteQrPayload.decode(raw);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(invite.familyDisplayName),
          content: Text(
            AppLocalizations.of(
              context,
            )!.homeServerJoinConfirm(invite.serverUrl.host),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppLocalizations.of(context)!.homeServerJoinAction),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (_deviceName.text.trim().isEmpty) {
        throw const FamilySyncUnavailable('device_name_required');
      }
      await ref
          .read(homeServerPairingServiceProvider)
          .join(invite: invite, deviceDisplayName: _deviceName.text.trim());
      _completed = true;
      if (mounted) Navigator.of(context).pop(true);
    } on FormatException {
      if (mounted && !_completed) {
        _showMessage(
          context,
          AppLocalizations.of(context)!.homeServerInvalidQr,
        );
      }
    } on FamilySyncUnavailable catch (error) {
      if (mounted) _showPairingError(context, error);
    } finally {
      if (mounted && !_completed) {
        setState(() => _handling = false);
        unawaited(_scanner.start());
      }
    }
  }
}

class HomeServerInvitePage extends StatelessWidget {
  const HomeServerInvitePage({required this.invite, super.key});

  final FamilyInviteQrPayload invite;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.homeServerInviteTitle)),
      body: AdaptiveContentFrame(
        child: ListView(
          padding: AppInsets.page,
          children: [
            Text(
              loc.homeServerInviteDescription,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Semantics(
                label: loc.homeServerInviteQrSemantics,
                child: QrImageView(
                  data: invite.encode(),
                  size: 280,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              loc.homeServerQrSecurityNotice,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeServerDevicesPage extends ConsumerStatefulWidget {
  const HomeServerDevicesPage({required this.familySpaceId, super.key});

  final String familySpaceId;

  @override
  ConsumerState<HomeServerDevicesPage> createState() =>
      _HomeServerDevicesPageState();
}

class _HomeServerDevicesPageState extends ConsumerState<HomeServerDevicesPage> {
  List<HomeServerDevice>? _devices;
  FamilySyncUnavailable? _error;
  final Set<String> _revoking = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.homeServerDevicesTitle),
        actions: [
          IconButton(
            tooltip: loc.homeServerDevicesRefresh,
            onPressed: _devices == null ? null : _load,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: AdaptiveContentFrame(child: _buildBody(context, loc)),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations loc) {
    if (_devices == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      final ownerRequired = _error!.code == 'server_owner_required';
      return Center(
        child: Padding(
          padding: AppInsets.page,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ownerRequired
                    ? Icons.admin_panel_settings_outlined
                    : Icons.cloud_off_outlined,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                ownerRequired
                    ? loc.homeServerDevicesOwnerOnly
                    : loc.homeServerDevicesLoadFailed,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_outlined),
                label: Text(loc.homeServerDevicesRefresh),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppInsets.page,
      itemCount: _devices!.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final device = _devices![index];
        return Card(
          child: ListTile(
            leading: Icon(
              device.isCurrent
                  ? Icons.smartphone_outlined
                  : Icons.devices_other_outlined,
            ),
            title: Text(device.displayName),
            subtitle: Text(_deviceDescription(context, loc, device)),
            isThreeLine: true,
            trailing: device.isCurrent || device.isRevoked
                ? null
                : IconButton(
                    key: Key('revoke-device-${device.deviceId}'),
                    tooltip: loc.homeServerDeviceRevokeAction,
                    onPressed: _revoking.contains(device.deviceId)
                        ? null
                        : () => _confirmRevoke(device),
                    icon: _revoking.contains(device.deviceId)
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_remove_outlined),
                  ),
          ),
        );
      },
    );
  }

  String _deviceDescription(
    BuildContext context,
    AppLocalizations loc,
    HomeServerDevice device,
  ) {
    final role = device.role == 'owner'
        ? loc.homeServerDeviceRoleOwner
        : loc.homeServerDeviceRoleMember;
    final status = device.isRevoked
        ? loc.homeServerDeviceRevoked
        : device.isCurrent
        ? loc.homeServerDeviceCurrent
        : device.lastSeenAt == null
        ? loc.homeServerDeviceNeverSeen
        : loc.homeServerDeviceLastSeen(
            MaterialLocalizations.of(
              context,
            ).formatFullDate(device.lastSeenAt!.toLocal()),
            TimeOfDay.fromDateTime(
              device.lastSeenAt!.toLocal(),
            ).format(context),
          );
    return '$role\n$status';
  }

  Future<void> _load() async {
    setState(() {
      _devices = null;
      _error = null;
    });
    try {
      final devices = await ref
          .read(homeServerPairingServiceProvider)
          .listDevices(familySpaceId: widget.familySpaceId);
      if (mounted) setState(() => _devices = devices);
    } on FamilySyncUnavailable catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _confirmRevoke(HomeServerDevice device) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.homeServerDeviceRevokeTitle),
        content: Text(loc.homeServerDeviceRevokeConfirm(device.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(loc.homeServerDeviceRevokeAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _revoking.add(device.deviceId));
    try {
      await ref
          .read(homeServerPairingServiceProvider)
          .revokeDevice(
            familySpaceId: widget.familySpaceId,
            deviceId: device.deviceId,
          );
      if (!mounted) return;
      _showMessage(context, loc.homeServerDeviceRevokedSuccess);
      await _load();
    } on FamilySyncUnavailable catch (error) {
      if (mounted) _showPairingError(context, error);
    } finally {
      if (mounted) setState(() => _revoking.remove(device.deviceId));
    }
  }
}

void _showPairingError(BuildContext context, FamilySyncUnavailable error) {
  final loc = AppLocalizations.of(context)!;
  final message = switch (error.code) {
    'invite_expired' || 'server_invite_expired' => loc.homeServerInviteExpired,
    'device_name_required' => loc.homeServerDeviceNameRequired,
    'home_server_timeout' ||
    'home_server_unreachable' => loc.homeServerUnavailable,
    _ => loc.homeServerPairingFailed,
  };
  _showMessage(context, message);
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
