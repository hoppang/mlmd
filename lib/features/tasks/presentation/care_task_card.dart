import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/author_profile_entity.dart';
import '../../../repositories/profile_repository.dart';
import '../domain/care_task_model.dart';

class CareTaskCard extends ConsumerWidget {
  const CareTaskCard({
    super.key,
    required this.task,
    required this.occurrence,
    required this.onComplete,
    required this.onSkip,
    required this.onUndo,
  });

  final CareTask task;
  final CareTaskOccurrence occurrence;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final computedStatus = occurrence.computedStatusAt(now);
    final isDue = computedStatus == TaskStatus.due && !occurrence.isDone;
    final isCompleted = occurrence.isCompleted;
    final isSkipped = occurrence.isSkipped;

    final profileRepo = ref.watch(profileRepositoryProvider);
    final assigneeProfile = task.assignedToAuthorProfileId != null
        ? profileRepo.authorByProfileId(task.assignedToAuthorProfileId!)
        : null;

    final timeFormatter = DateFormat('a h:mm', 'ko_KR');
    final formattedTime = timeFormatter.format(occurrence.scheduledAt);

    Color cardBorderColor = Colors.grey.shade300;
    Color statusBadgeColor = Colors.grey.shade200;
    Color statusTextColor = Colors.grey.shade800;
    String statusLabel = formattedTime;

    if (isDue) {
      final overdueMin = occurrence.getMinutesOverdueAt(now);
      cardBorderColor = Colors.orange.shade400;
      statusBadgeColor = Colors.orange.shade100;
      statusTextColor = Colors.orange.shade900;
      statusLabel = overdueMin > 0 ? '$overdueMin분 지남' : '지금 할 일';
    } else if (isCompleted) {
      cardBorderColor = Colors.green.shade300;
      statusBadgeColor = Colors.green.shade100;
      statusTextColor = Colors.green.shade900;
      statusLabel = '완료됨';
    } else if (isSkipped) {
      cardBorderColor = Colors.grey.shade300;
      statusBadgeColor = Colors.grey.shade200;
      statusTextColor = Colors.grey.shade600;
      statusLabel = '건너뜀';
    } else {
      cardBorderColor = Colors.blue.shade300;
      statusBadgeColor = Colors.blue.shade50;
      statusTextColor = Colors.blue.shade900;
      statusLabel = '다음 할 일 ($formattedTime)';
    }

    final actionVerb = _getCompleteActionVerb(task.linkedCategory);

    return Card(
      key: ValueKey('task_card_${occurrence.occurrenceId}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cardBorderColor, width: isDue ? 1.5 : 1.0),
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: isDue ? 2 : 0.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBadgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildAssigneeBadge(assigneeProfile),
                const Spacer(),
                Text(
                  formattedTime,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: (isCompleted || isSkipped)
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: (isCompleted || isSkipped)
                    ? Colors.grey.shade600
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!occurrence.isDone) ...[
                  OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('건너뛰기'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(actionVerb),
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: onUndo,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('실행 취소'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeBadge(AuthorProfileEntity? assignee) {
    if (assignee == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '누구나',
          style: TextStyle(fontSize: 11, color: Colors.black87),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Color(assignee.colorValue).withAlpha(40),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Color(assignee.colorValue), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(assignee.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            assignee.nickname,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getCompleteActionVerb(String? linkedCategory) {
    if (linkedCategory == null || linkedCategory.isEmpty) {
      return '완료';
    }
    switch (linkedCategory.toLowerCase()) {
      case 'medication':
        return '먹였어요';
      case 'temperature':
        return '체온 쟀어요';
      case 'bath':
        return '목욕했어요';
      case 'intake':
        return '수유/식사 완료';
      default:
        return '시행했어요';
    }
  }
}
