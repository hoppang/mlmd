import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/intake_record.dart';
import 'package:mlmd/features/quick_launch/domain/quick_launch_models.dart';
import 'package:mlmd/features/quick_launch/presentation/quick_launch_labels.dart';
import 'package:mlmd/l10n/app_localizations.dart';

Future<AppLocalizations> _loadLoc() =>
    AppLocalizations.delegate.load(const Locale('ko'));

void main() {
  test('feeding targets require a choice or an amount form', () {
    expect(
      quickLaunchCanSaveInstantly(QuickLaunchEventTarget.feeding),
      isFalse,
    );
    expect(
      quickLaunchCanSaveInstantly(QuickLaunchEventTarget.formulaFeeding),
      isFalse,
    );
    expect(
      quickLaunchCanSaveInstantly(QuickLaunchEventTarget.breastFeeding),
      isFalse,
    );
    expect(
      quickLaunchCanSaveInstantly(QuickLaunchEventTarget.expressedMilkFeeding),
      isFalse,
    );
  });

  test('feeding variants render localized slot labels', () async {
    final loc = await _loadLoc();

    final formula = QuickLaunchSlot(
      slotIndex: 0,
      eventTypeId: QuickLaunchEventTarget.formulaFeeding,
      structuredPresetJson: IntakeRecord(
        kind: IntakeRecordKind.feeding,
        method: FeedingMethod.bottle,
        bottleContents: BottleContents.formula,
      ).encode(),
    );
    final breast = QuickLaunchSlot(
      slotIndex: 1,
      eventTypeId: QuickLaunchEventTarget.breastFeeding,
      structuredPresetJson: IntakeRecord(
        kind: IntakeRecordKind.feeding,
        method: FeedingMethod.breast,
        side: BreastSide.left,
      ).encode(),
    );
    final expressedMilk = QuickLaunchSlot(
      slotIndex: 2,
      eventTypeId: QuickLaunchEventTarget.expressedMilkFeeding,
      structuredPresetJson: IntakeRecord(
        kind: IntakeRecordKind.feeding,
        method: FeedingMethod.bottle,
        bottleContents: BottleContents.expressedMilk,
      ).encode(),
    );

    expect(quickLaunchSlotLabel(formula, loc), contains(loc.formulaOption));
    expect(
      quickLaunchSlotLabel(breast, loc),
      contains(loc.breastFeedingOption),
    );
    expect(
      quickLaunchSlotLabel(expressedMilk, loc),
      contains(loc.expressedMilkFeedingOption),
    );
  });
}
