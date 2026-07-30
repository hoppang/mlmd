import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/child_profile_repository.dart';
import '../domain/child_profile.dart';

class ChildProfilesPage extends ConsumerWidget {
  const ChildProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final children = ref.watch(childProfileListProvider);
    final selectedId = ref.watch(selectedChildIdProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.childProfilesTitle)),
      body: AdaptiveContentFrame(
        child: ListView(
          padding: AppInsets.page,
          children: [
            Text(loc.childProfilesDescription),
            const SizedBox(height: AppSpacing.md),
            for (final child in children)
              Card(
                child: ListTile(
                  key: Key('child-profile-${child.childId}'),
                  leading: CircleAvatar(
                    child: Icon(
                      child.childId == selectedId
                          ? Icons.check
                          : Icons.child_care,
                    ),
                  ),
                  title: Text(child.name),
                  subtitle: Text(
                    child.birthDate == null
                        ? loc.childBirthDateUnknown
                        : MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(child.birthDate!),
                  ),
                  trailing: IconButton(
                    onPressed: () => _showEditor(context, ref, child),
                    tooltip: loc.editChildProfile,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  onTap: () => ref
                      .read(selectedChildIdProvider.notifier)
                      .select(child.childId),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('add-child-profile'),
              onPressed: () => _showEditor(context, ref, null),
              icon: const Icon(Icons.add),
              label: Text(loc.addChildProfile),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref,
    ChildProfile? child,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: child?.name ?? '');
    var birthDate = child?.birthDate;
    var clearBirthDate = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              child == null ? loc.addChildProfile : loc.editChildProfile,
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('child-name-field'),
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(labelText: loc.childNameLabel),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final chosen = await showDatePicker(
                        context: dialogContext,
                        initialDate: birthDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (chosen != null) {
                        setDialogState(() {
                          birthDate = chosen;
                          clearBirthDate = false;
                        });
                      }
                    },
                    icon: const Icon(Icons.cake_outlined),
                    label: Text(
                      birthDate == null
                          ? loc.childBirthDateLabel
                          : MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(birthDate!),
                    ),
                  ),
                  if (birthDate != null)
                    TextButton(
                      onPressed: () => setDialogState(() {
                        birthDate = null;
                        clearBirthDate = true;
                      }),
                      child: Text(loc.childBirthDateUnknown),
                    ),
                ],
              ),
            ),
            actions: [
              if (child != null)
                TextButton(
                  onPressed: () {
                    final deleted = ref
                        .read(childProfileListProvider.notifier)
                        .delete(child.childId);
                    if (!deleted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.lastChildCannotDelete)),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: Text(loc.deleteChildProfile),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(loc.cancel),
              ),
              FilledButton(
                key: const Key('save-child-profile'),
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  if (child == null) {
                    ref
                        .read(childProfileListProvider.notifier)
                        .create(name: name, birthDate: birthDate);
                  } else {
                    ref
                        .read(childProfileListProvider.notifier)
                        .update(
                          childId: child.childId,
                          name: name,
                          birthDate: birthDate,
                          clearBirthDate: clearBirthDate,
                        );
                  }
                  Navigator.pop(dialogContext);
                },
                child: Text(loc.saveRecord),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}
