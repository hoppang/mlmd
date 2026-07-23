import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../l10n/app_localizations.dart';

class StartupErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;
  final VoidCallback onResetData;

  const StartupErrorScreen({
    super.key,
    required this.error,
    this.stackTrace,
    required this.onRetry,
    required this.onResetData,
  });

  Future<void> _confirmReset(BuildContext context, AppLocalizations loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.startupResetData),
        content: Text(loc.startupResetConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onResetData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a standalone MaterialApp because this is shown before MyApp is loaded.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
      home: Builder(
        builder: (context) {
          final loc = AppLocalizations.of(context)!;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: AppInsets.dialog,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        loc.startupErrorTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppRadii.control),
                        ),
                        child: Text(
                          error.toString(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontFamily: 'monospace'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      ElevatedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: Text(loc.startupRetry),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(
                            double.infinity,
                            AppSizes.minimumInteractiveDimension,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: () => _confirmReset(context, loc),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: Text(loc.startupResetData),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
