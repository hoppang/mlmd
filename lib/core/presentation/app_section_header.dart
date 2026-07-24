import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class SliverAppSectionHeader extends StatelessWidget {
  const SliverAppSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) =>
      SliverToBoxAdapter(child: AppSectionHeader(title: title));
}
