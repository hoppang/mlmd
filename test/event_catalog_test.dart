import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/events/domain/event_catalog.dart';
import 'package:mlmd/features/events/domain/intake_record.dart';
import 'package:mlmd/l10n/app_localizations_ko.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/diary_entity.dart';

void main() {
  test('default quick choices contain the planned five event types', () {
    expect(buildQuickEventItems().map((item) => item.id), [
      EventTypeId.feeding,
      EventTypeId.sleep,
      EventTypeId.diaper,
      EventTypeId.temperature,
      EventTypeId.memo,
    ]);
  });

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

  test('meal keeps legacy aliases while using the infant-focused name', () {
    final item = eventCatalogItem(EventTypeId.meal);

    expect(item.label(AppLocalizationsKo()), '이유식');
    expect(item.matches('이유식'), isTrue);
    expect(item.matches('이유식·식사'), isTrue);
    expect(item.matches('Meal'), isTrue);
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

    expect(presets.map((preset) => preset.item.id), [
      EventTypeId.meal,
      EventTypeId.medication,
    ]);
    expect(presets.first.details, '120g');
    expect(presets.map((preset) => preset.label(AppLocalizationsKo())), [
      '이유식',
      '투약',
    ]);
  });

  test('recent meal shows a compact label and keeps editable defaults', () {
    final previousMeal = const IntakeRecord(
      kind: IntakeRecordKind.meal,
      mealType: MealType.dinner,
      amountExpression: AmountExpression.qualitative(QualitativeLevel.normal),
      reaction: IntakeReaction.ateWell,
    );
    final diary = DiaryEntity(
      date: DateTime(2026, 8, 10),
      title: '',
      content: '',
      lastModified: DateTime(2026, 8, 10),
    );
    diary.activities.add(
      ActivityEntity(
        type: '이유식·식사',
        time: DateTime(2026, 8, 10, 18),
        details: '저녁 · 보통 · 잘 먹음',
        structuredDataJson: previousMeal.encode(),
        lastModified: DateTime(2026, 8, 10, 18),
      ),
    );

    final preset = buildRecentEventPresets([diary]).single;
    final restored = IntakeRecord.decode(preset.structuredDataJson!);

    expect(preset.label(AppLocalizationsKo()), '이유식');
    expect(restored?.mealType, MealType.dinner);
    expect(
      restored?.amountExpression?.qualitativeLevel,
      QualitativeLevel.normal,
    );
    expect(restored?.reaction, IntakeReaction.ateWell);
  });
}
