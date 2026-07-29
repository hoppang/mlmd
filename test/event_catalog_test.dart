import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/event_catalog.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/diary_entity.dart';

void main() {
  test('care procedure aliases keep concrete types in the health category', () {
    final item = eventCatalogItem(EventTypeId.careProcedure);

    expect(item.category, EventCategoryId.healthMedical);
    expect(item.matches('코 세척·흡인'), isTrue);
    expect(item.matches('Wound cleaning · dressing'), isTrue);
    expect(item.matches('処置・ケア · その他'), isTrue);
  });

  test('hidden tracking items are removed only from quick choices', () {
    final items = buildQuickEventItems(
      hiddenIds: {EventTypeId.feeding, EventTypeId.diaper},
    );

    expect(items.map((item) => item.id), isNot(contains(EventTypeId.feeding)));
    expect(items.map((item) => item.id), isNot(contains(EventTypeId.diaper)));
    expect(eventCatalogItem(EventTypeId.feeding), isNotNull);
  });

  test('recent presets keep latest type and exclude quick records', () {
    final diary = DiaryEntity(
      date: DateTime(2026, 7, 23),
      title: '',
      content: '',
      lastModified: DateTime(2026, 7, 23),
    );
    diary.activities.addAll([
      ActivityEntity(
        type: '이유식·식사',
        time: DateTime(2026, 7, 23, 9),
        details: '80g',
        lastModified: DateTime(2026, 7, 23, 9),
      ),
      ActivityEntity(
        type: 'Meal',
        time: DateTime(2026, 7, 23, 12),
        details: '120g',
        lastModified: DateTime(2026, 7, 23, 12),
      ),
      ActivityEntity(
        type: '수유',
        time: DateTime(2026, 7, 23, 13),
        details: '180mL',
        lastModified: DateTime(2026, 7, 23, 13),
      ),
      ActivityEntity(
        type: '투약',
        time: DateTime(2026, 7, 23, 11),
        details: '2.5mL',
        lastModified: DateTime(2026, 7, 23, 11),
      ),
    ]);

    final presets = buildRecentEventPresets([
      diary,
    ], excludedIds: defaultQuickEventIds.toSet());

    expect(presets.map((preset) => preset.item.id), [EventTypeId.medication]);
    expect(presets.first.details, '2.5mL');
  });
}
