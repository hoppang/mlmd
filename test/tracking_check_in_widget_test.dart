import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/application/custom_event_notifier.dart';
import 'package:mlmd/features/events/domain/event_catalog.dart';
import 'package:mlmd/features/events/presentation/record_entry_sheet.dart';
import 'package:mlmd/features/tracking/domain/tracking_models.dart';
import 'package:mlmd/l10n/app_localizations.dart';

class _EmptyCustomCatalogNotifier extends CustomEventCatalogNotifier {
  @override
  CustomEventCatalogState build() => const CustomEventCatalogState();
}

void main() {
  testWidgets('daily mode saves one relative check-in instead of a detail form', (
    tester,
  ) async {
    TrackingRelativeState? savedState;
    String? savedMemo;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customEventCatalogProvider.overrideWith(
            _EmptyCustomCatalogNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecordEntrySheet(
              recentPresets: const [],
              trackingModes: const {
                EventTypeId.feeding: TrackingMode.dailyCheckIn,
              },
              onSave: (_, _, _, _) async => 'unexpected',
              onUpdate: (_, _, _) async {},
              onDelete: (_) async {},
              onSaveCustom: (_, _, _, _) async {},
              onStartSleep: (_, _) async => true,
              onOpenDetailedRecord: () {},
              onSaveDailyCheckIn: (eventType, relativeState, memo) async {
                expect(eventType, EventTypeId.feeding);
                savedState = relativeState;
                savedMemo = memo;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('quick-record-feeding')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-tracking-check-in')), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.enterText(
      find.byKey(const Key('daily-tracking-memo')),
      'Ate well',
    );
    await tester.tap(
      find.byKey(const Key('save-daily-tracking-check-in')),
    );
    await tester.pumpAndSettle();

    expect(savedState, TrackingRelativeState.more);
    expect(savedMemo, 'Ate well');
  });
}
