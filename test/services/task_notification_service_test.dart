import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/tasks/domain/care_task_model.dart';
import 'package:mlmd/models/author_profile_entity.dart';
import 'package:mlmd/models/device_profile_entity.dart';
import 'package:mlmd/repositories/profile_repository.dart';
import 'package:mlmd/services/task_notification_service.dart';

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.author);

  final AuthorProfileEntity? author;

  @override
  AuthorProfileEntity? get currentAuthor => author;

  @override
  DeviceProfileEntity get currentDevice =>
      DeviceProfileEntity(deviceProfileId: 'dev-1', createdAt: DateTime.now());

  @override
  bool get hasSharedHistory => false;

  @override
  AuthorProfileEntity? authorByProfileId(String authorProfileId) {
    if (author?.authorProfileId == authorProfileId) return author;
    return null;
  }

  @override
  List<AuthorProfileEntity> getAuthorProfiles() =>
      author != null ? [author!] : [];

  @override
  AuthorProfileEntity createAuthor({
    required String nickname,
    required int colorValue,
  }) {
    throw UnimplementedError();
  }

  @override
  AuthorProfileEntity updateAuthor({
    required String authorProfileId,
    required String nickname,
    required int colorValue,
  }) {
    throw UnimplementedError();
  }

  @override
  void selectAuthor(String authorProfileId) {}

  @override
  void markSharedHistory() {}

  @override
  RecordSource requireCurrentSource() {
    return RecordSource(
      authorProfileId: author?.authorProfileId ?? 'auth-1',
      deviceProfileId: 'dev-1',
    );
  }
}

void main() {
  final mom = AuthorProfileEntity(
    authorProfileId: 'author-mom',
    nickname: '엄마',
    colorValue: 0xFFFF5722,
    createdAt: DateTime.now(),
  );

  test(
    'evaluateNotificationPolicy - inAppOnly mode disables quiet notification',
    () {
      final profileRepo = _FakeProfileRepository(mom);
      final notificationService = TaskNotificationService(profileRepo);

      final now = DateTime.now();
      final task = CareTask(
        taskId: 'task-1',
        title: '비타민 주기',
        notificationMode: TaskNotificationMode.inAppOnly,
        createdAt: now,
        createdByAuthorProfileId: mom.authorProfileId,
        createdByDeviceProfileId: 'dev-1',
      );

      final occurrence = CareTaskOccurrence(
        occurrenceId: 'occ-1',
        taskId: 'task-1',
        scheduledAt: now.subtract(const Duration(minutes: 10)),
      );

      final policy = notificationService.evaluateNotificationPolicy(
        task: task,
        occurrence: occurrence,
        now: now,
      );

      expect(policy.shouldShowInApp, isTrue);
      expect(policy.shouldNotifyQuietly, isFalse);
    },
  );

  test(
    'evaluateNotificationPolicy - quietToAssignee notifies quietly for assigned user when due',
    () {
      final profileRepo = _FakeProfileRepository(mom);
      final notificationService = TaskNotificationService(profileRepo);

      final now = DateTime.now();
      final task = CareTask(
        taskId: 'task-2',
        title: '해열제 먹이기',
        assignedToAuthorProfileId: 'author-mom',
        notificationMode: TaskNotificationMode.quietToAssignee,
        createdAt: now,
        createdByAuthorProfileId: mom.authorProfileId,
        createdByDeviceProfileId: 'dev-1',
      );

      final occurrence = CareTaskOccurrence(
        occurrenceId: 'occ-2',
        taskId: 'task-2',
        scheduledAt: now.subtract(const Duration(minutes: 5)),
      );

      final policy = notificationService.evaluateNotificationPolicy(
        task: task,
        occurrence: occurrence,
        now: now,
      );

      expect(policy.shouldShowInApp, isTrue);
      expect(policy.shouldNotifyQuietly, isTrue);
      expect(policy.allowVibration, isTrue);
      expect(policy.allowSound, isFalse);
    },
  );

  test(
    'evaluateNotificationPolicy - quietToAssignee does NOT quietly notify different user',
    () {
      final dad = AuthorProfileEntity(
        authorProfileId: 'author-dad',
        nickname: '아빠',
        colorValue: 0xFF2196F3,
        createdAt: DateTime.now(),
      );

      final profileRepo = _FakeProfileRepository(dad);
      final notificationService = TaskNotificationService(profileRepo);

      final now = DateTime.now();
      final task = CareTask(
        taskId: 'task-3',
        title: '해열제 먹이기',
        assignedToAuthorProfileId:
            'author-mom', // assigned to mom, but current user is dad
        notificationMode: TaskNotificationMode.quietToAssignee,
        createdAt: now,
        createdByAuthorProfileId: mom.authorProfileId,
        createdByDeviceProfileId: 'dev-1',
      );

      final occurrence = CareTaskOccurrence(
        occurrenceId: 'occ-3',
        taskId: 'task-3',
        scheduledAt: now.subtract(const Duration(minutes: 5)),
      );

      final policy = notificationService.evaluateNotificationPolicy(
        task: task,
        occurrence: occurrence,
        now: now,
      );

      expect(policy.shouldShowInApp, isTrue);
      expect(policy.shouldNotifyQuietly, isFalse);
    },
  );
}
