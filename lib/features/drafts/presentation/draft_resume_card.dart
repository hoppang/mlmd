import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';

class DraftResumeCard extends StatelessWidget {
  const DraftResumeCard({
    super.key,
    required this.count,
    required this.description,
    required this.onContinue,
    required this.onStartNew,
  });

  final int count;
  final String description;
  final VoidCallback onContinue;
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.draftsInProgress(count),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onStartNew,
                  child: Text(loc.startNewDraft),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  onPressed: onContinue,
                  child: Text(loc.continueWriting),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
