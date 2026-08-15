import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/children/application/child_profile_repository.dart';
import 'package:mlmd/features/sharing/application/family_sync_payloads.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads legacy JSON with sync metadata defaults', () async {
    SharedPreferences.setMockInitialValues({
      'child_profiles_json':
          '[{"childId":"legacy","name":"Legacy","createdAt":"2026-01-01T00:00:00.000Z"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = ChildProfileRepository(prefs);

    final legacy = repository.children.singleWhere(
      (item) => item.childId == 'legacy',
    );
    expect(legacy.revision, 1);
    expect(legacy.updatedAt, legacy.createdAt);
    expect(legacy.familySpaceId, isNull);
    expect(legacy.deletedAt, isNull);
    repository.dispose();
  });

  test(
    'keeps tombstones and remote applies do not emit local mutations',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ChildProfileRepository(prefs);
      final mutations = <ChildProfileMutation>[];
      final subscription = repository.mutations.listen(mutations.add);

      repository.create(
        name: 'Child',
        childId: 'child-sync',
        birthDate: DateTime(2026, 1, 2),
      );
      final associated = repository.associateWithFamily(
        'child-sync',
        'family-1',
      );
      expect(associated.familySpaceId, 'family-1');
      expect(
        FamilySyncPayloads.forChildProfile(associated)['birthDate'] as String,
        startsWith('2026-01-02'),
      );
      expect(repository.delete('child-sync'), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(mutations.map((item) => item.kind), [
        ChildProfileMutationKind.create,
        ChildProfileMutationKind.delete,
      ]);
      expect(
        repository.children.map((item) => item.childId),
        isNot(contains('child-sync')),
      );
      final tombstone = repository.allChildren.singleWhere(
        (item) => item.childId == 'child-sync',
      );
      expect(tombstone.deletedAt, isNotNull);

      repository.applyRemote(
        tombstone.copyWith(
          name: 'Remote child',
          revision: tombstone.revision + 1,
          updatedAt: tombstone.updatedAt.add(const Duration(seconds: 1)),
          clearDeletedAt: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(mutations, hasLength(2));
      expect(
        repository.children
            .singleWhere((item) => item.childId == 'child-sync')
            .name,
        'Remote child',
      );

      await subscription.cancel();
      repository.dispose();
    },
  );
}
