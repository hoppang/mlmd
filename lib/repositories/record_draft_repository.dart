import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/objectbox_helper.dart';
import '../models/record_draft_entity.dart';
import '../objectbox.g.dart';

abstract class RecordDraftRepository {
  RecordDraftEntity? getByDraftId(String draftId);
  RecordDraftEntity? getEditDraft(String targetRecordId);
  List<RecordDraftEntity> getCreateDrafts(String recordType);
  List<RecordDraftEntity> getAllDrafts();
  int saveDraft(RecordDraftEntity draft);
  bool deleteDraft(String draftId);
}

class RecordDraftRepositoryImpl implements RecordDraftRepository {
  RecordDraftRepositoryImpl(this._objectBox);

  final ObjectBoxHelper _objectBox;

  @override
  RecordDraftEntity? getByDraftId(String draftId) {
    final query = _objectBox.draftBox
        .query(RecordDraftEntity_.draftId.equals(draftId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  @override
  RecordDraftEntity? getEditDraft(String targetRecordId) {
    final query = _objectBox.draftBox
        .query(
          RecordDraftEntity_.draftKind.equals('editRecord') &
              RecordDraftEntity_.targetRecordId.equals(targetRecordId),
        )
        .order(RecordDraftEntity_.lastSavedAt, flags: Order.descending)
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  @override
  List<RecordDraftEntity> getCreateDrafts(String recordType) {
    final query = _objectBox.draftBox
        .query(
          RecordDraftEntity_.draftKind.equals('createRecord') &
              RecordDraftEntity_.recordType.equals(recordType),
        )
        .order(RecordDraftEntity_.lastSavedAt, flags: Order.descending)
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  @override
  List<RecordDraftEntity> getAllDrafts() {
    final query = _objectBox.draftBox
        .query()
        .order(RecordDraftEntity_.lastSavedAt, flags: Order.descending)
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  @override
  int saveDraft(RecordDraftEntity draft) {
    final existing = getByDraftId(draft.draftId);
    if (existing != null) draft.id = existing.id;
    return _objectBox.draftBox.put(draft);
  }

  @override
  bool deleteDraft(String draftId) {
    final existing = getByDraftId(draftId);
    return existing != null && _objectBox.draftBox.remove(existing.id);
  }
}

final recordDraftRepositoryProvider = Provider<RecordDraftRepository>((ref) {
  return RecordDraftRepositoryImpl(ref.watch(objectBoxProvider));
});

class RecordDraftListNotifier extends Notifier<List<RecordDraftEntity>> {
  @override
  List<RecordDraftEntity> build() {
    return ref.watch(recordDraftRepositoryProvider).getAllDrafts();
  }

  void reload() {
    state = ref.read(recordDraftRepositoryProvider).getAllDrafts();
  }
}

final recordDraftListProvider =
    NotifierProvider<RecordDraftListNotifier, List<RecordDraftEntity>>(
      RecordDraftListNotifier.new,
    );
