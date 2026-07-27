import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/tasks/domain/care_task_model.dart';
import 'package:mlmd/features/tasks/presentation/care_task_card.dart';
import 'package:mlmd/l10n/app_localizations.dart';
import 'package:mlmd/repositories/profile_repository.dart';

import '../support/test_profile_repository.dart';

void main() {
  testWidgets('CareTaskCard displays title, status badge, action buttons, and triggers callbacks', (
    tester,
  ) async {
    final profiles = TestProfileRepository();
    final now = DateTime.now();

    final task = CareTask(
      taskId: 'task-1',
      title: '오후 6:30 해열제 먹이기',
      linkedCategory: 'medication',
      createdAt: now,
      createdByAuthorProfileId: 'author-1',
      createdByDeviceProfileId: 'dev-1',
    );

    final occurrence = CareTaskOccurrence(
      occurrenceId: 'occ-1',
      taskId: 'task-1',
      scheduledAt: now.subtract(const Duration(minutes: 10)), // due
    );

    bool completedTapped = false;
    bool skippedTapped = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CareTaskCard(
              task: task,
              occurrence: occurrence,
              onComplete: () {
                completedTapped = true;
              },
              onSkip: () {
                skippedTapped = true;
              },
              onUndo: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('오후 6:30 해열제 먹이기'), findsOneWidget);
    expect(find.text('먹였어요'), findsOneWidget); // linkedCategory medication -> verb '먹였어요'
    expect(find.text('건너뛰기'), findsOneWidget);

    await tester.tap(find.text('먹였어요'));
    await tester.pump();
    expect(completedTapped, isTrue);

    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    expect(skippedTapped, isTrue);
  });
}
