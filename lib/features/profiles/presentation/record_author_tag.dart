import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/diary_entity.dart';
import '../../../repositories/profile_repository.dart';

bool shouldShowAuthorTags(
  Iterable<DiaryEntity> diaries,
  ProfileRepository profiles,
) {
  if (!profiles.hasSharedHistory) return false;
  final authorIds = <String>{};
  for (final diary in diaries) {
    final diaryAuthor = diary.createdByAuthorProfileId;
    if (diaryAuthor != null) authorIds.add(diaryAuthor);
    for (final activity in diary.activities) {
      final activityAuthor = activity.createdByAuthorProfileId;
      if (activityAuthor != null) authorIds.add(activityAuthor);
    }
    if (authorIds.length > 1) return true;
  }
  return false;
}

class RecordAuthorTag extends ConsumerWidget {
  const RecordAuthorTag({
    super.key,
    required this.authorProfileId,
    required this.visible,
  });

  final String? authorProfileId;
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible || authorProfileId == null) return const SizedBox.shrink();
    final profiles = ref.watch(authorProfileListProvider);
    final matches = profiles
        .where((profile) => profile.authorProfileId == authorProfileId)
        .toList(growable: false);
    if (matches.isEmpty) return const SizedBox.shrink();
    final profile = matches.single;
    final color = Color(profile.colorValue);
    return Semantics(
      label: profile.nickname,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              profile.nickname,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
