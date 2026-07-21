import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/locale_provider.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({
    super.key,
    required this.onExport,
    required this.onImport,
  });

  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(localeProvider);
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(
        loc.settingsTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.languageSetting,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AppLocaleMode>(
            initialValue: currentMode,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            items: [
              DropdownMenuItem(
                value: AppLocaleMode.system,
                child: Text(loc.languageSystem),
              ),
              DropdownMenuItem(
                value: AppLocaleMode.korean,
                child: Text(loc.languageKorean),
              ),
              DropdownMenuItem(
                value: AppLocaleMode.english,
                child: Text(loc.languageEnglish),
              ),
              DropdownMenuItem(
                value: AppLocaleMode.japanese,
                child: Text(loc.languageJapanese),
              ),
            ],
            onChanged: (mode) {
              if (mode != null) {
                ref.read(localeProvider.notifier).setLocale(mode);
              }
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            loc.dataManagement,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loc.dataManagementDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.upload_file),
                  label: Text(loc.exportDiary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: Text(loc.importDiary),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.close, style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
