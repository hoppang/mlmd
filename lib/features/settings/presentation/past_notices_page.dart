import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../repositories/stt_notice_repository.dart';
import 'stt_notice_dialog.dart';

class PastNoticesPage extends ConsumerWidget {
  const PastNoticesPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (_) => const PastNoticesPage(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final repo = ref.watch(sttNoticeRepositoryProvider);
    final state = repo.state;

    final acceptedDateStr = state.acceptedAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(state.acceptedAt!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pastNoticesTitle),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.privacy_tip_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              l10n.pastNoticeSttTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              state.isAccepted && acceptedDateStr != null
                  ? l10n.pastNoticeStatusAccepted(acceptedDateStr)
                  : l10n.pastNoticeStatusNotAccepted,
              style: TextStyle(
                color: state.isAccepted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
            trailing: OutlinedButton(
              onPressed: () {
                SttNoticeDialog.show(context);
              },
              child: Text(l10n.recheckNoticeAction),
            ),
            onTap: () {
              SttNoticeDialog.show(context);
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
