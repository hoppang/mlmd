import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/tasks/domain/care_task_model.dart';
import '../repositories/profile_repository.dart';

class TaskNotificationPolicy {
  const TaskNotificationPolicy({
    required this.shouldShowInApp,
    required this.shouldNotifyQuietly,
    required this.allowVibration,
    required this.allowSound,
  });

  final bool shouldShowInApp;
  final bool shouldNotifyQuietly;
  final bool allowVibration;
  final bool allowSound;
}

class TaskNotificationService {
  TaskNotificationService(this._profileRepository);

  final ProfileRepository _profileRepository;

  TaskNotificationPolicy evaluateNotificationPolicy({
    required CareTask task,
    required CareTaskOccurrence occurrence,
    required DateTime now,
    bool enableSound = false,
    bool enableVibration = true,
  }) {
    final status = occurrence.computedStatusAt(now);

    if (task.notificationMode == TaskNotificationMode.inAppOnly) {
      return TaskNotificationPolicy(
        shouldShowInApp: true,
        shouldNotifyQuietly: false,
        allowVibration: false,
        allowSound: false,
      );
    }

    // quietToAssignee mode
    final currentAuthor = _profileRepository.currentAuthor;
    final currentAuthorId = currentAuthor?.authorProfileId;

    // Check if current user is the assignee or if assigned to anyone
    final isAssignee =
        task.isAssignedToAnyone ||
        (currentAuthorId != null &&
            task.assignedToAuthorProfileId == currentAuthorId);

    if (!isAssignee) {
      return const TaskNotificationPolicy(
        shouldShowInApp: true,
        shouldNotifyQuietly: false,
        allowVibration: false,
        allowSound: false,
      );
    }

    final isDue = status == TaskStatus.due && !occurrence.isDone;

    return TaskNotificationPolicy(
      shouldShowInApp: true,
      shouldNotifyQuietly: isDue,
      allowVibration: isDue && enableVibration,
      allowSound: isDue && enableSound,
    );
  }
}

final taskNotificationServiceProvider = Provider<TaskNotificationService>((
  ref,
) {
  return TaskNotificationService(ref.watch(profileRepositoryProvider));
}, dependencies: [profileRepositoryProvider]);
