import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/activity_entity.dart';
import '../domain/medical_guidance.dart';

typedef ExternalGuidanceLauncher = Future<bool> Function(Uri uri);

class MedicalAttentionLabel extends StatelessWidget {
  const MedicalAttentionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: AppLocalizations.of(context)!.medicalAttentionRequired,
      child: Container(
        key: const Key('medical-attention-label'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Text(
          AppLocalizations.of(context)!.medicalAttentionRequired,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class MedicalGuidanceSection extends StatelessWidget {
  const MedicalGuidanceSection({
    required this.activity,
    this.launchExternal,
    super.key,
  });

  final ActivityEntity activity;
  final ExternalGuidanceLauncher? launchExternal;

  Future<void> _open(BuildContext context, GuidanceLinkRule rule) async {
    final uri = Uri.tryParse(rule.sourceUrl);
    if (uri == null || !isApprovedGuidanceUri(uri)) {
      _showFailure(context);
      return;
    }
    try {
      final opened =
          await (launchExternal?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && context.mounted) _showFailure(context);
    } catch (_) {
      if (context.mounted) _showFailure(context);
    }
  }

  void _showFailure(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.officialGuidanceOpenFailed,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final evaluation = evaluateMedicalGuidance(activity);
    if (evaluation.links.isEmpty) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context)!;
    return Column(
      key: const Key('medical-guidance-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          loc.relatedOfficialGuidance,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (evaluation.reason case final reason?) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            loc.officialGuidanceMatchReason(reason),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        for (final rule in evaluation.links)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: AppInsets.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.sourceOrganization,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    rule.sourceTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: Key('open-guidance-${rule.ruleId}'),
                      onPressed: () => _open(context, rule),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(loc.openInSystemBrowser),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          loc.officialGuidanceDisclaimer,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
