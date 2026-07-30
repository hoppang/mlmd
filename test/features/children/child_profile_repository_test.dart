import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mlmd/features/children/application/child_profile_repository.dart';
import 'package:mlmd/features/children/domain/child_profile.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('creates a default local child profile when storage is empty', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ChildProfileRepository(prefs);

    expect(repository.children, hasLength(1));
    expect(repository.children.single.childId, ChildProfile.localChildId);
    expect(repository.selectedChildId, ChildProfile.localChildId);
  });

  test(
    'creates, selects, updates, and deletes child profiles safely',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ChildProfileRepository(prefs);

      final created = repository.create(
        name: '아기',
        birthDate: DateTime(2026, 1, 1),
        childId: 'child-a',
      );
      expect(repository.selectedChildId, 'child-a');
      expect(created.birthDate, DateTime(2026, 1, 1));

      repository.select(ChildProfile.localChildId);
      expect(repository.selectedChildId, ChildProfile.localChildId);

      final updated = repository.update(
        childId: 'child-a',
        name: '아기2',
        birthDate: DateTime(2026, 2, 1),
      );
      expect(updated.name, '아기2');
      expect(
        repository.children
            .singleWhere((item) => item.childId == 'child-a')
            .name,
        '아기2',
      );

      expect(repository.delete('child-a'), isTrue);
      expect(repository.children, hasLength(1));
      expect(repository.selectedChildId, ChildProfile.localChildId);
      expect(repository.delete(ChildProfile.localChildId), isFalse);
    },
  );

  test('persists and restores selected child id and profile list', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = ChildProfileRepository(prefs);
    first.create(
      name: '둘째',
      childId: 'child-b',
      birthDate: DateTime(2026, 3, 3),
    );

    final restored = ChildProfileRepository(prefs);
    expect(restored.children, hasLength(2));
    expect(restored.selectedChildId, 'child-b');
    expect(restored.selectedChild.name, '둘째');
  });
}
