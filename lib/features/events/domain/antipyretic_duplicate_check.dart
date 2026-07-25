import '../../../models/activity_entity.dart';
import 'medication_record.dart';

enum AntipyreticDuplicateRelation {
  sameIngredient,
  differentIngredient,
  unknownIngredient,
}

class AntipyreticDuplicateCandidate {
  const AntipyreticDuplicateCandidate({
    required this.newRecord,
    required this.existingRecord,
    required this.existingActivity,
    required this.relation,
  });

  final MedicationRecord newRecord;
  final MedicationRecord existingRecord;
  final ActivityEntity existingActivity;
  final AntipyreticDuplicateRelation relation;
}

AntipyreticDuplicateCandidate? findAntipyreticDuplicateCandidate({
  required MedicationRecord newRecord,
  required String? newRecordId,
  required Iterable<ActivityEntity> existingActivities,
  Duration timeWindow = const Duration(hours: 6),
}) {
  if (!newRecord.isAntipyretic) return null;

  AntipyreticDuplicateCandidate? closestCandidate;
  Duration? shortestDiff;

  for (final activity in existingActivities) {
    if (activity.recordId != null && activity.recordId == newRecordId) {
      continue;
    }

    final jsonStr = activity.structuredDataJson;
    if (jsonStr == null || jsonStr.trim().isEmpty) continue;

    final record = MedicationRecord.decode(jsonStr);
    if (record == null || !record.isAntipyretic) continue;

    final diff =
        newRecord.administeredAt.difference(record.administeredAt).abs();
    if (diff > timeWindow) continue;

    if (shortestDiff == null || diff < shortestDiff) {
      shortestDiff = diff;

      final AntipyreticDuplicateRelation relation;
      if (newRecord.ingredient == null ||
          newRecord.ingredient == AntipyreticIngredient.unknown ||
          record.ingredient == null ||
          record.ingredient == AntipyreticIngredient.unknown) {
        relation = AntipyreticDuplicateRelation.unknownIngredient;
      } else if (newRecord.ingredient == record.ingredient) {
        relation = AntipyreticDuplicateRelation.sameIngredient;
      } else {
        relation = AntipyreticDuplicateRelation.differentIngredient;
      }

      closestCandidate = AntipyreticDuplicateCandidate(
        newRecord: newRecord,
        existingRecord: record,
        existingActivity: activity,
        relation: relation,
      );
    }
  }

  return closestCandidate;
}
