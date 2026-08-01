import 'dart:convert';

import '../../../l10n/app_localizations.dart';
import '../../events/domain/event_catalog.dart';
import '../../events/domain/intake_record.dart';
import '../domain/quick_launch_models.dart';

EventCatalogItem quickLaunchCatalogItem(QuickLaunchEventTarget target) {
  final id = switch (target) {
    QuickLaunchEventTarget.formulaFeeding ||
    QuickLaunchEventTarget.breastFeeding ||
    QuickLaunchEventTarget.expressedMilkFeeding ||
    QuickLaunchEventTarget.feeding => EventTypeId.feeding,
    QuickLaunchEventTarget.pumping => EventTypeId.pumping,
    _ => EventTypeId.values.firstWhere((value) => value.name == target.name),
  };
  return eventCatalogItem(id);
}

QuickLaunchEventTarget quickLaunchTarget(EventTypeId id) =>
    QuickLaunchEventTarget.values.firstWhere((value) => value.name == id.name);

bool quickLaunchCanSaveInstantly(QuickLaunchEventTarget target) =>
    switch (target) {
      QuickLaunchEventTarget.sleep ||
      QuickLaunchEventTarget.diaper ||
      QuickLaunchEventTarget.bath => true,
      _ => false,
    };

bool quickLaunchOpensCategory(QuickLaunchEventTarget target) =>
    target == QuickLaunchEventTarget.feeding;

String quickLaunchSlotLabel(QuickLaunchSlot slot, AppLocalizations loc) {
  final target = slot.eventTypeId;
  if (target == null) return loc.quickLaunchAdd;
  if (target == QuickLaunchEventTarget.feeding ||
      target == QuickLaunchEventTarget.formulaFeeding ||
      target == QuickLaunchEventTarget.breastFeeding ||
      target == QuickLaunchEventTarget.expressedMilkFeeding) {
    final record = IntakeRecord.decode(slot.structuredPresetJson ?? '');
    if (record != null) return _feedingLabel(record, loc);
    if (target == QuickLaunchEventTarget.formulaFeeding) {
      return loc.formulaOption;
    }
    if (target == QuickLaunchEventTarget.breastFeeding) {
      return loc.breastFeedingOption;
    }
    if (target == QuickLaunchEventTarget.expressedMilkFeeding) {
      return loc.expressedMilkFeedingOption;
    }
  }
  if (target == QuickLaunchEventTarget.diaper) {
    final kind = _simplePresetValue(slot.structuredPresetJson, 'kind');
    if (kind == 'urine') return loc.eliminationUrinePreset;
    if (kind == 'stool') return loc.eliminationStoolPreset;
    if (kind == 'both') return loc.eliminationBothPreset;
  }
  final customLabel = slot.displayLabel?.trim();
  if (customLabel != null &&
      customLabel.isNotEmpty &&
      !_isGeneratedLabel(customLabel)) {
    return customLabel;
  }
  return quickLaunchCatalogItem(target).label(loc);
}

String _feedingLabel(IntakeRecord record, AppLocalizations loc) {
  final values = <String>[];
  switch (record.method) {
    case FeedingMethod.breast:
      values.add(loc.breastFeedingOption);
      if (record.side == BreastSide.left) values.add(loc.leftSideOption);
      if (record.side == BreastSide.right) values.add(loc.rightSideOption);
    case FeedingMethod.bottle:
      values.add(switch (record.bottleContents) {
        BottleContents.formula => loc.formulaOption,
        BottleContents.expressedMilk => loc.expressedMilkFeedingOption,
        BottleContents.other => loc.otherOption,
        null => loc.bottleFeedingOption,
      });
    case FeedingMethod.timeOnly || null:
      values.add(loc.feedingEvent);
  }
  final amount = record.amountExpression;
  if (amount?.kind == AmountExpressionKind.exact) {
    values.add('${_formatNumber(amount!.exactValue!)} ${amount.unit ?? 'mL'}');
  }
  return values.join(' ');
}

String? _simplePresetValue(String? source, String key) {
  if (source == null) return null;
  try {
    final decoded = jsonDecode(source);
    return decoded is Map ? decoded[key]?.toString() : null;
  } on FormatException {
    return null;
  }
}

bool _isGeneratedLabel(String value) => const {
  'feeding',
  'formulaFeeding',
  'breastFeeding',
  'expressedMilkFeeding',
  'sleep',
  'diaper',
  'diaperUrine',
  'diaperStool',
  'meal',
  'water',
  'snack',
  'tummyTime',
  'temperature',
}.contains(value);

String _formatNumber(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
