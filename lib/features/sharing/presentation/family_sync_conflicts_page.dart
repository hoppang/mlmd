import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../repositories/family_sync_repository.dart';
import '../application/family_sync_coordinator.dart';
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
    return Card(
      child: ListTile(
        key: Key('sync-conflict-${conflict.conflictId}'),
        leading: Icon(
          conflict.isResolved
              ? Icons.check_circle_outline
              : Icons.compare_arrows_outlined,
        ),
        title: Text(_humanize(conflict.entityType)),
        subtitle: Text(
          conflict.isResolved
              ? _resolutionLabel(loc, conflict.resolution)
              : loc.syncConflictUnresolved,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                _ConflictDetailPage(conflictId: conflict.conflictId),
          ),
        ),
      ),
    );
  }
}

class _ConflictDetailPage extends ConsumerWidget {
  const _ConflictDetailPage({required this.conflictId});

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
