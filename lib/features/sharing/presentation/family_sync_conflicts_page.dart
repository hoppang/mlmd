import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../repositories/family_sync_repository.dart';
import '../application/family_sync_coordinator.dart';
import '../domain/family_sync_conflict_policy.dart';
import '../domain/family_sync_models.dart';

class FamilySyncConflictsPage extends ConsumerWidget {
  const FamilySyncConflictsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final conflicts = ref.watch(familySyncConflictsProvider);
    final unresolved = conflicts.where((item) => !item.isResolved).toList();
    final resolved = conflicts.where((item) => item.isResolved).toList();

    return Scaffold(
      appBar: AppBar(title: Text(loc.syncConflictsTitle)),
      body: AdaptiveContentFrame(
        child: conflicts.isEmpty
            ? Center(
                child: Padding(
                  padding: AppInsets.page,
                  child: Text(loc.syncConflictEmpty),
                ),
              )
            : ListView(
                padding: AppInsets.page,
                children: [
                  for (final conflict in unresolved)
                    _ConflictTile(conflict: conflict),
                  if (resolved.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      loc.syncConflictHistoryTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final conflict in resolved)
                      _ConflictTile(conflict: conflict),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ConflictTile extends StatelessWidget {
  const _ConflictTile({required this.conflict});

  final FamilySyncConflict conflict;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final importance = FamilySyncConflictPolicy.importanceOf(conflict);
    return Card(
      child: ListTile(
        key: Key('sync-conflict-${conflict.conflictId}'),
        leading: Icon(
          conflict.isResolved
              ? Icons.check_circle_outline
              : importance == FamilySyncConflictImportance.critical
              ? Icons.medication_outlined
              : importance == FamilySyncConflictImportance.caution
              ? Icons.warning_amber_outlined
              : Icons.compare_arrows_outlined,
          color:
              !conflict.isResolved &&
                  importance == FamilySyncConflictImportance.critical
              ? Theme.of(context).colorScheme.error
              : null,
        ),
        title: Text(
          importance == FamilySyncConflictImportance.critical
              ? loc.syncConflictMedicationTitle
              : _humanize(conflict.entityType),
        ),
        subtitle: Text(
          conflict.isResolved
              ? _resolutionLabel(loc, conflict.resolution)
              : loc.syncConflictUnresolved,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                FamilySyncConflictDetailPage(conflictId: conflict.conflictId),
          ),
        ),
      ),
    );
  }
}

class FamilySyncConflictDetailPage extends ConsumerWidget {
  const FamilySyncConflictDetailPage({required this.conflictId, super.key});

  final String conflictId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final conflicts = ref.watch(familySyncConflictsProvider);
    final conflict = conflicts
        .where((item) => item.conflictId == conflictId)
        .firstOrNull;
    if (conflict == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.syncConflictsTitle)),
        body: Center(child: Text(loc.syncConflictEmpty)),
      );
    }
    final importance = FamilySyncConflictPolicy.importanceOf(conflict);

    return Scaffold(
      appBar: AppBar(title: Text(_humanize(conflict.entityType))),
      body: AdaptiveContentFrame(
        child: ListView(
          padding: AppInsets.page,
          children: [
            if (conflict.isResolved)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(_resolutionLabel(loc, conflict.resolution)),
                  subtitle: conflict.resolvedAt == null
                      ? null
                      : Text(_formatMoment(context, conflict.resolvedAt!)),
                ),
              )
            else if (importance == FamilySyncConflictImportance.critical)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.medication_outlined),
                  title: Text(loc.syncConflictMedicationTitle),
                  subtitle: Text(loc.syncConflictMedicationWarning),
                ),
              )
            else
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(loc.syncConflictUnresolved),
                  subtitle: Text(loc.syncConflictResolutionWarning),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (importance == FamilySyncConflictImportance.critical) ...[
              _MedicationVersionCard(
                key: const Key('sync-conflict-medication-local'),
                title: loc.syncConflictLocalVersion,
                version: FamilySyncConflictPolicy.medicationVersion(
                  conflict.localPayload,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _MedicationVersionCard(
                key: const Key('sync-conflict-medication-incoming'),
                title: loc.syncConflictIncomingVersion,
                version: FamilySyncConflictPolicy.medicationVersion(
                  conflict.incomingPayload,
                  fallbackAuthorProfileId:
                      conflict.incomingSourceAuthorProfileId,
                  fallbackDeviceProfileId:
                      conflict.incomingSourceDeviceProfileId,
                  fallbackModifiedAt: conflict.incomingOccurredAt,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final local = _VersionCard(
                  key: const Key('sync-conflict-local-version'),
                  title: loc.syncConflictLocalVersion,
                  revision: conflict.localRevision,
                  payload: conflict.localPayload,
                );
                final incoming = _VersionCard(
                  key: const Key('sync-conflict-incoming-version'),
                  title: loc.syncConflictIncomingVersion,
                  revision: conflict.incomingRevision,
                  payload: conflict.incomingPayload,
                );
                if (constraints.maxWidth >= 720) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: local),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: incoming),
                    ],
                  );
                }
                return Column(
                  children: [
                    local,
                    const SizedBox(height: AppSpacing.md),
                    incoming,
                  ],
                );
              },
            ),
            if (!conflict.isResolved) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                key: const Key('sync-conflict-keep-local'),
                onPressed: () => _confirm(
                  context,
                  ref,
                  conflict,
                  SyncConflictResolution.keepLocal,
                ),
                child: Text(loc.syncConflictKeepLocal),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: const Key('sync-conflict-use-incoming'),
                onPressed: () => _confirm(
                  context,
                  ref,
                  conflict,
                  SyncConflictResolution.useIncoming,
                ),
                child: Text(loc.syncConflictUseIncoming),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    FamilySyncConflict conflict,
    SyncConflictResolution resolution,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.syncConflictConfirmTitle),
        content: Text(loc.syncConflictResolutionWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.syncConflictConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(familySyncConflictControllerProvider)
          .resolve(conflictId: conflict.conflictId, resolution: resolution);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.syncConflictResolveFailed)));
    }
  }
}

class _MedicationVersionCard extends StatelessWidget {
  const _MedicationVersionCard({
    super.key,
    required this.title,
    required this.version,
  });

  final String title;
  final MedicationConflictVersion version;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              label: loc.syncConflictMedicationName,
              value: version.medicationName ?? loc.syncConflictValueUnknown,
            ),
            _DetailRow(
              label: loc.syncConflictMedicationDose,
              value: version.dose ?? loc.syncConflictValueUnknown,
            ),
            _DetailRow(
              label: loc.syncConflictMedicationTime,
              value: version.administeredAt == null
                  ? loc.syncConflictValueUnknown
                  : _formatMoment(context, version.administeredAt!.toLocal()),
            ),
            _DetailRow(
              label: loc.syncConflictMedicationAuthor,
              value: version.authorProfileId ?? loc.syncConflictValueUnknown,
            ),
            _DetailRow(
              label: loc.syncConflictMedicationDevice,
              value: version.deviceProfileId ?? loc.syncConflictValueUnknown,
            ),
            _DetailRow(
              label: loc.syncConflictMedicationModifiedAt,
              value: version.modifiedAt == null
                  ? loc.syncConflictValueUnknown
                  : _formatMoment(context, version.modifiedAt!.toLocal()),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    super.key,
    required this.title,
    required this.revision,
    required this.payload,
  });

  final String title;
  final int revision;
  final Map<String, Object?> payload;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final entries = payload.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(loc.syncConflictRevision(revision)),
            const Divider(),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _humanize(entry.key),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    SelectableText(_formatValue(entry.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _resolutionLabel(
  AppLocalizations loc,
  SyncConflictResolution? resolution,
) => switch (resolution) {
  SyncConflictResolution.keepLocal => loc.syncConflictResolvedKeepLocal,
  SyncConflictResolution.useIncoming => loc.syncConflictResolvedUseIncoming,
  null => loc.syncConflictResolved,
};

String _humanize(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    )
    .replaceAll('_', ' ');

String _formatValue(Object? value) {
  if (value == null) return '—';
  if (value is List) return value.map(_formatValue).join(', ');
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key}: ${_formatValue(entry.value)}')
        .join(', ');
  }
  return value.toString();
}

String _formatMoment(BuildContext context, DateTime moment) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatFullDate(moment)} '
      '${TimeOfDay.fromDateTime(moment).format(context)}';
}
