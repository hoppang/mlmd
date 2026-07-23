import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/author_profile_entity.dart';
import '../../../repositories/profile_repository.dart';

const authorProfileColors = <Color>[
  Color(0xFF00796B),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFFC62828),
  Color(0xFFEF6C00),
  Color(0xFF2E7D32),
  Color(0xFF5D4037),
  Color(0xFF455A64),
];

class AuthorProfileGate extends ConsumerWidget {
  const AuthorProfileGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(authorProfileListProvider);
    if (profiles.isEmpty) {
      return const AuthorProfileEditorPage(isInitialSetup: true);
    }
    return child;
  }
}

class AuthorProfilesPage extends ConsumerWidget {
  const AuthorProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final profiles = ref.watch(authorProfileListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.authorProfilesTitle)),
      body: AdaptiveContentFrame(
        child: ListView(
          padding: AppInsets.page,
          children: [
            Text(
              loc.authorProfileLocalNotice,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final profile in profiles)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: ListTile(
                  key: Key('author-profile-${profile.authorProfileId}'),
                  leading: AuthorAvatar(profile: profile),
                  title: Text(profile.nickname),
                  subtitle: profile.isCurrent ? Text(loc.authorCurrent) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (profile.isCurrent)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      IconButton(
                        tooltip: loc.authorEdit,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AuthorProfileEditorPage(profile: profile),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  onTap: profile.isCurrent
                      ? null
                      : () => ref
                            .read(authorProfileListProvider.notifier)
                            .select(profile.authorProfileId),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-author-profile'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AuthorProfileEditorPage(),
          ),
        ),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(loc.authorAdd),
      ),
    );
  }
}

class AuthorProfileEditorPage extends ConsumerStatefulWidget {
  const AuthorProfileEditorPage({
    super.key,
    this.profile,
    this.isInitialSetup = false,
  });

  final AuthorProfileEntity? profile;
  final bool isInitialSetup;

  @override
  ConsumerState<AuthorProfileEditorPage> createState() =>
      _AuthorProfileEditorPageState();
}

class _AuthorProfileEditorPageState
    extends ConsumerState<AuthorProfileEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.profile?.nickname ?? '',
    );
    _color = widget.profile == null
        ? authorProfileColors.first
        : Color(widget.profile!.colorValue);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final title = widget.profile == null
        ? loc.authorSetupTitle
        : loc.authorEdit;
    return PopScope(
      canPop: !widget.isInitialSetup,
      child: Scaffold(
        appBar: widget.isInitialSetup ? null : AppBar(title: Text(title)),
        body: SafeArea(
          child: AdaptiveContentFrame(
            child: ListView(
              padding: AppInsets.page,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Icon(
                  Icons.badge_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  loc.authorSetupDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xl),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    key: const Key('author-nickname-field'),
                    controller: _nicknameController,
                    autofocus: widget.isInitialSetup,
                    maxLength: 30,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: loc.authorNicknameLabel,
                      hintText: loc.authorNicknameHint,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      final length = value?.trim().length ?? 0;
                      return length < 1 || length > 30
                          ? loc.authorNicknameError
                          : null;
                    },
                    onFieldSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  loc.authorColorLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final entry in authorProfileColors.indexed)
                      _ColorChoice(
                        label: '${loc.authorColorLabel} ${entry.$1 + 1}',
                        color: entry.$2,
                        selected: entry.$2.toARGB32() == _color.toARGB32(),
                        onTap: () => setState(() => _color = entry.$2),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  key: const Key('save-author-profile'),
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(
                    widget.profile == null ? loc.authorSave : loc.saveRecord,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authorProfileListProvider.notifier);
    final profile = widget.profile;
    if (profile == null) {
      notifier.create(
        nickname: _nicknameController.text,
        colorValue: _color.toARGB32(),
      );
    } else {
      notifier.update(
        authorProfileId: profile.authorProfileId,
        nickname: _nicknameController.text,
        colorValue: _color.toARGB32(),
      );
    }
    if (!widget.isInitialSetup && mounted) Navigator.pop(context);
  }
}

class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({super.key, required this.profile, this.radius = 20});

  final AuthorProfileEntity profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = Color(profile.colorValue);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundColor:
          ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : Colors.black,
      child: Text(
        profile.nickname.characters.first.toUpperCase(),
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    selected: selected,
    button: true,
    child: InkResponse(
      onTap: onTap,
      radius: 28,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                color:
                    ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : null,
      ),
    ),
  );
}
