import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/family_sync_models.dart';
import '../../../repositories/family_sync_repository.dart';
import 'family_sync_conflicts_page.dart';

class FamilySharingPage extends ConsumerWidget {
  const FamilySharingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final snapshot = ref.watch(familySyncStatusProvider);
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
            if (snapshot.isConnected)
              _ConnectedFamilyCard(snapshot: snapshot)
            else
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
          ],
        ),
      ),
    );
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
