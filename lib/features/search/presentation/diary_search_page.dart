import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/presentation/app_empty_state.dart';
import '../../../core/presentation/adaptive_detail.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/diary_entity.dart';
import '../../../repositories/diary_repository.dart';
import '../../../utils/logger.dart';
import '../../diary/application/diary_list_notifier.dart';

enum _DiarySearchSort { relevance, newest, oldest }

class DiarySearchPage extends ConsumerStatefulWidget {
  const DiarySearchPage({
    required this.onEditDiary,
    this.focusRequest,
    super.key,
  });

  final ValueChanged<DiaryEntity> onEditDiary;
  final ValueListenable<int>? focusRequest;

  @override
  ConsumerState<DiarySearchPage> createState() => _DiarySearchPageState();
}

class _DiarySearchPageState extends ConsumerState<DiarySearchPage> {
  final _queryController = TextEditingController();
  final _queryFocusNode = FocusNode(debugLabel: 'search query');
  List<DiarySearchResult> _results = const [];
  _DiarySearchSort _sort = _DiarySearchSort.relevance;
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _hasError = false;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.focusRequest?.addListener(_requestQueryFocus);
  }

  @override
  void didUpdateWidget(covariant DiarySearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusRequest == widget.focusRequest) return;
    oldWidget.focusRequest?.removeListener(_requestQueryFocus);
    widget.focusRequest?.addListener(_requestQueryFocus);
  }

  void _requestQueryFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _queryFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.focusRequest?.removeListener(_requestQueryFocus);
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isSearching) return;

    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
      _hasError = false;
    });
    try {
      final results = await ref
          .read(diaryListProvider.notifier)
          .searchRecords(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = results;
        _hasSearched = true;
      });
    } catch (error, stackTrace) {
      logger.e('Diary search failed.', error: error, stackTrace: stackTrace);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = const [];
        _hasSearched = true;
        _hasError = true;
      });
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _isSearching = false);
      }
    }
  }

  List<DiarySearchResult> get _sortedResults {
    final results = [..._results];
    results.sort((a, b) {
      return switch (_sort) {
        _DiarySearchSort.relevance =>
          b.relevanceScore.compareTo(a.relevanceScore) != 0
              ? b.relevanceScore.compareTo(a.relevanceScore)
              : b.occurredAt.compareTo(a.occurredAt),
        _DiarySearchSort.newest => b.occurredAt.compareTo(a.occurredAt),
        _DiarySearchSort.oldest => a.occurredAt.compareTo(b.occurredAt),
      };
    });
    return results;
  }

  Future<void> _openResult(DiarySearchResult result) async {
    final shouldEdit = await showAdaptiveDetail<bool>(
      context: context,
      builder: (context) => _SearchResultDetail(result: result),
    );
    if (shouldEdit == true && mounted) widget.onEditDiary(result.diary);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AdaptiveContentFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('search-query-field'),
                    controller: _queryController,
                    focusNode: _queryFocusNode,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: loc.searchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  key: const Key('search-submit-button'),
                  onPressed: _isSearching ? null : _search,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  child: _isSearching
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(loc.searchAction),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_results.isNotEmpty && !_hasError) _buildResultHeader(loc),
            Expanded(child: _buildBody(loc)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loc.searchResultCount(_results.length),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Semantics(
            label: loc.searchSortLabel,
            child: DropdownButton<_DiarySearchSort>(
              key: const Key('search-sort-dropdown'),
              value: _sort,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: _DiarySearchSort.relevance,
                  child: Text(loc.searchSortRelevance),
                ),
                DropdownMenuItem(
                  value: _DiarySearchSort.newest,
                  child: Text(loc.searchSortNewest),
                ),
                DropdownMenuItem(
                  value: _DiarySearchSort.oldest,
                  child: Text(loc.searchSortOldest),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _sort = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations loc) {
    if (_isSearching && !_hasSearched) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return _SearchMessage(
        icon: Icons.error_outline,
        title: loc.searchFailed,
        actionLabel: loc.retrySearch,
        onAction: _search,
      );
    }
    if (!_hasSearched) {
      return _SearchMessage(
        icon: Icons.manage_search,
        title: loc.searchIntroTitle,
        description: loc.searchIntroDescription,
      );
    }
    if (_results.isEmpty) {
      return _SearchMessage(
        icon: Icons.search_off,
        title: loc.searchNoResults,
        description: loc.searchNoResultsHint,
      );
    }

    return ListView.separated(
      key: const Key('search-results-list'),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      itemCount: _sortedResults.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final result = _sortedResults[index];
        return _SearchResultCard(
          key: ValueKey(result.resultKey),
          result: result,
          onTap: () => _openResult(result),
        );
      },
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: icon,
    title: title,
    description: description,
    actionLabel: actionLabel,
    onAction: onAction,
    liveRegion: true,
  );
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.onTap,
    super.key,
  });

  final DiarySearchResult result;
  final VoidCallback onTap;

  String _reason(AppLocalizations loc) => switch (result.reason) {
    DiarySearchMatchReason.exactText => loc.searchMatchExact,
    DiarySearchMatchReason.activityType => loc.searchMatchActivityType,
    DiarySearchMatchReason.relatedExpression => loc.searchMatchRelated,
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final activity = result.activity;
    final title = activity?.type ?? result.diary.title;
    final excerpt = activity == null
        ? (result.diary.content.trim().isNotEmpty
              ? result.diary.content.trim()
              : result.diary.summary.trim())
        : activity.details.trim();
    final typeLabel = activity == null
        ? loc.searchMemoResult
        : loc.searchActivityResult;

    final timeLabel = _formatResultTime(context, result);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '$typeLabel, $title, $timeLabel, ${_reason(loc)}, '
          '${loc.searchReadOnly}',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: AppInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      activity == null ? Icons.notes : Icons.event_note,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      typeLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (excerpt.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _reason(loc),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultDetail extends StatelessWidget {
  const _SearchResultDetail({required this.result});

  final DiarySearchResult result;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final diary = result.diary;
    final activity = result.activity;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.searchResultDetail,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(loc.searchReadOnly),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formatResultTime(context, result),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              activity?.type ?? diary.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (activity != null) ...[
              if (activity.details.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(activity.details.trim()),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                diary.title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              if (diary.summary.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  loc.summaryLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(diary.summary.trim()),
              ],
              if (diary.content.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  loc.contentLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(diary.content.trim()),
              ],
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('search-result-edit-button'),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.edit_outlined),
              label: Text(loc.edit),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatResultTime(BuildContext context, DiarySearchResult result) {
  final materialLoc = MaterialLocalizations.of(context);
  final date = materialLoc.formatShortDate(result.occurredAt);
  final activity = result.activity;
  if (activity != null && !activity.hasExactTime) {
    return '$date · ${AppLocalizations.of(context)!.eventTimeUnknown}';
  }
  final time = materialLoc.formatTimeOfDay(
    TimeOfDay.fromDateTime(result.occurredAt),
  );
  return '$date · $time';
}
