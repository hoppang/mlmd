import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../objectbox.g.dart';
import '../models/diary_entity.dart';
import '../models/activity_entity.dart';
import '../models/record_draft_entity.dart';

class ObjectBoxHelper {
  late final Store store;
  late final Box<DiaryEntity> diaryBox;
  late final Box<ActivityEntity> activityBox;
  late final Box<RecordDraftEntity> draftBox;

  ObjectBoxHelper._create(this.store) {
    diaryBox = Box<DiaryEntity>(store);
    activityBox = Box<ActivityEntity>(store);
    draftBox = Box<RecordDraftEntity>(store);
  }

  /// 데이터베이스 저장 공간을 열고 초기화합니다.
  static Future<ObjectBoxHelper> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storePath = p.join(docsDir.path, "obx-db");

    // openStore는 objectbox.g.dart에 구현되어 있는 자동생성 함수입니다.
    final store = await openStore(directory: storePath);
    return ObjectBoxHelper._create(store);
  }
}

/// Riverpod에서 사용할 ObjectBoxHelper 프로바이더.
/// main.dart에서 스토어 초기화 후 반드시 재정의(override)하여 주입해야 합니다.
final objectBoxProvider = Provider<ObjectBoxHelper>((ref) {
  throw UnimplementedError(
    'objectBoxProvider가 초기화되지 않았습니다. main.dart에서 재정의해주십시오.',
  );
});
