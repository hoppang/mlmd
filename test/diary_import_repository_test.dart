import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/data/objectbox_helper.dart';
import 'package:mlmd/models/activity_entity.dart';
import 'package:mlmd/models/diary_entity.dart';
import 'package:mlmd/models/record_draft_entity.dart';
import 'package:mlmd/models/author_profile_entity.dart';
import 'package:mlmd/models/device_profile_entity.dart';
import 'package:mlmd/models/search_document_entity.dart';
import 'package:mlmd/models/ai_summary_entity.dart';
import 'package:mlmd/models/duplicate_review_edge_entity.dart';
import 'package:mlmd/models/logical_event_group_entity.dart';
import 'package:mlmd/objectbox.g.dart';
import 'package:mlmd/repositories/diary_repository.dart';
import 'package:mlmd/repositories/profile_repository.dart';
import 'package:mlmd/transfer/canonical_transfer_document.dart';
import 'package:mlmd/transfer/diary_transfer_service.dart';

class _TestObjectBoxHelper implements ObjectBoxHelper {
  @override
  late final Store store;
  @override
  late final Box<DiaryEntity> diaryBox;
  @override
  late final Box<ActivityEntity> activityBox;
  @override
  late final Box<RecordDraftEntity> draftBox;
  @override
  late final Box<AuthorProfileEntity> authorProfileBox;
  @override
  late final Box<DeviceProfileEntity> deviceProfileBox;
  @override
  late final Box<SearchDocumentEntity> searchDocumentBox;
  @override
  late final Box<AiSummaryEntity> aiSummaryBox;
  @override
  late final Box<DuplicateReviewEdgeEntity> duplicateReviewEdgeBox;
  @override
  late final Box<LogicalEventGroupEntity> logicalEventGroupBox;
  final Directory directory;

  _TestObjectBoxHelper(this.store, this.directory) {
    diaryBox = Box<DiaryEntity>(store);
    activityBox = Box<ActivityEntity>(store);
    draftBox = Box<RecordDraftEntity>(store);
    authorProfileBox = Box<AuthorProfileEntity>(store);
    deviceProfileBox = Box<DeviceProfileEntity>(store);
    searchDocumentBox = Box<SearchDocumentEntity>(store);
    aiSummaryBox = Box<AiSummaryEntity>(store);
    duplicateReviewEdgeBox = Box<DuplicateReviewEdgeEntity>(store);
    logicalEventGroupBox = Box<LogicalEventGroupEntity>(store);
  }

  static Future<_TestObjectBoxHelper> create() async {
    final directory = await Directory.systemTemp.createTemp('mlmd-import-');
    return _TestObjectBoxHelper(
      await openStore(directory: directory.path),
      directory,
    );
  }

  void close() {
    store.close();
    directory.deleteSync(recursive: true);
  }
}

void main() {
  late _TestObjectBoxHelper helper;
  late DiaryRepository repository;
  late ProfileRepository profileRepository;

  setUp(() async {
    helper = await _TestObjectBoxHelper.create();
    profileRepository = ProfileRepositoryImpl(helper);
    profileRepository.createAuthor(nickname: '테스트 작성자', colorValue: 0xFF00796B);
    repository = DiaryRepositoryImpl(helper, profileRepository);
  });

  tearDown(() => helper.close());

  CanonicalImportDocument document({
    required DateTime modified,
    String title = '백업 일기',
  }) => CanonicalImportDocument(
    exportedAt: DateTime.utc(2026, 7, 18),
    appVersion: 'test',
    diaries: [
      CanonicalDiary(
        recordId: '550e8400-e29b-41d4-a716-446655440000',
        date: DateTime(2026, 7, 18, 20, 15),
        title: title,
        summary: '요약',
        content: '본문',
        lastModified: modified,
        activities: [
          CanonicalActivity(
            type: '수유',
            time: DateTime(2026, 7, 18, 19, 30),
            details: '120ml',
            lastModified: modified.subtract(const Duration(minutes: 1)),
          ),
        ],
      ),
    ],
  );

  test('legacy diaries receive stable unique record IDs', () {
    helper.diaryBox.put(
      DiaryEntity(
        date: DateTime(2026),
        title: 'legacy',
        content: 'content',
        lastModified: DateTime.utc(2026),
      ),
    );

    repository = DiaryRepositoryImpl(helper, profileRepository);
    final first = repository.getDiaries().single.recordId;
    final second = DiaryRepositoryImpl(
      helper,
      profileRepository,
    ).getDiaries().single.recordId;

    expect(first, isNotNull);
    expect(first, second);
  });

  test('skip policy is idempotent and preserves imported timestamps', () {
    final modified = DateTime.utc(2026, 7, 18, 12, 20);
    final first = repository.importDocument(
      document(modified: modified),
      ImportConflictPolicy.skipExisting,
    );
    final second = repository.importDocument(
      document(modified: modified),
      ImportConflictPolicy.skipExisting,
    );

    expect(first.inserted, 1);
    expect(second.skipped, 1);
    expect(repository.getDiaries(), hasLength(1));
    final saved = repository.getDiaries().single;
    expect(
      saved.lastModified.millisecondsSinceEpoch,
      modified.millisecondsSinceEpoch,
    );
    expect(saved.embedding, isNull);
    expect(
      saved.activities.single.lastModified.millisecondsSinceEpoch,
      modified.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    );
  });

  test('overwrite policy replaces activities only for newer backups', () {
    final older = DateTime.utc(2026, 7, 18, 10);
    repository.importDocument(
      document(modified: older, title: 'old'),
      ImportConflictPolicy.skipExisting,
    );
    final originalId = repository.getDiaries().single.id;

    final preview = repository.previewImport(
      document(modified: older.subtract(const Duration(minutes: 1))),
      ImportConflictPolicy.overwriteIfNewer,
    );
    expect(preview.newerCount, 0);
    expect(preview.skippedCount, 1);

    final newer = older.add(const Duration(hours: 2));
    final result = repository.importDocument(
      document(modified: newer, title: 'new'),
      ImportConflictPolicy.overwriteIfNewer,
    );
    final saved = repository.getDiaries().single;
    expect(result.updated, 1);
    expect(saved.id, originalId);
    expect(saved.title, 'new');
    expect(
      saved.lastModified.millisecondsSinceEpoch,
      newer.millisecondsSinceEpoch,
    );
    expect(saved.activities, hasLength(1));
    expect(saved.activities.single.diary.targetId, originalId);
  });

  test(
    'safe import writes a restorable snapshot before applying changes',
    () async {
      final modified = DateTime.utc(2026, 7, 18, 12);
      repository.importDocument(
        document(modified: modified, title: 'before import'),
        ImportConflictPolicy.skipExisting,
      );
      final incoming = CanonicalImportDocument(
        exportedAt: DateTime.utc(2026, 7, 19),
        appVersion: 'test',
        diaries: [
          CanonicalDiary(
            recordId: '550e8400-e29b-41d4-a716-446655440001',
            date: DateTime(2026, 7, 19),
            title: 'new record',
            summary: '',
            content: '',
            lastModified: modified,
            activities: const [],
          ),
        ],
      );
      final service = DiaryTransferService(repository: repository);
      final safetyDirectory = Directory('${helper.directory.path}/safety');

      final result = await service.applyWithAutomaticBackup(
        PreparedDiaryImport(
          document: incoming,
          schemaVersion: 1,
          sourceName: 'incoming.mlmd.json',
        ),
        ImportConflictPolicy.skipExisting,
        backupDirectory: safetyDirectory,
        createdAt: DateTime(2026, 7, 19, 9, 30),
      );

      expect(result.inserted, 1);
      expect(repository.getDiaries(), hasLength(2));
      final safetyFiles = safetyDirectory.listSync().whereType<File>().toList();
      expect(safetyFiles, hasLength(1));
      final snapshot = service.decodeImportBytes(
        await safetyFiles.single.readAsBytes(),
        sourceName: safetyFiles.single.path,
      );
      expect(snapshot.document.diaries, hasLength(1));
      expect(snapshot.document.diaries.single.title, 'before import');
    },
  );

  test('preview distinguishes identical records from content conflicts', () {
    final modified = DateTime.utc(2026, 7, 18, 12);
    repository.importDocument(
      document(modified: modified, title: 'same'),
      ImportConflictPolicy.skipExisting,
    );

    final identical = repository.previewImport(
      document(modified: modified.add(const Duration(hours: 1)), title: 'same'),
      ImportConflictPolicy.skipExisting,
    );
    final conflict = repository.previewImport(
      document(
        modified: modified.add(const Duration(hours: 1)),
        title: 'changed',
      ),
      ImportConflictPolicy.skipExisting,
    );

    expect(identical.identicalCount, 1);
    expect(identical.conflictCount, 0);
    expect(conflict.identicalCount, 0);
    expect(conflict.conflictCount, 1);
  });
}
