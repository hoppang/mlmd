import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../objectbox.g.dart';
import '../models/diary_entity.dart';
import '../models/activity_entity.dart';
import '../models/record_draft_entity.dart';
import '../models/author_profile_entity.dart';
import '../models/device_profile_entity.dart';
import '../models/search_document_entity.dart';
import '../models/ai_summary_entity.dart';
import '../models/duplicate_review_edge_entity.dart';
import '../models/logical_event_group_entity.dart';
import '../models/care_task_entity.dart';
import '../models/care_task_occurrence_entity.dart';

class ObjectBoxHelper {
  late final Store store;
  late final Box<DiaryEntity> diaryBox;
  late final Box<ActivityEntity> activityBox;
  late final Box<RecordDraftEntity> draftBox;
  late final Box<AuthorProfileEntity> authorProfileBox;
  late final Box<DeviceProfileEntity> deviceProfileBox;
  late final Box<SearchDocumentEntity> searchDocumentBox;
  late final Box<AiSummaryEntity> aiSummaryBox;
  late final Box<DuplicateReviewEdgeEntity> duplicateReviewEdgeBox;
  late final Box<LogicalEventGroupEntity> logicalEventGroupBox;
  late final Box<CareTaskEntity> careTaskBox;
  late final Box<CareTaskOccurrenceEntity> careTaskOccurrenceBox;

  ObjectBoxHelper._create(this.store) {
    diaryBox = Box<DiaryEntity>(store);
    activityBox = Box<ActivityEntity>(store);
    draftBox = Box<RecordDraftEntity>(store);
    authorProfileBox = Box<AuthorProfileEntity>(store);
    deviceProfileBox = Box<DeviceProfileEntity>(store);
    searchDocumentBox = Box<SearchDocumentEntity>(store);
    aiSummaryBox = Box<AiSummaryEntity>(store);
    duplicateReviewEdgeBox = Box<DuplicateReviewEdgeEntity>(store);
    logicalEventGroupBox = Box<LogicalEventGroupEntity>(store);
    careTaskBox = Box<CareTaskEntity>(store);
    careTaskOccurrenceBox = Box<CareTaskOccurrenceEntity>(store);
  }

  /// 데이터베이스 저장 공간을 열고 초기화합니다.
  /// Opens the database in the platform's app-private documents directory.
  ///
  /// On Android this directory is sandboxed from other apps. The Android
  /// manifest and backup rules also exclude it from cloud backup and
  /// device-to-device transfer because it contains sensitive family data.
  /// ObjectBox for Dart does not expose database-at-rest encryption, and moving
  /// this existing store without a migration would risk data loss. At-rest
  /// protection therefore relies on the device file system and screen lock.
  static Future<ObjectBoxHelper> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storePath = p.join(docsDir.path, "obx-db");

    // openStore는 objectbox.g.dart에 구현되어 있는 자동생성 함수입니다.
    final store = await openStore(directory: storePath);
    return ObjectBoxHelper._create(store);
  }

  /// 모든 로컬 데이터를 삭제합니다. (초기화 오류 복구용)
  static Future<void> resetData() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storePath = p.join(docsDir.path, "obx-db");
    final directory = Directory(storePath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

/// Riverpod에서 사용할 ObjectBoxHelper 프로바이더.
/// main.dart에서 스토어 초기화 후 반드시 재정의(override)하여 주입해야 합니다.
final objectBoxProvider = Provider<ObjectBoxHelper>(
  (ref) => throw UnimplementedError(
    'objectBoxProvider가 초기화되지 않았습니다. main.dart에서 재정의해주십시오.',
  ),
  dependencies: const [],
);
