import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';

import '../data/objectbox_helper.dart';
import '../features/duplicate_review/domain/duplicate_detector.dart';
import '../models/activity_entity.dart';
import '../models/diary_entity.dart';
import '../models/duplicate_review_edge_entity.dart';
import '../models/logical_event_group_entity.dart';
import 'profile_repository.dart';

class DuplicateReviewItem {
  const DuplicateReviewItem({
    required this.edge,
    required this.firstDiary,
    required this.firstActivity,
    required this.secondDiary,
    required this.secondActivity,
  });

  final DuplicateReviewEdgeEntity edge;
  final DiaryEntity firstDiary;
  final ActivityEntity firstActivity;
  final DiaryEntity secondDiary;
  final ActivityEntity secondActivity;
}

abstract interface class DuplicateReviewRepository {
  List<DuplicateReviewItem> synchronize(
    List<DiaryEntity> diaries, {
    bool includeResolved = false,
  });

  void useRepresentative(String pairKey, String representativeRecordId);
  void markDistinct(String pairKey);
  void defer(String pairKey);
  void resetDecision(String pairKey);
}

class DuplicateReviewRepositoryImpl implements DuplicateReviewRepository {
  DuplicateReviewRepositoryImpl(this._objectBox, this._profiles);

  final ObjectBoxHelper _objectBox;
  final ProfileRepository _profiles;

  @override
  List<DuplicateReviewItem> synchronize(
    List<DiaryEntity> diaries, {
    bool includeResolved = false,
  }) {
    final sources = <String, ({DiaryEntity diary, ActivityEntity activity})>{};
    for (final diary in diaries) {
      for (final activity in diary.activities) {
        final recordId = activity.recordId;
        if (recordId != null) {
          sources[recordId] = (diary: diary, activity: activity);
        }
      }
    }

    final detected = {
      for (final candidate in detectDuplicateCandidates(diaries))
        candidate.pairKey: candidate,
    };

    _objectBox.store.runInTransaction(TxMode.write, () {
      final existing = {
        for (final edge in _objectBox.duplicateReviewEdgeBox.getAll())
          edge.pairKey: edge,
      };

      for (final edge in existing.values) {
        final first = sources[edge.recordAId]?.activity;
        final second = sources[edge.recordBId]?.activity;
        if (first == null || second == null) {
          _removeGroup(edge.logicalGroupId);
          _objectBox.duplicateReviewEdgeBox.remove(edge.id);
          continue;
        }
        if (edge.revisionA != first.revision ||
            edge.revisionB != second.revision) {
          _removeGroup(edge.logicalGroupId);
          edge
            ..status = DuplicateReviewEdgeEntity.statusPending
            ..revisionA = first.revision
            ..revisionB = second.revision
            ..signatureA = _activitySignature(first)
            ..signatureB = _activitySignature(second)
            ..representativeRecordId = null
            ..logicalGroupId = null
            ..deferredAt = null
            ..resolvedByAuthorProfileId = null
            ..resolvedByDeviceProfileId = null
            ..resolvedAt = null;
          _objectBox.duplicateReviewEdgeBox.put(edge);
        }
      }

      for (final entry in detected.entries) {
        if (existing.containsKey(entry.key)) continue;
        final candidate = entry.value;
        _objectBox.duplicateReviewEdgeBox.put(
          DuplicateReviewEdgeEntity(
            pairKey: candidate.pairKey,
            recordAId: candidate.firstActivity.recordId!,
            recordBId: candidate.secondActivity.recordId!,
            signatureA: _activitySignature(candidate.firstActivity),
            signatureB: _activitySignature(candidate.secondActivity),
            revisionA: candidate.firstActivity.revision,
            revisionB: candidate.secondActivity.revision,
            detectionReasonsJson: jsonEncode(
              candidate.reasons.map((reason) => reason.name).toList()..sort(),
            ),
            detectedAt: DateTime.now(),
            detectorVersion: candidate.detectorVersion,
          ),
        );
      }
    });

    final items = <DuplicateReviewItem>[];
    for (final edge in _objectBox.duplicateReviewEdgeBox.getAll()) {
      if (!includeResolved &&
          edge.status != DuplicateReviewEdgeEntity.statusPending) {
        continue;
      }
      final first = sources[edge.recordAId];
      final second = sources[edge.recordBId];
      if (first == null || second == null) continue;
      items.add(
        DuplicateReviewItem(
          edge: edge,
          firstDiary: first.diary,
          firstActivity: first.activity,
          secondDiary: second.diary,
          secondActivity: second.activity,
        ),
      );
    }
    items.sort((left, right) {
      final byTime = right.firstActivity.time.compareTo(
        left.firstActivity.time,
      );
      return byTime != 0
          ? byTime
          : left.edge.pairKey.compareTo(right.edge.pairKey);
    });
    return List.unmodifiable(items);
  }

  @override
  void useRepresentative(String pairKey, String representativeRecordId) {
    final edge = _requireEdge(pairKey);
    if (representativeRecordId != edge.recordAId &&
        representativeRecordId != edge.recordBId) {
      throw ArgumentError.value(
        representativeRecordId,
        'representativeRecordId',
        'must be a member of the duplicate pair',
      );
    }
    final source = _profiles.requireCurrentSource();
    final now = DateTime.now();
    final groupId = 'group:$pairKey';
    _objectBox.store.runInTransaction(TxMode.write, () {
      final existingGroup = _group(groupId);
      final group = LogicalEventGroupEntity(
        id: existingGroup?.id ?? 0,
        groupId: groupId,
        memberRecordIdsJson: jsonEncode([edge.recordAId, edge.recordBId]),
        representativeRecordId: representativeRecordId,
        memberRevisionsJson: jsonEncode({
          edge.recordAId: edge.revisionA,
          edge.recordBId: edge.revisionB,
        }),
        resolvedByAuthorProfileId: source.authorProfileId,
        resolvedByDeviceProfileId: source.deviceProfileId,
        resolvedAt: now,
      );
      _objectBox.logicalEventGroupBox.put(group);
      edge
        ..status = DuplicateReviewEdgeEntity.statusSameEvent
        ..representativeRecordId = representativeRecordId
        ..logicalGroupId = groupId
        ..deferredAt = null
        ..resolvedByAuthorProfileId = source.authorProfileId
        ..resolvedByDeviceProfileId = source.deviceProfileId
        ..resolvedAt = now;
      _objectBox.duplicateReviewEdgeBox.put(edge);
    });
  }

  @override
  void markDistinct(String pairKey) {
    final edge = _requireEdge(pairKey);
    final source = _profiles.requireCurrentSource();
    _objectBox.store.runInTransaction(TxMode.write, () {
      _removeGroup(edge.logicalGroupId);
      edge
        ..status = DuplicateReviewEdgeEntity.statusDistinctEvents
        ..representativeRecordId = null
        ..logicalGroupId = null
        ..deferredAt = null
        ..resolvedByAuthorProfileId = source.authorProfileId
        ..resolvedByDeviceProfileId = source.deviceProfileId
        ..resolvedAt = DateTime.now();
      _objectBox.duplicateReviewEdgeBox.put(edge);
    });
  }

  @override
  void defer(String pairKey) {
    final edge = _requireEdge(pairKey)
      ..status = DuplicateReviewEdgeEntity.statusPending
      ..deferredAt = DateTime.now();
    _objectBox.duplicateReviewEdgeBox.put(edge);
  }

  @override
  void resetDecision(String pairKey) {
    final edge = _requireEdge(pairKey);
    _objectBox.store.runInTransaction(TxMode.write, () {
      _removeGroup(edge.logicalGroupId);
      edge
        ..status = DuplicateReviewEdgeEntity.statusPending
        ..representativeRecordId = null
        ..logicalGroupId = null
        ..deferredAt = null
        ..resolvedByAuthorProfileId = null
        ..resolvedByDeviceProfileId = null
        ..resolvedAt = null;
      _objectBox.duplicateReviewEdgeBox.put(edge);
    });
  }

  DuplicateReviewEdgeEntity _requireEdge(String pairKey) {
    for (final edge in _objectBox.duplicateReviewEdgeBox.getAll()) {
      if (edge.pairKey == pairKey) return edge;
    }
    throw StateError('Duplicate review edge does not exist.');
  }

  LogicalEventGroupEntity? _group(String groupId) {
    for (final group in _objectBox.logicalEventGroupBox.getAll()) {
      if (group.groupId == groupId) return group;
    }
    return null;
  }

  void _removeGroup(String? groupId) {
    if (groupId == null) return;
    final group = _group(groupId);
    if (group != null) _objectBox.logicalEventGroupBox.remove(group.id);
  }

  String _activitySignature(ActivityEntity activity) => jsonEncode({
    'type': activity.type.trim().toLowerCase(),
    'time': activity.time.toIso8601String(),
    'timePrecision': activity.timePrecision,
    'details': normalizeDuplicateDetails(activity.details),
  });
}

final duplicateReviewRepositoryProvider = Provider<DuplicateReviewRepository>(
  (ref) => DuplicateReviewRepositoryImpl(
    ref.watch(objectBoxProvider),
    ref.watch(profileRepositoryProvider),
  ),
  dependencies: [objectBoxProvider, profileRepositoryProvider],
);
