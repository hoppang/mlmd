import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/family_sync_models.dart';
import '../../../repositories/family_sync_repository.dart';
import '../application/family_sync_transport.dart';
import '../application/family_sync_transport_provider.dart';
import '../domain/family_sync_conflict_policy.dart';
import 'family_sync_conflicts_page.dart';
import 'home_server_pairing_pages.dart';

class FamilySharingPage extends ConsumerWidget {
  const FamilySharingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final snapshot = ref.watch(familySyncStatusProvider);
    final criticalConflicts = ref
        .watch(familySyncConflictsProvider)
        .where(
          (conflict) =>
              !conflict.isResolved &&
              FamilySyncConflictPolicy.importanceOf(conflict) ==
                  FamilySyncConflictImportance.critical,
        )
        .toList();
    final resolutionNotices = ref.watch(familySyncResolutionNoticesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.familySharing)),
      body: AdaptiveContentFrame(
        child: ListView(
          padding: AppInsets.page,
          children: [
            Text(
              loc.familySharingIntro,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            if (snapshot.isConnected) ...[
              if (criticalConflicts.isNotEmpty) ...[
                _CriticalConflictNotice(
                  conflict: criticalConflicts.first,
                  totalCount: criticalConflicts.length,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (resolutionNotices.isNotEmpty) ...[
                _ResolutionCollisionNotice(notice: resolutionNotices.first),
                const SizedBox(height: AppSpacing.sm),
              ],
              _ConnectedFamilyCard(snapshot: snapshot),
            ] else
              Card(
                key: const Key('family-sharing-not-connected'),
                child: Padding(
                  padding: AppInsets.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.group_add_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        loc.familySharingNotConnectedTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(loc.familySharingNotConnectedDescription),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        key: const Key('family-sharing-connect-home-server'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const HomeServerBootstrapPage(),
                          ),
                        ),
                        icon: const Icon(Icons.dns_outlined),
                        label: Text(loc.homeServerConnectAction),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton.icon(
                        key: const Key('family-sharing-join-home-server'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const HomeServerJoinPage(),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_outlined),
                        label: Text(loc.homeServerJoinAction),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            _BoundaryCard(
              icon: Icons.offline_bolt_outlined,
              title: loc.familySharingLocalFirstTitle,
              description: loc.familySharingLocalFirstDescription,
            ),
            const SizedBox(height: AppSpacing.sm),
            _BoundaryCard(
              icon: Icons.text_snippet_outlined,
              title: loc.familySharingTextOnlyTitle,
              description: loc.familySharingTextOnlyDescription,
            ),
          ],
        ),
      ),
    );
  }
}

class _CriticalConflictNotice extends StatelessWidget {
  const _CriticalConflictNotice({
    required this.conflict,
    required this.totalCount,
  });

  final FamilySyncConflict conflict;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final local = FamilySyncConflictPolicy.medicationVersion(
      conflict.localPayload,
    );
    final incoming = FamilySyncConflictPolicy.medicationVersion(
      conflict.incomingPayload,
      fallbackAuthorProfileId: conflict.incomingSourceAuthorProfileId,
      fallbackDeviceProfileId: conflict.incomingSourceDeviceProfileId,
      fallbackModifiedAt: conflict.incomingOccurredAt,
    );
    return Card(
      key: const Key('family-sharing-critical-conflict'),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    loc.syncConflictMedicationNoticeTitle(totalCount),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(loc.syncConflictMedicationWarning),
            const SizedBox(height: AppSpacing.sm),
            Text(
              loc.syncConflictMedicationComparison(
                _medicationBrief(loc, local),
                _medicationBrief(loc, incoming),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('family-sharing-review-critical-conflict'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FamilySyncConflictDetailPage(
                    conflictId: conflict.conflictId,
                  ),
                ),
              ),
              icon: const Icon(Icons.compare_arrows_outlined),
              label: Text(loc.syncConflictMedicationReviewAction),
            ),
          ],
        ),
      ),
    );
  }

  String _medicationBrief(
    AppLocalizations loc,
    MedicationConflictVersion version,
  ) {
    final values = [
      version.medicationName,
      version.dose,
    ].whereType<String>().where((value) => value.isNotEmpty).toList();
    return values.isEmpty ? loc.syncConflictValueUnknown : values.join(' · ');
  }
}

class _ResolutionCollisionNotice extends ConsumerWidget {
  const _ResolutionCollisionNotice({required this.notice});

  final FamilySyncResolutionNotice notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final importance = FamilySyncConflictPolicy.importanceOfVersions(
      entityType: notice.entityType,
      firstPayload: notice.firstPayload,
      secondPayload: notice.secondPayload,
    );
    final isCritical = importance == FamilySyncConflictImportance.critical;
    final first = isCritical
        ? FamilySyncConflictPolicy.medicationVersion(
            notice.firstPayload,
            fallbackAuthorProfileId: notice.firstSourceAuthorProfileId,
            fallbackDeviceProfileId: notice.firstSourceDeviceProfileId,
            fallbackModifiedAt: notice.firstOccurredAt,
          )
        : null;
    final second = isCritical
        ? FamilySyncConflictPolicy.medicationVersion(
            notice.secondPayload,
            fallbackAuthorProfileId: notice.secondSourceAuthorProfileId,
            fallbackDeviceProfileId: notice.secondSourceDeviceProfileId,
            fallbackModifiedAt: notice.secondOccurredAt,
          )
        : null;
    final winnerLabel = notice.winningChangeId == notice.firstChangeId
        ? loc.syncResolutionNoticeFirstVersion
        : loc.syncResolutionNoticeSecondVersion;
    return Card(
      key: const Key('family-sharing-resolution-notice'),
      color: isCritical
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCritical
                      ? Icons.medication_outlined
                      : Icons.merge_type_outlined,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    isCritical
                        ? loc.syncResolutionNoticeMedicationTitle
                        : loc.syncResolutionNoticeTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isCritical
                  ? loc.syncResolutionNoticeMedicationWarning
                  : loc.syncResolutionNoticeDescription,
            ),
            if (first != null && second != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                loc.syncConflictMedicationComparison(
                  _resolutionMedicationBrief(loc, first),
                  _resolutionMedicationBrief(loc, second),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(loc.syncResolutionNoticeWinner(winnerLabel)),
            ],
            if (notice.acknowledgedAuthorProfileIds.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                loc.syncResolutionNoticeAcknowledgedMembers(
                  notice.acknowledgedAuthorProfileIds.length,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              key: const Key('family-sharing-acknowledge-resolution-notice'),
              onPressed: () {
                ref
                    .read(familySyncRepositoryProvider)
                    .acknowledgeResolutionNotice(notice.noticeId);
                ref.read(familySyncStatusProvider.notifier).reload();
              },
              icon: const Icon(Icons.check_outlined),
              label: Text(loc.syncResolutionNoticeAcknowledge),
            ),
          ],
        ),
      ),
    );
  }
}

String _resolutionMedicationBrief(
  AppLocalizations loc,
  MedicationConflictVersion version,
) {
  final values = [
    version.medicationName,
    version.dose,
  ].whereType<String>().where((value) => value.isNotEmpty).toList();
  return values.isEmpty ? loc.syncConflictValueUnknown : values.join(' · ');
}

class _ConnectedFamilyCard extends StatelessWidget {
  const _ConnectedFamilyCard({required this.snapshot});

  final FamilySyncSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lastSuccessfulAt = snapshot.lastSuccessfulAt;
    final lastSuccessfulLabel = lastSuccessfulAt == null
        ? loc.familySharingNeverReceived
        : loc.familySharingLastReceived(
            MaterialLocalizations.of(context).formatFullDate(lastSuccessfulAt),
            TimeOfDay.fromDateTime(lastSuccessfulAt).format(context),
          );
    return Card(
      key: const Key('family-sharing-connected'),
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snapshot.familyDisplayName!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(loc.familySharingPending(snapshot.pendingChangeCount)),
            Text(loc.familySharingConflicts(snapshot.unresolvedConflictCount)),
            if (snapshot.unresolvedConflictCount > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('family-sharing-review-conflicts'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FamilySyncConflictsPage(),
                  ),
                ),
                icon: const Icon(Icons.compare_arrows_outlined),
                label: Text(loc.syncConflictsReviewAction),
              ),
            ],
            Text(lastSuccessfulLabel),
            if (snapshot.lastErrorCode != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                loc.familySharingOfflineNotice,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('family-sharing-manage-devices'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HomeServerDevicesPage(
                    familySpaceId: snapshot.familySpaceId!,
                  ),
                ),
              ),
              icon: const Icon(Icons.devices_other_outlined),
              label: Text(loc.homeServerManageDevicesAction),
            ),
            const SizedBox(height: AppSpacing.xs),
            _CreateFamilyInviteButton(snapshot: snapshot),
          ],
        ),
      ),
    );
  }
}

class _CreateFamilyInviteButton extends ConsumerStatefulWidget {
  const _CreateFamilyInviteButton({required this.snapshot});

  final FamilySyncSnapshot snapshot;

  @override
  ConsumerState<_CreateFamilyInviteButton> createState() =>
      _CreateFamilyInviteButtonState();
}

class _CreateFamilyInviteButtonState
    extends ConsumerState<_CreateFamilyInviteButton> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      key: const Key('family-sharing-create-invite'),
      onPressed: _creating ? null : _create,
      icon: _creating
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.qr_code_2_outlined),
      label: Text(loc.homeServerCreateInviteAction),
    );
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final invite = await ref
          .read(homeServerPairingServiceProvider)
          .createInvite(
            familySpaceId: widget.snapshot.familySpaceId!,
            familyDisplayName: widget.snapshot.familyDisplayName!,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HomeServerInvitePage(invite: invite),
        ),
      );
    } on FamilySyncUnavailable {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.homeServerPairingFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
    ),
  );
}
