import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary_entity.dart';
import '../data/objectbox_helper.dart';

/// 일기 CRUD 처리를 위한 Repository 인터페이스
abstract class DiaryRepository {
  /// 모든 일기 목록을 반환합니다.
  List<DiaryEntity> getDiaries();

  /// 지정한 ID에 해당하는 일기를 조회합니다.
  DiaryEntity? getDiary(int id);

  /// 일기를 저장(생성 또는 수정)합니다.
  /// 저장 시 `lastModified` 타임스탬프가 자동으로 현재 시간으로 갱신됩니다.
  int saveDiary(DiaryEntity diary);

  /// 지정한 ID의 일기를 삭제합니다.
  bool deleteDiary(int id);
}

/// DiaryRepository의 ObjectBox 구현체
class DiaryRepositoryImpl implements DiaryRepository {
  final ObjectBoxHelper _obxHelper;

  DiaryRepositoryImpl(this._obxHelper);

  @override
  List<DiaryEntity> getDiaries() {
    return _obxHelper.diaryBox.getAll();
  }

  @override
  DiaryEntity? getDiary(int id) {
    return _obxHelper.diaryBox.get(id);
  }

  @override
  int saveDiary(DiaryEntity diary) {
    // 트리거: 생성 및 수정 시 자동으로 lastModified 갱신
    diary.lastModified = DateTime.now();
    return _obxHelper.diaryBox.put(diary);
  }

  @override
  bool deleteDiary(int id) {
    return _obxHelper.diaryBox.remove(id);
  }
}

/// Riverpod에서 제공할 DiaryRepository 프로바이더
final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final obxHelper = ref.watch(objectBoxProvider);
  return DiaryRepositoryImpl(obxHelper);
});

/// 일기 목록의 상태와 변경을 관리하는 Riverpod Notifier
class DiaryListNotifier extends Notifier<List<DiaryEntity>> {
  @override
  List<DiaryEntity> build() {
    final repo = ref.watch(diaryRepositoryProvider);
    return repo.getDiaries();
  }

  void addDiary(String content) {
    final repo = ref.read(diaryRepositoryProvider);
    final now = DateTime.now();
    final newDiary = DiaryEntity(
      date: now,
      title: '일기 (${_formatDateTime(now)})',
      content: content,
      lastModified: now,
    );
    repo.saveDiary(newDiary);
    state = repo.getDiaries();
  }

  void updateDiary(DiaryEntity diary, String newContent) {
    final repo = ref.read(diaryRepositoryProvider);
    diary.content = newContent;
    repo.saveDiary(diary); // saveDiary가 자동으로 lastModified를 갱신합니다.
    state = repo.getDiaries();
  }

  void deleteDiary(int id) {
    final repo = ref.read(diaryRepositoryProvider);
    repo.deleteDiary(id);
    state = repo.getDiaries();
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

final diaryListProvider = NotifierProvider<DiaryListNotifier, List<DiaryEntity>>(DiaryListNotifier.new);

