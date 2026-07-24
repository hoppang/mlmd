import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_entity.dart';
import '../data/objectbox_helper.dart';
import '../objectbox.g.dart';
import 'profile_repository.dart';
import 'package:uuid/uuid.dart';

/// 활동 로그 CRUD 처리를 위한 Repository 인터페이스
abstract class ActivityRepository {
  /// 모든 활동 목록을 반환합니다.
  List<ActivityEntity> getActivities();

  /// 특정 일기에 포함된 활동 목록을 반환합니다.
  List<ActivityEntity> getActivitiesByDiary(int diaryId);

  /// 지정한 ID에 해당하는 활동을 조회합니다.
  ActivityEntity? getActivity(int id);

  /// 특정 일기에 활동을 저장(생성 또는 수정)합니다.
  /// 저장 시 활동의 `lastModified`와 연관된 일기(Diary)의 `lastModified`가 모두 자동으로 현재 시간으로 갱신됩니다.
  int saveActivity(ActivityEntity activity, int diaryId);

  /// 지정한 ID의 활동을 삭제합니다.
  /// 삭제 시 연관되었던 일기(Diary)의 `lastModified`가 자동으로 현재 시간으로 갱신됩니다.
  bool deleteActivity(int id);
}

/// ActivityRepository의 ObjectBox 구현체
class ActivityRepositoryImpl implements ActivityRepository {
  static const _uuid = Uuid();
  final ObjectBoxHelper _obxHelper;
  final ProfileRepository _profileRepository;

  ActivityRepositoryImpl(this._obxHelper, this._profileRepository);

  @override
  List<ActivityEntity> getActivities() {
    return _obxHelper.activityBox.getAll();
  }

  @override
  List<ActivityEntity> getActivitiesByDiary(int diaryId) {
    final query = _obxHelper.activityBox
        .query(ActivityEntity_.diary.equals(diaryId))
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  @override
  ActivityEntity? getActivity(int id) {
    return _obxHelper.activityBox.get(id);
  }

  @override
  int saveActivity(ActivityEntity activity, int diaryId) {
    final diary = _obxHelper.diaryBox.get(diaryId);
    if (diary == null) {
      throw Exception(
        "상위 DiaryEntity(ID: $diaryId)를 찾을 수 없어 Activity를 저장할 수 없습니다.",
      );
    }

    // 1. 관계 매핑
    activity.diary.target = diary;

    // 2. 트리거: 활동 및 부모 일기의 lastModified 타임스탬프 갱신
    final now = DateTime.now();
    final source = _profileRepository.requireCurrentSource();
    final previous = activity.id == 0
        ? null
        : _obxHelper.activityBox.get(activity.id);
    activity
      ..recordId = activity.recordId ?? previous?.recordId ?? _uuid.v4()
      ..revision = previous == null
          ? (activity.revision < 1 ? 1 : activity.revision)
          : (_sameCore(activity, previous)
                ? previous.revision
                : previous.revision + 1)
      ..createdAt = activity.createdAt ?? previous?.createdAt ?? now
      ..createdByAuthorProfileId =
          activity.createdByAuthorProfileId ??
          previous?.createdByAuthorProfileId ??
          source.authorProfileId
      ..createdByDeviceProfileId =
          activity.createdByDeviceProfileId ??
          previous?.createdByDeviceProfileId ??
          source.deviceProfileId
      ..lastModifiedByAuthorProfileId = source.authorProfileId
      ..lastModifiedByDeviceProfileId = source.deviceProfileId
      ..lastModified = now;
    diary
      ..createdAt = diary.createdAt ?? diary.lastModified
      ..createdByAuthorProfileId =
          diary.createdByAuthorProfileId ?? source.authorProfileId
      ..createdByDeviceProfileId =
          diary.createdByDeviceProfileId ?? source.deviceProfileId
      ..lastModifiedByAuthorProfileId = source.authorProfileId
      ..lastModifiedByDeviceProfileId = source.deviceProfileId
      ..lastModified = now;

    // 3. ObjectBox 저장 수행
    final activityId = _obxHelper.activityBox.put(activity);
    _obxHelper.diaryBox.put(diary);

    return activityId;
  }

  bool _sameCore(ActivityEntity left, ActivityEntity right) =>
      left.type == right.type &&
      left.time.isAtSameMomentAs(right.time) &&
      left.timePrecision == right.timePrecision &&
      left.details == right.details &&
      left.customEventTypeId == right.customEventTypeId &&
      left.customEventNameSnapshot == right.customEventNameSnapshot;

  @override
  bool deleteActivity(int id) {
    final activity = _obxHelper.activityBox.get(id);
    if (activity != null) {
      final diary = activity.diary.target;
      if (diary != null) {
        // 트리거: 활동 삭제 시 부모 일기의 lastModified 갱신
        final source = _profileRepository.requireCurrentSource();
        diary
          ..lastModified = DateTime.now()
          ..lastModifiedByAuthorProfileId = source.authorProfileId
          ..lastModifiedByDeviceProfileId = source.deviceProfileId;
        _obxHelper.diaryBox.put(diary);
      }
      return _obxHelper.activityBox.remove(id);
    }
    return false;
  }
}

/// Riverpod에서 제공할 ActivityRepository 프로바이더
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final obxHelper = ref.watch(objectBoxProvider);
  final profiles = ref.watch(profileRepositoryProvider);
  return ActivityRepositoryImpl(obxHelper, profiles);
}, dependencies: [objectBoxProvider, profileRepositoryProvider]);
