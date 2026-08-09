import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/sharing/domain/family_sync_conflict_policy.dart';
import 'package:mlmd/features/sharing/domain/family_sync_models.dart';

FamilySyncConflict _conflict({
  required String entityType,
  required Map<String, Object?> local,
  required Map<String, Object?> incoming,
}) => FamilySyncConflict(
  conflictId: 'conflict-1',
  familySpaceId: 'family-1',
  entityType: entityType,
  entityId: 'entity-1',
  localRevision: 1,
  incomingRevision: 2,
  localPayload: local,
  incomingPayload: incoming,
  incomingChangeId: 'change-1',
  incomingOperation: SyncOperation.update,
  detectedAt: DateTime.utc(2026, 8, 3),
);

void main() {
  test('structured medication conflicts are always critical', () {
    final conflict = _conflict(
      entityType: 'activity',
      local: {
        'type': 'custom label',
        'structuredDataJson':
            '{"schema":"mlmd.medication","medicationName":"해열제","amount":5,"unit":"mL","administeredAt":"2026-08-03T12:00:00Z"}',
      },
      incoming: const {'type': 'memo'},
    );

    expect(
      FamilySyncConflictPolicy.importanceOf(conflict),
      FamilySyncConflictImportance.critical,
    );
    final version = FamilySyncConflictPolicy.medicationVersion(
      conflict.localPayload,
    );
    expect(version.medicationName, '해열제');
    expect(version.dose, '5 mL');
    expect(version.administeredAt, DateTime.utc(2026, 8, 3, 12));
  });

  test('temperature, feeding, and scheduled occurrences are caution', () {
    for (final conflict in [
      _conflict(
        entityType: 'activity',
        local: const {'type': '체온'},
        incoming: const {'type': '체온'},
      ),
      _conflict(
        entityType: 'activity',
        local: const {'type': 'Feeding'},
        incoming: const {'type': 'Feeding'},
      ),
      _conflict(
        entityType: 'careTaskOccurrence',
        local: const {},
        incoming: const {},
      ),
    ]) {
      expect(
        FamilySyncConflictPolicy.importanceOf(conflict),
        FamilySyncConflictImportance.caution,
      );
    }
  });

  test('ordinary memo conflicts remain routine', () {
    final conflict = _conflict(
      entityType: 'activity',
      local: const {'type': '메모', 'details': '왼쪽'},
      incoming: const {'type': '메모', 'details': '오른쪽'},
    );

    expect(
      FamilySyncConflictPolicy.importanceOf(conflict),
      FamilySyncConflictImportance.routine,
    );
  });
}
