import '../../../features/events/domain/event_catalog.dart';
import '../../../models/activity_entity.dart';
import '../../../models/diary_entity.dart';

const duplicateDetectorVersion = 'exact-duplicate-v2';

enum DuplicateReason { sameType, exactTime, exactDetails, differentDevices }

class DuplicateCoreSignature {
  const DuplicateCoreSignature({
    required this.eventTypeId,
    required this.customEventName,
    required this.occurredAt,
    required this.timePrecision,
    required this.normalizedDetails,
  });

  final EventTypeId? eventTypeId;
  final String? customEventName;
  final DateTime occurredAt;
  final int timePrecision;
  final String normalizedDetails;
}

class DuplicateCandidate {
  const DuplicateCandidate({
    required this.pairKey,
    required this.firstDiary,
    required this.firstActivity,
    required this.firstCoreSignature,
    required this.secondDiary,
    required this.secondActivity,
    required this.secondCoreSignature,
    required this.reasons,
    required this.detectorVersion,
  });

  final String pairKey;
  final DiaryEntity firstDiary;
  final ActivityEntity firstActivity;
  final DuplicateCoreSignature firstCoreSignature;
  final DiaryEntity secondDiary;
  final ActivityEntity secondActivity;
  final DuplicateCoreSignature secondCoreSignature;
  final Set<DuplicateReason> reasons;
  final String detectorVersion;
}

/// Finds only conservative, byte-stable duplicate candidates.
///
/// This detector deliberately does not assign a user-facing score. It also
/// excludes temperature readings because repeated measurements must be
/// preserved even when their values and timestamps happen to match.
List<DuplicateCandidate> detectDuplicateCandidates(
  Iterable<DiaryEntity> diaries,
) {
  final eligible = <_EligibleActivity>[];

  for (final diary in diaries) {
    for (final activity in diary.activities) {
      final recordId = activity.recordId?.trim();
      final deviceId = activity.createdByDeviceProfileId?.trim();
      if (recordId == null ||
          recordId.isEmpty ||
          deviceId == null ||
          deviceId.isEmpty ||
          !activity.hasExactTime) {
        continue;
      }

      final eventTypeId = _canonicalEventType(activity.type);
      final customEventName =
          eventTypeId == null && activity.customEventTypeId != null
          ? normalizeDuplicateDetails(
              activity.customEventNameSnapshot ?? activity.type,
            )
          : null;
      if ((eventTypeId == null &&
              (customEventName == null || customEventName.isEmpty)) ||
          eventTypeId == EventTypeId.temperature) {
        continue;
      }

      eligible.add(
        _EligibleActivity(
          diary: diary,
          activity: activity,
          recordId: recordId,
          deviceId: deviceId,
          coreSignature: DuplicateCoreSignature(
            eventTypeId: eventTypeId,
            customEventName: customEventName,
            occurredAt: activity.time,
            timePrecision: activity.timePrecision,
            normalizedDetails: normalizeDuplicateDetails(activity.details),
          ),
        ),
      );
    }
  }

  eligible.sort((a, b) => a.recordId.compareTo(b.recordId));
  final candidatesByPairKey = <String, DuplicateCandidate>{};

  for (var firstIndex = 0; firstIndex < eligible.length; firstIndex++) {
    final first = eligible[firstIndex];
    for (
      var secondIndex = firstIndex + 1;
      secondIndex < eligible.length;
      secondIndex++
    ) {
      final second = eligible[secondIndex];
      if (first.recordId == second.recordId ||
          first.deviceId == second.deviceId ||
          !_sameCoreSignature(first.coreSignature, second.coreSignature)) {
        continue;
      }

      final pairKey = '${first.recordId}|${second.recordId}';
      candidatesByPairKey.putIfAbsent(
        pairKey,
        () => DuplicateCandidate(
          pairKey: pairKey,
          firstDiary: first.diary,
          firstActivity: first.activity,
          firstCoreSignature: first.coreSignature,
          secondDiary: second.diary,
          secondActivity: second.activity,
          secondCoreSignature: second.coreSignature,
          reasons: const {
            DuplicateReason.sameType,
            DuplicateReason.exactTime,
            DuplicateReason.exactDetails,
            DuplicateReason.differentDevices,
          },
          detectorVersion: duplicateDetectorVersion,
        ),
      );
    }
  }

  final result = candidatesByPairKey.values.toList()
    ..sort((a, b) => a.pairKey.compareTo(b.pairKey));
  return result;
}

String normalizeDuplicateDetails(String details) =>
    details.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

EventTypeId? _canonicalEventType(String storedType) {
  for (final item in eventCatalog) {
    if (item.matches(storedType)) return item.id;
  }
  return null;
}

bool _sameCoreSignature(
  DuplicateCoreSignature first,
  DuplicateCoreSignature second,
) =>
    first.eventTypeId == second.eventTypeId &&
    first.customEventName == second.customEventName &&
    first.occurredAt.isAtSameMomentAs(second.occurredAt) &&
    first.timePrecision == second.timePrecision &&
    first.normalizedDetails == second.normalizedDetails;

class _EligibleActivity {
  const _EligibleActivity({
    required this.diary,
    required this.activity,
    required this.recordId,
    required this.deviceId,
    required this.coreSignature,
  });

  final DiaryEntity diary;
  final ActivityEntity activity;
  final String recordId;
  final String deviceId;
  final DuplicateCoreSignature coreSignature;
}
