import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/activity_entity.dart';
import '../../../models/diary_entity.dart';

enum EventCategoryId { basicCare, healthMedical, activityPlay, growthMemory }

enum EventTypeId {
  feeding,
  meal,
  water,
  snack,
  sleep,
  diaper,
  pumping,
  temperature,
  medication,
  symptom,
  hospital,
  vaccination,
  accidentInjury,
  tummyTime,
  bath,
  growthMeasurement,
  memo,
}

class EventCatalogItem {
  const EventCatalogItem({
    required this.id,
    required this.category,
    required this.icon,
    required this.aliases,
  });

  final EventTypeId id;
  final EventCategoryId category;
  final IconData icon;

  /// Previously stored localized event names remain recognizable after the
  /// app language changes.
  final Set<String> aliases;

  String label(AppLocalizations loc) => switch (id) {
    EventTypeId.feeding => loc.feedingEvent,
    EventTypeId.meal => loc.mealEvent,
    EventTypeId.water => loc.waterEvent,
    EventTypeId.snack => loc.snackEvent,
    EventTypeId.sleep => loc.sleepEvent,
    EventTypeId.diaper => loc.diaperEvent,
    EventTypeId.pumping => loc.pumpingEvent,
    EventTypeId.temperature => loc.temperatureEvent,
    EventTypeId.medication => loc.medicationEvent,
    EventTypeId.symptom => loc.symptomEvent,
    EventTypeId.hospital => loc.hospitalEvent,
    EventTypeId.vaccination => loc.vaccinationEvent,
    EventTypeId.accidentInjury => loc.accidentInjuryEvent,
    EventTypeId.tummyTime => loc.tummyTimeEvent,
    EventTypeId.bath => loc.bathEvent,
    EventTypeId.growthMeasurement => loc.growthMeasurementEvent,
    EventTypeId.memo => loc.memoEvent,
  };

  bool matches(String storedType) {
    final normalized = storedType.trim().toLowerCase();
    return aliases.any((alias) => alias.toLowerCase() == normalized);
  }
}

const eventCatalog = <EventCatalogItem>[
  EventCatalogItem(
    id: EventTypeId.feeding,
    category: EventCategoryId.basicCare,
    icon: Icons.baby_changing_station,
    aliases: {'수유', 'Feeding', '授乳'},
  ),
  EventCatalogItem(
    id: EventTypeId.meal,
    category: EventCategoryId.basicCare,
    icon: Icons.restaurant_outlined,
    aliases: {'이유식·식사', 'Meal', '離乳食・食事'},
  ),
  EventCatalogItem(
    id: EventTypeId.water,
    category: EventCategoryId.basicCare,
    icon: Icons.local_drink_outlined,
    aliases: {'물', 'Water', '水', '물·간식', 'Water · snack', '水分・おやつ'},
  ),
  EventCatalogItem(
    id: EventTypeId.snack,
    category: EventCategoryId.basicCare,
    icon: Icons.cookie_outlined,
    aliases: {'간식', 'Snack', 'おやつ'},
  ),
  EventCatalogItem(
    id: EventTypeId.sleep,
    category: EventCategoryId.basicCare,
    icon: Icons.bedtime_outlined,
    aliases: {'수면', 'Sleep', '睡眠'},
  ),
  EventCatalogItem(
    id: EventTypeId.diaper,
    category: EventCategoryId.basicCare,
    icon: Icons.child_friendly_outlined,
    aliases: {'기저귀·배변', '기저귀', 'Diaper · bowel', 'おむつ・排便'},
  ),
  EventCatalogItem(
    id: EventTypeId.pumping,
    category: EventCategoryId.basicCare,
    icon: Icons.water_drop_outlined,
    aliases: {'유축', 'Pumping', '搾乳'},
  ),
  EventCatalogItem(
    id: EventTypeId.temperature,
    category: EventCategoryId.healthMedical,
    icon: Icons.thermostat_outlined,
    aliases: {'체온', 'Temperature', '体温'},
  ),
  EventCatalogItem(
    id: EventTypeId.medication,
    category: EventCategoryId.healthMedical,
    icon: Icons.medication_outlined,
    aliases: {'투약', 'Medication', '投薬'},
  ),
  EventCatalogItem(
    id: EventTypeId.symptom,
    category: EventCategoryId.healthMedical,
    icon: Icons.monitor_heart_outlined,
    aliases: {'증상·컨디션', '증상', 'Symptom · condition', '症状・体調'},
  ),
  EventCatalogItem(
    id: EventTypeId.hospital,
    category: EventCategoryId.healthMedical,
    icon: Icons.local_hospital_outlined,
    aliases: {'병원·상담', 'Hospital · consultation', '通院・相談'},
  ),
  EventCatalogItem(
    id: EventTypeId.vaccination,
    category: EventCategoryId.healthMedical,
    icon: Icons.vaccines_outlined,
    aliases: {'예방접종', 'Vaccination', '予防接種'},
  ),
  EventCatalogItem(
    id: EventTypeId.accidentInjury,
    category: EventCategoryId.healthMedical,
    icon: Icons.healing_outlined,
    aliases: {'사고·다침', 'Accident · injury', '事故・けが'},
  ),
  EventCatalogItem(
    id: EventTypeId.tummyTime,
    category: EventCategoryId.activityPlay,
    icon: Icons.child_care_outlined,
    aliases: {'터미타임', 'Tummy time', 'タミータイム'},
  ),
  EventCatalogItem(
    id: EventTypeId.bath,
    category: EventCategoryId.activityPlay,
    icon: Icons.bathtub_outlined,
    aliases: {'목욕', 'Bath', '入浴'},
  ),
  EventCatalogItem(
    id: EventTypeId.growthMeasurement,
    category: EventCategoryId.growthMemory,
    icon: Icons.straighten_outlined,
    aliases: {'키·몸무게 측정', 'Growth measurement', '身長・体重測定'},
  ),
  EventCatalogItem(
    id: EventTypeId.memo,
    category: EventCategoryId.growthMemory,
    icon: Icons.notes_outlined,
    aliases: {'메모', 'Memo', 'メモ'},
  ),
];

const defaultQuickEventIds = <EventTypeId>[
  EventTypeId.feeding,
  EventTypeId.meal,
  EventTypeId.water,
  EventTypeId.snack,
  EventTypeId.sleep,
  EventTypeId.diaper,
  EventTypeId.temperature,
  EventTypeId.memo,
];

EventCatalogItem eventCatalogItem(EventTypeId id) =>
    eventCatalog.firstWhere((item) => item.id == id);

String eventCategoryLabel(EventCategoryId id, AppLocalizations loc) =>
    switch (id) {
      EventCategoryId.basicCare => loc.basicCareCategory,
      EventCategoryId.healthMedical => loc.healthMedicalCategory,
      EventCategoryId.activityPlay => loc.activityPlayCategory,
      EventCategoryId.growthMemory => loc.growthMemoryCategory,
    };

class RecentEventPreset {
  const RecentEventPreset({
    required this.item,
    required this.details,
    required this.occurredAt,
    this.structuredDataJson,
  });

  final EventCatalogItem item;
  final String details;
  final DateTime occurredAt;
  final String? structuredDataJson;

  String label(AppLocalizations loc) {
    final typeLabel = item.label(loc);
    final normalizedDetails = details.trim();
    return normalizedDetails.isEmpty
        ? typeLabel
        : '$typeLabel · $normalizedDetails';
  }
}

List<RecentEventPreset> buildRecentEventPresets(
  Iterable<DiaryEntity> diaries, {
  Set<EventTypeId> excludedIds = const {},
  int limit = 5,
}) {
  final activities = <ActivityEntity>[
    for (final diary in diaries) ...diary.activities,
  ]..sort((a, b) => b.time.compareTo(a.time));
  final seen = <EventTypeId>{};
  final result = <RecentEventPreset>[];

  for (final activity in activities) {
    EventCatalogItem? matched;
    for (final item in eventCatalog) {
      if (item.matches(activity.type)) {
        matched = item;
        break;
      }
    }
    if (matched == null ||
        excludedIds.contains(matched.id) ||
        !seen.add(matched.id)) {
      continue;
    }
    result.add(
      RecentEventPreset(
        item: matched,
        details: activity.details,
        occurredAt: activity.time,
        structuredDataJson: activity.structuredDataJson,
      ),
    );
    if (result.length == limit) break;
  }
  return result;
}
