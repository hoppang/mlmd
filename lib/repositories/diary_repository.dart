import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary_entity.dart';
import '../data/objectbox_helper.dart';
import '../objectbox.g.dart';
import '../services/embedding_service.dart';
import 'dart:math';

/// 유사 검색 결과 모델
class SimilarDiaryResult {
  final DiaryEntity diary;

  /// 유사도 (0.0 ~ 100.0 %)
  final double similarityPercent;

  const SimilarDiaryResult({
    required this.diary,
    required this.similarityPercent,
  });
}

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

  /// 쿼리 텍스트와 의미적으로 유사한 일기를 HNSW 벡터 검색으로 조회합니다.
  /// [embeddingService]로 쿼리를 임베딩한 뒤 가장 가까운 [limit]개를 반환합니다.
  /// 반환값은 유사도(%) 내림차순으로 정렬됩니다.
  List<SimilarDiaryResult> searchSimilar(
    String query,
    EmbeddingService embeddingService, {
    int limit = 5,
  });
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

  @override
  List<SimilarDiaryResult> searchSimilar(
    String query,
    EmbeddingService embeddingService, {
    int limit = 5,
  }) {
    final queryVector = embeddingService.getQueryEmbedding(query);
    if (queryVector == null || queryVector.isEmpty) return [];

    // ObjectBox HNSW: nearestNeighborsF32는 L2 제곱 거리(score)를 반환
    final obxQuery = _obxHelper.diaryBox
        .query(DiaryEntity_.embedding.nearestNeighborsF32(queryVector, limit))
        .build();

    final withScores = obxQuery.findWithScores();
    obxQuery.close();

    // L2 제곱 거리 → 유사도 % 변환
    // 벡터가 정규화되어 있을 때, L2 제곱 거리(D^2) = 2 - 2 * CosSim
    // 따라서 CosSim = 1 - (D^2 / 2)
    return withScores.map((item) {
      final distance = item.score;
      final cosSim = 1.0 - (distance / 2.0);
      
      // E5 같은 밀집 임베딩(dense embedding) 모델은 의미가 전혀 달라도 
      // 코사인 유사도가 0.8 이상으로 매우 높게 나오는 특성이 있습니다.
      // 사용자 체감상 직관적인 퍼센티지(0~100%)로 보정하기 위해 0.82를 0%의 기준으로 삼습니다.
      double mapped = (cosSim - 0.82) / (1.0 - 0.82) * 100.0;
      
      // [키워드 검색(Lexical) 보정]
      // 의미론적 검색(Vector)의 한계로 인해, 단어가 정확히 일치해도 100%가 나오지 않는 문제를 해결합니다.
      // 실제 텍스트에 검색어가 그대로 포함되어 있다면 확정적으로 가산점을 주어 최상단에 노출되도록 합니다.
      final exactMatch = item.object.title.contains(query) || item.object.content.contains(query);
      if (exactMatch) {
        mapped += 50.0; 
      }

      final clamped = mapped.clamp(0.0, 100.0);

      return SimilarDiaryResult(
        diary: item.object,
        similarityPercent: clamped,
      );
    }).where((result) => result.similarityPercent > 0.0).toList()
      ..sort((a, b) => b.similarityPercent.compareTo(a.similarityPercent));
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

  void addDiary(String title, String content) {
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    final embedding = embeddingService.getEmbedding(content);
    final now = DateTime.now();
    final newDiary = DiaryEntity(
      date: now,
      title: title,
      content: content,
      lastModified: now,
      embedding: embedding,
    );
    repo.saveDiary(newDiary);
    state = repo.getDiaries();
  }

  /// 현재 텍스트 쿼리와 유사한 일기를 검색합니다.
  List<SimilarDiaryResult> searchSimilar(String query, {int limit = 5}) {
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    return repo.searchSimilar(query, embeddingService, limit: limit);
  }

  void updateDiary(DiaryEntity diary, String newTitle, String newContent) {
    final repo = ref.read(diaryRepositoryProvider);
    final embeddingService = ref.read(embeddingServiceProvider);
    final embedding = embeddingService.getEmbedding(newContent);
    diary.title = newTitle;
    diary.content = newContent;
    diary.embedding = embedding;
    repo.saveDiary(diary); // saveDiary가 자동으로 lastModified를 갱신합니다.
    state = repo.getDiaries();
  }

  void deleteDiary(int id) {
    final repo = ref.read(diaryRepositoryProvider);
    repo.deleteDiary(id);
    state = repo.getDiaries();
  }

}

final diaryListProvider = NotifierProvider<DiaryListNotifier, List<DiaryEntity>>(DiaryListNotifier.new);

