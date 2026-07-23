import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/event_catalog.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/diary_entity.dart';

void main() {
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

    expect(presets.map((preset) => preset.item.id), [
      EventTypeId.meal,
      EventTypeId.medication,
    ]);
    expect(presets.first.details, '120g');
  });
}
