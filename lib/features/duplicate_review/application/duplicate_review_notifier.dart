import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/duplicate_review_repository.dart';
import '../../diary/application/diary_list_notifier.dart';

class DuplicateReviewNotifier extends Notifier<List<DuplicateReviewItem>> {
  @override
  List<DuplicateReviewItem> build() {
    final diaries = ref.watch(diaryListProvider);
    return ref
        .watch(duplicateReviewRepositoryProvider)
        .synchronize(diaries, includeResolved: true);
  }

  void useRepresentative(String pairKey, String recordId) {
    ref
        .read(duplicateReviewRepositoryProvider)
        .useRepresentative(pairKey, recordId);
    _reload();
  }

  void markDistinct(String pairKey) {
    ref.read(duplicateReviewRepositoryProvider).markDistinct(pairKey);
    _reload();
  }

  void defer(String pairKey) {
    ref.read(duplicateReviewRepositoryProvider).defer(pairKey);
    _reload();
  }

  void resetDecision(String pairKey) {
    ref.read(duplicateReviewRepositoryProvider).resetDecision(pairKey);
    _reload();
  }

  void _reload() {
    state = ref
        .read(duplicateReviewRepositoryProvider)
        .synchronize(ref.read(diaryListProvider), includeResolved: true);
  }
}

final duplicateReviewListProvider =
    NotifierProvider<DuplicateReviewNotifier, List<DuplicateReviewItem>>(
      DuplicateReviewNotifier.new,
      dependencies: [duplicateReviewRepositoryProvider, diaryListProvider],
    );
