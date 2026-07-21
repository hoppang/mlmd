import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/diary/application/diary_draft_payload.dart';
import 'package:mlmd/features/drafts/application/draft_autosave_controller.dart';
import 'package:mlmd/features/drafts/application/active_draft_registry.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/repositories/record_draft_repository.dart';

class _MemoryDraftRepository implements RecordDraftRepository {
  final Map<String, RecordDraftEntity> drafts = {};
  var saveCount = 0;
  var failSave = false;

  @override
  bool deleteDraft(String draftId) => drafts.remove(draftId) != null;

  @override
  List<RecordDraftEntity> getAllDrafts() => drafts.values.toList();

  @override
  RecordDraftEntity? getByDraftId(String draftId) => drafts[draftId];

  @override
  List<RecordDraftEntity> getCreateDrafts(String recordType) => drafts.values
      .where(
        (draft) =>
            draft.draftKind == 'createRecord' && draft.recordType == recordType,
      )
      .toList();

  @override
  RecordDraftEntity? getEditDraft(String targetRecordId) {
    for (final draft in drafts.values) {
      if (draft.draftKind == 'editRecord' &&
          draft.targetRecordId == targetRecordId) {
        return draft;
      }
    }
    return null;
  }

  @override
  int saveDraft(RecordDraftEntity draft) {
    if (failSave) throw StateError('disk full');
    saveCount++;
    drafts[draft.draftId] = draft;
    return saveCount;
  }
}

void main() {
  group('DiaryDraftPayload', () {
    test('round-trips all user-entered fields', () {
      final occurredAt = DateTime(2026, 7, 21, 14, 30);
      final activityTime = DateTime(2026, 7, 21, 13, 10);
      final original = DiaryDraftPayload(
        inputMode: 'manual',
        title: '감기 기록',
        rawText: '병원에 다녀옴',
        summary: '저녁 약 처방',
        occurredAt: occurredAt,
        activities: [
          DiaryDraftActivity(
            type: '투약',
            detail: '18:30',
            occurredAt: activityTime,
          ),
        ],
      );

      final restored = DiaryDraftPayload.decode(original.encode());

      expect(restored.inputMode, original.inputMode);
      expect(restored.title, original.title);
      expect(restored.rawText, original.rawText);
      expect(restored.summary, original.summary);
      expect(restored.occurredAt, occurredAt);
      expect(restored.activities.single.type, '투약');
      expect(restored.activities.single.detail, '18:30');
      expect(restored.activities.single.occurredAt, activityTime);
    });

    test('restores v1 drafts with original record timestamps', () {
      final recordTime = DateTime(2026, 7, 20, 9);
      final activityTime = DateTime(2026, 7, 20, 8, 30);
      final legacy = DiaryDraftPayload.decode(
        '{"inputMode":"manual","title":"기존 초안",'
        '"rawText":"","summary":"",'
        '"activities":[{"type":"수유","detail":"120ml"}]}',
      );
      final fallback = DiaryDraftPayload(
        inputMode: 'manual',
        title: '원본',
        rawText: '',
        summary: '',
        occurredAt: recordTime,
        activities: [
          DiaryDraftActivity(
            type: '수유',
            detail: '100ml',
            occurredAt: activityTime,
          ),
        ],
      );

      final restored = legacy.withFallbackTimes(fallback);

      expect(restored.title, '기존 초안');
      expect(restored.occurredAt, recordTime);
      expect(restored.activities.single.occurredAt, activityTime);
    });

    test('keeps an explicitly unknown v2 activity time unknown', () {
      final original = DiaryDraftPayload(
        inputMode: 'manual',
        title: '집계 이벤트',
        rawText: '',
        summary: '',
        occurredAt: DateTime(2026, 7, 21, 12),
        activities: const [DiaryDraftActivity(type: '수유', detail: '여러 번')],
      );

      final restored = DiaryDraftPayload.decode(original.encode());

      expect(restored.activities.single.occurredAt, isNull);
    });

    test('ignores presentation mode when comparing record content', () {
      const simple = DiaryDraftPayload(
        inputMode: 'simple',
        title: '',
        rawText: '같은 내용',
        summary: '',
        activities: [],
      );
      const manual = DiaryDraftPayload(
        inputMode: 'manual',
        title: '',
        rawText: '같은 내용',
        summary: '',
        activities: [],
      );

      expect(simple.hasSameRecordContent(manual), isTrue);
    });
  });

  group('DraftAutosaveController', () {
    test('does not persist an empty draft', () {
      final repository = _MemoryDraftRepository();
      final controller = DraftAutosaveController(
        repository: repository,
        draftId: 'draft-1',
        draftKind: 'createRecord',
        recordType: 'diary',
        capturePayload: () => '{}',
        hasMeaningfulChanges: () => false,
        onStatusChanged: (_) {},
        onDraftListChanged: () {},
      );

      controller.flush();

      expect(repository.drafts, isEmpty);
      controller.dispose();
    });

    test('persists content and does not recreate it after commit', () async {
      final repository = _MemoryDraftRepository();
      var payload = '{"rawText":"기록 중"}';
      var changed = true;
      final statuses = <DraftSaveStatus>[];
      final controller = DraftAutosaveController(
        repository: repository,
        draftId: 'draft-2',
        draftKind: 'createRecord',
        recordType: 'diary',
        capturePayload: () => payload,
        hasMeaningfulChanges: () => changed,
        onStatusChanged: statuses.add,
        onDraftListChanged: () {},
        debounceDuration: const Duration(milliseconds: 1),
      );

      controller.flush();
      expect(repository.getByDraftId('draft-2')?.fieldPayloadJson, payload);
      expect(statuses.last, DraftSaveStatus.saved);

      repository.deleteDraft('draft-2');
      controller.markCommitted();
      payload = '{"rawText":"저장 뒤 변경"}';
      changed = true;
      controller.schedule();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.dispose();

      expect(repository.getByDraftId('draft-2'), isNull);
      expect(repository.saveCount, 1);
    });

    test('reports failure so navigation or window close can stay open', () {
      final repository = _MemoryDraftRepository()..failSave = true;
      final statuses = <DraftSaveStatus>[];
      final controller = DraftAutosaveController(
        repository: repository,
        draftId: 'draft-failure',
        draftKind: 'createRecord',
        recordType: 'diary',
        capturePayload: () => '{"rawText":"보호할 내용"}',
        hasMeaningfulChanges: () => true,
        onStatusChanged: statuses.add,
        onDraftListChanged: () {},
      );

      expect(controller.flush(), isFalse);
      expect(statuses.last, DraftSaveStatus.failed);
      controller.markCommitted();
    });
  });

  test('active draft registry flushes every editor before desktop close', () {
    var first = 0;
    var second = 0;
    bool flushFirst() {
      first++;
      return true;
    }

    bool flushSecond() {
      second++;
      return false;
    }

    ActiveDraftRegistry.instance
      ..register(flushFirst)
      ..register(flushSecond);

    expect(ActiveDraftRegistry.instance.flushAll(), isFalse);
    expect(first, 1);
    expect(second, 1);

    ActiveDraftRegistry.instance
      ..unregister(flushFirst)
      ..unregister(flushSecond);
  });
}
