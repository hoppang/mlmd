import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/locale_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.onExport,
    required this.onImport,
    required this.backupOverview,
  });

  final Future<void> Function() onExport;
  final Future<void> Function() onImport;
  final BackupOverview Function() backupOverview;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(loc.settingsIntro, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          _SettingsTile(
            icon: Icons.child_care_outlined,
            title: loc.childInformation,
            subtitle: loc.childInformationDescription,
            onTap: () => _showUnavailable(context, loc.childInformation),
          ),
          _SettingsTile(
            icon: Icons.badge_outlined,
            title: loc.authorProfile,
            subtitle: loc.authorProfileDescription,
            onTap: () => _showUnavailable(context, loc.authorProfile),
          ),
          _SettingsTile(
            icon: Icons.family_restroom_outlined,
            title: loc.familySharing,
            subtitle: loc.familySharingDescription,
            onTap: () => _showUnavailable(context, loc.familySharing),
          ),
          _SettingsTile(
            icon: Icons.inventory_2_outlined,
            title: loc.dataBackupTitle,
            subtitle: loc.dataBackupDescription,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DataBackupPage(
                  onExport: onExport,
                  onImport: onImport,
                  backupOverview: backupOverview,
                ),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: loc.helpTitle,
            subtitle: loc.helpDescription,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const HelpPage())),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnavailable(BuildContext context, String feature) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.notAvailableYetTitle),
          content: Text(
            AppLocalizations.of(context)!.notAvailableYetDescription(feature),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.close),
            ),
          ],
        ),
      );
}

class BackupOverview {
  const BackupOverview({
    required this.diaryCount,
    required this.activityCount,
    required this.estimatedBackupBytes,
  });

  final int diaryCount;
  final int activityCount;
  final int estimatedBackupBytes;
}

class DataBackupPage extends StatefulWidget {
  const DataBackupPage({
    super.key,
    required this.onExport,
    required this.onImport,
    required this.backupOverview,
  });

  final Future<void> Function() onExport;
  final Future<void> Function() onImport;
  final BackupOverview Function() backupOverview;

  @override
  State<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends State<DataBackupPage> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final overview = widget.backupOverview();
    return Scaffold(
      appBar: AppBar(title: Text(loc.dataBackupTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage_outlined, color: colors.primary),
                      const SizedBox(width: 10),
                      Text(
                        loc.storageSummaryTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.backupContentsSummary(
                      overview.diaryCount,
                      overview.activityCount,
                      _formatBytes(overview.estimatedBackupBytes),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.backupPrivacyNotice,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.upload_file_outlined,
            title: loc.createBackupFile,
            description: loc.createBackupDescription,
            buttonLabel: loc.createBackupFile,
            filled: true,
            onPressed: widget.onExport,
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.download_for_offline_outlined,
            title: loc.importBackupFile,
            description: loc.importBackupDescription,
            buttonLabel: loc.importBackupFile,
            filled: false,
            onPressed: _importAndRefresh,
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.restore_from_trash_outlined),
            title: Text(loc.recentlyDeleted),
            subtitle: Text(loc.recentlyDeletedDescription),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kibibytes = bytes / 1024;
    if (kibibytes < 1024) return '${kibibytes.toStringAsFixed(1)} KB';
    return '${(kibibytes / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _importAndRefresh() async {
    await widget.onImport();
    if (mounted) setState(() {});
  }
}

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final currentMode = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.helpTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(loc.helpIntro, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          _HelpCard(
            question: loc.offlineHelpQuestion,
            answer: loc.offlineHelpAnswer,
          ),
          _HelpCard(
            question: loc.duplicateHelpQuestion,
            answer: loc.duplicateHelpAnswer,
          ),
          const SizedBox(height: 20),
          Text(
            loc.languageSetting,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<AppLocaleMode>(
            initialValue: currentMode,
            decoration: const InputDecoration(border: OutlineInputBorder()),
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
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool filled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 14),
          if (filled)
            FilledButton(onPressed: onPressed, child: Text(buttonLabel))
          else
            OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    ),
  );
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      title: Text(question),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [Text(answer)],
    ),
  );
}
