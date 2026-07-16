import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/diary_repository.dart';

/// 유사 일기 검색 패널.
///
/// 검색 입력 필드와 유사도 % 배지가 포함된 결과 목록을 표시합니다.
/// 상위 [maxResults]개만 표시하며, 유사도 내림차순으로 정렬됩니다.
class SimilarDiaryPanel extends ConsumerStatefulWidget {
  /// 최대 표시 결과 수
  final int maxResults;

  /// 초기 검색어 (일기 조회 페이지에서 현재 일기 내용을 넘길 때 사용)
  final String? initialQuery;

  const SimilarDiaryPanel({
    super.key,
    this.maxResults = 5,
    this.initialQuery,
  });

  @override
  ConsumerState<SimilarDiaryPanel> createState() => _SimilarDiaryPanelState();
}

class _SimilarDiaryPanelState extends ConsumerState<SimilarDiaryPanel> {
  late final TextEditingController _queryController;
  List<SimilarDiaryResult> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
    // 초기 검색어가 있으면 바로 검색
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = ref
          .read(diaryListProvider.notifier)
          .searchSimilar(query, limit: widget.maxResults);
      setState(() => _results = results);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 검색 입력 필드
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: '유사한 날을 검색해 보세요...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isSearching ? null : _search,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search, color: Colors.white),
            ),
          ],
        ),

        // 결과 목록
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '유사한 일기 ${_results.length}건',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ..._results.map((result) => _SimilarDiaryCard(result: result)),
        ] else if (!_isSearching && _queryController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              '유사한 일기가 없습니다.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ],
      ],
    );
  }
}

/// 유사 일기 단일 카드 위젯
class _SimilarDiaryCard extends StatelessWidget {
  final SimilarDiaryResult result;

  const _SimilarDiaryCard({required this.result});

  /// 유사도에 따른 배지 색상
  Color _badgeColor(double percent) {
    if (percent >= 80) return Colors.green.shade600;
    if (percent >= 60) return Colors.orange.shade600;
    return Colors.grey.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final diary = result.diary;
    final percent = result.similarityPercent;
    final dateStr = '${diary.date.year}-'
        '${diary.date.month.toString().padLeft(2, '0')}-'
        '${diary.date.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 유사도 배지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _badgeColor(percent),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${percent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 일기 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          diary.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    diary.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
