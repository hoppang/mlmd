import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../transfer/canonical_transfer_document.dart';
import '../transfer/diary_transfer_service.dart';

class ImportPreviewDialog extends StatelessWidget {
  final PreparedDiaryImport prepared;
  final ImportPreview Function(ImportConflictPolicy policy) previewFor;

  const ImportPreviewDialog({
    super.key,
    required this.prepared,
    required this.previewFor,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final preview = previewFor(ImportConflictPolicy.skipExisting);
    final document = prepared.document;
    final dates = document.diaries.map((diary) => diary.date).toList()..sort();
    final materialLoc = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.importPreviewTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                prepared.sourceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                loc.backupInfo(
                  prepared.schemaVersion,
                  document.appVersion,
                  document.exportedAt.toLocal().toString(),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (dates.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  loc.importDateRange(
                    materialLoc.formatMediumDate(dates.first),
                    materialLoc.formatMediumDate(dates.last),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                loc.importCounts(preview.total, preview.activityCount),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CountChip(label: loc.newRecords, count: preview.newCount),
                  _CountChip(
                    label: loc.identicalRecords,
                    count: preview.identicalCount,
                  ),
                  _CountChip(
                    label: loc.conflictingRecords,
                    count: preview.conflictCount,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: Text(loc.safeImportNotice)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: preview.appliedCount == 0
              ? null
              : () => Navigator.pop(context, ImportConflictPolicy.skipExisting),
          child: Text(loc.importAction),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;

  const _CountChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Chip(label: Text('$label $count'));
}
