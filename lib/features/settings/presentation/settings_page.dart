import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/locale_provider.dart';
import '../../../repositories/profile_repository.dart';
import '../../profiles/presentation/author_profile_page.dart';

class SettingsPage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final profiles = ref.watch(authorProfileListProvider);
    final currentProfiles = profiles
        .where((profile) => profile.isCurrent)
        .toList(growable: false);
    final currentAuthor = currentProfiles.isEmpty
        ? null
        : currentProfiles.first;
    return Scaffold(
      appBar: AppBar(title: Text(loc.settingsTitle)),
      body: AdaptiveContentFrame(
        child: ListView(
          padding: AppInsets.page,
          children: [
            Text(
              loc.settingsIntro,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsTile(
              icon: Icons.child_care_outlined,
              title: loc.childInformation,
              subtitle: loc.childInformationDescription,
              onTap: () => _showUnavailable(context, loc.childInformation),
            ),
            _SettingsTile(
              icon: Icons.badge_outlined,
              title: loc.authorProfile,
              subtitle: currentAuthor == null
                  ? loc.authorProfileDescription
                  : '${currentAuthor.nickname} · ${loc.authorProfileDescription}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AuthorProfilesPage(),
                ),
              ),
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
      body: AdaptiveContentFrame(
        child: ListView(
          padding: AppInsets.page,
          children: [
            Card(
              child: Padding(
                padding: AppInsets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage_outlined, color: colors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          loc.storageSummaryTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      loc.backupContentsSummary(
                        overview.diaryCount,
                        overview.activityCount,
                        _formatBytes(overview.estimatedBackupBytes),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      loc.backupPrivacyNotice,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionCard(
              icon: Icons.upload_file_outlined,
              title: loc.createBackupFile,
              description: loc.createBackupDescription,
              buttonLabel: loc.createBackupFile,
              filled: true,
              onPressed: widget.onExport,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionCard(
              icon: Icons.download_for_offline_outlined,
              title: loc.importBackupFile,
              description: loc.importBackupDescription,
              buttonLabel: loc.importBackupFile,
              filled: false,
              onPressed: _importAndRefresh,
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
              ),
              leading: const Icon(Icons.restore_from_trash_outlined),
              title: Text(loc.recentlyDeleted),
              subtitle: Text(loc.recentlyDeletedDescription),
            ),
          ],
        ),
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
      body: AdaptiveContentFrame(
        child: ListView(
          padding: AppInsets.page,
          children: [
            Text(loc.helpIntro, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            _HelpCard(
              question: loc.offlineHelpQuestion,
              answer: loc.offlineHelpAnswer,
            ),
            _HelpCard(
              question: loc.duplicateHelpQuestion,
              answer: loc.duplicateHelpAnswer,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              loc.languageSetting,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
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
    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
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
      padding: AppInsets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(description),
          const SizedBox(height: AppSpacing.sm),
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
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: ExpansionTile(
      title: Text(question),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: [Text(answer)],
    ),
  );
}
