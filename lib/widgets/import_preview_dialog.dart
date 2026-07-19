import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../transfer/canonical_transfer_document.dart';
import '../transfer/diary_transfer_service.dart';

class ImportPreviewDialog extends StatefulWidget {
  final PreparedDiaryImport prepared;
  final ImportPreview Function(ImportConflictPolicy policy) previewFor;

  const ImportPreviewDialog({
    super.key,
    required this.prepared,
    required this.previewFor,
  });

  @override
  State<ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<ImportPreviewDialog> {
  ImportConflictPolicy _policy = ImportConflictPolicy.skipExisting;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final preview = widget.previewFor(_policy);
    final document = widget.prepared.document;
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
                widget.prepared.sourceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                loc.backupInfo(
                  widget.prepared.schemaVersion,
                  document.appVersion,
                  document.exportedAt.toLocal().toString(),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                    label: loc.duplicateRecords,
                    count: preview.duplicateCount,
                  ),
                  _CountChip(
                    label: loc.newerRecords,
                    count: preview.newerCount,
                  ),
                  _CountChip(
                    label: loc.skippedRecords,
                    count: preview.skippedCount,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                loc.conflictPolicy,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              RadioGroup<ImportConflictPolicy>(
                groupValue: _policy,
                onChanged: (value) {
                  if (value != null) setState(() => _policy = value);
                },
                child: Column(
                  children: [
                    RadioListTile<ImportConflictPolicy>(
                      contentPadding: EdgeInsets.zero,
                      value: ImportConflictPolicy.skipExisting,
                      title: Text(loc.skipExisting),
                    ),
                    RadioListTile<ImportConflictPolicy>(
                      contentPadding: EdgeInsets.zero,
                      value: ImportConflictPolicy.overwriteIfNewer,
                      title: Text(loc.overwriteIfNewer),
                    ),
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
              : () => Navigator.pop(context, _policy),
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
