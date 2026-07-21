import 'package:flutter/material.dart';

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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.draftsInProgress(count),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onStartNew,
                  child: Text(loc.startNewDraft),
                ),
                const SizedBox(width: 8),
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
