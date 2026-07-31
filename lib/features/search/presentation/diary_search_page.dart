import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/presentation/app_empty_state.dart';
import '../../../core/presentation/adaptive_detail.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/activity_entity.dart';
import '../../../models/diary_entity.dart';
import '../../../models/author_profile_entity.dart';
import '../../../repositories/diary_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../../utils/logger.dart';
import '../../diary/application/diary_list_notifier.dart';
import '../../events/domain/medical_guidance.dart';
import '../../events/presentation/medical_guidance_widgets.dart';
import '../../profiles/presentation/record_author_tag.dart';
import '../domain/hybrid_search_query.dart';

enum _DiarySearchSort { relevance, newest, oldest }

class DiarySearchPage extends ConsumerStatefulWidget {
  const DiarySearchPage({
    required this.onEditDiary,
    required this.onEditActivity,
    this.focusRequest,
    super.key,
  });

  final ValueChanged<DiaryEntity> onEditDiary;
  final void Function(
    DiaryEntity diary,
    ActivityEntity activity,
    Widget? editContext,
  )
  onEditActivity;
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
  HybridSearchQuery _criteria = const HybridSearchQuery();
  SearchDatePreset _datePreset = SearchDatePreset.all;

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
    final profiles = ref.read(profileRepositoryProvider).getAuthorProfiles();
    final interpreted = const HybridSearchQueryParser().parse(
      _queryController.text,
      authorNicknames: profiles.map((profile) => profile.nickname).toList(),
      authorProfileIdsByNickname: {
        for (final profile in profiles)
          profile.nickname: profile.authorProfileId,
      },
    );
    final parsed = interpreted.query;
    final query = HybridSearchQuery(
      text: parsed.text,
      from: parsed.from ?? _criteria.from,
      untilExclusive: parsed.untilExclusive ?? _criteria.untilExclusive,
      eventKind: parsed.eventKind ?? _criteria.eventKind,
      authorProfileId: parsed.authorProfileId ?? _criteria.authorProfileId,
      temperature: parsed.temperature ?? _criteria.temperature,
    );
    if (!query.hasCriteria || _isSearching) return;

    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
      _hasError = false;
      _criteria = query;
      if (interpreted.datePreset != SearchDatePreset.all) {
        _datePreset = interpreted.datePreset;
      }
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

  Future<void> _openFilters() async {
    final profiles = ref.read(profileRepositoryProvider).getAuthorProfiles();
    final result =
        await showAdaptiveDetail<
          ({HybridSearchQuery query, SearchDatePreset preset})
        >(
          context: context,
          builder: (context) => _SearchFilterSheet(
            initialQuery: _criteria,
            initialPreset: _datePreset,
            profiles: profiles,
          ),
        );
    if (result == null || !mounted) return;
    setState(() {
      _criteria = result.query.copyWith(text: _criteria.text);
      _datePreset = result.preset;
    });
  }

  void _clearCriteria() {
    setState(() {
      _criteria = HybridSearchQuery(text: _queryController.text.trim());
      _datePreset = SearchDatePreset.all;
    });
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

  void _openResult(DiarySearchResult result) {
    final activity = result.activity;
    if (activity == null) {
      widget.onEditDiary(result.diary);
      return;
    }
    widget.onEditActivity(
      result.diary,
      activity,
      _buildEditContext(result, ref.read(diaryListProvider)),
    );
  }

  Widget? _buildEditContext(
    DiarySearchResult result,
    List<DiaryEntity> allDiaries,
  ) {
    final activity = result.activity;
    if (activity == null) return null;
    final guidance = evaluateMedicalGuidance(activity);
    final surrounding = <({DateTime occurredAt, String label})>[];
    for (final candidate in allDiaries) {
      if (!_isSameDate(candidate.date, result.occurredAt)) continue;
      if (candidate.id != result.diary.id &&
          candidate.title.trim().isNotEmpty) {
        surrounding.add((
          occurredAt: candidate.date,
          label: candidate.title.trim(),
        ));
      }
      for (final item in candidate.activities) {
        if (item.id == activity.id) continue;
        surrounding.add((
          occurredAt: item.time,
          label: item.details.trim().isEmpty
              ? item.type
              : '${item.type} · ${item.details.trim()}',
        ));
      }
    }
    surrounding.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    if (!guidance.requiresAttention && surrounding.isEmpty) return null;
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: ExpansionTile(
        key: const Key('record-edit-search-context'),
        initiallyExpanded: false,
        leading: Icon(
          guidance.requiresAttention
              ? Icons.health_and_safety_outlined
              : Icons.history_outlined,
        ),
        title: Text(
          guidance.requiresAttention
              ? loc.medicalAttentionRequired
              : loc.searchSameDayContext,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          if (guidance.requiresAttention)
            MedicalGuidanceSection(activity: activity),
          if (guidance.requiresAttention && surrounding.isNotEmpty)
            const SizedBox(height: AppSpacing.md),
          if (surrounding.isNotEmpty) ...[
            if (guidance.requiresAttention) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.searchSameDayContext,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            for (final item in surrounding.take(5))
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(item.occurredAt))} · ${item.label}',
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                loc.searchSameDayContextHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final diaries = ref.watch(diaryListProvider);
    final showAuthorTags = shouldShowAuthorTags(
      diaries,
      ref.watch(profileRepositoryProvider),
    );
    final searchNotifier = ref.read(diaryListProvider.notifier);

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
                const SizedBox(width: AppSpacing.xs),
                IconButton.filledTonal(
                  key: const Key('search-filter-button'),
                  onPressed: _isSearching ? null : _openFilters,
                  tooltip: loc.searchFilters,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            if (_criteria.from != null ||
                _criteria.untilExclusive != null ||
                _criteria.eventKind != null ||
                _criteria.authorProfileId != null ||
                _criteria.temperature != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _buildCriteriaChips(loc),
            ],
            if (!searchNotifier.isSemanticSearchAvailable ||
                searchNotifier.hasPendingSearchEmbeddings)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  loc.searchSemanticUnavailable,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (_results.isNotEmpty && !_hasError) _buildResultHeader(loc),
            Expanded(child: _buildBody(loc, showAuthorTags)),
          ],
        ),
      ),
    );
  }

  Widget _buildCriteriaChips(AppLocalizations loc) {
    final profiles = ref.read(profileRepositoryProvider).getAuthorProfiles();
    final author = profiles
        .where(
          (profile) => profile.authorProfileId == _criteria.authorProfileId,
        )
        .firstOrNull;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        if (_criteria.from != null || _criteria.untilExclusive != null)
          InputChip(
            key: const Key('search-date-chip'),
            label: Text(_datePresetLabel(loc, _datePreset)),
            onDeleted: () => setState(() {
              _criteria = _criteria.copyWith(from: null, untilExclusive: null);
              _datePreset = SearchDatePreset.all;
            }),
          ),
        if (_criteria.eventKind != null)
          InputChip(
            key: const Key('search-event-chip'),
            label: Text(_eventLabel(loc, _criteria.eventKind!)),
            onDeleted: () =>
                setState(() => _criteria = _criteria.copyWith(eventKind: null)),
          ),
        if (author != null)
          InputChip(
            key: const Key('search-author-chip'),
            label: Text('${loc.searchAuthor}: ${author.nickname}'),
            onDeleted: () => setState(
              () => _criteria = _criteria.copyWith(authorProfileId: null),
            ),
          ),
        if (_criteria.temperature case final temperature?)
          InputChip(
            key: const Key('search-temperature-chip'),
            label: Text(
              loc.searchTemperatureAtLeast(
                temperature.value.toStringAsFixed(
                  temperature.value.truncateToDouble() == temperature.value
                      ? 0
                      : 1,
                ),
              ),
            ),
            onDeleted: () => setState(
              () => _criteria = _criteria.copyWith(temperature: null),
            ),
          ),
        TextButton(
          key: const Key('search-clear-filters'),
          onPressed: _clearCriteria,
          child: Text(loc.searchClearFilters),
        ),
      ],
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

  Widget _buildBody(AppLocalizations loc, bool showAuthorTags) {
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
          showAuthorTag: showAuthorTags,
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
    required this.showAuthorTag,
    required this.onTap,
    super.key,
  });

  final DiarySearchResult result;
  final bool showAuthorTag;
  final VoidCallback onTap;

  String _reason(AppLocalizations loc) => switch (result.reason) {
    DiarySearchMatchReason.exactText => loc.searchMatchExact,
    DiarySearchMatchReason.activityType => loc.searchMatchActivityType,
    DiarySearchMatchReason.relatedExpression => loc.searchMatchRelated,
    DiarySearchMatchReason.structuredTemperature => loc.searchMatchTemperature,
    DiarySearchMatchReason.structuredAuthor => loc.searchMatchAuthor,
    DiarySearchMatchReason.structuredEvent => loc.searchMatchEvent,
    DiarySearchMatchReason.dateRange => loc.searchMatchDate,
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final activity = result.activity;
    final guidance = evaluateMedicalGuidance(activity);
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
          '${loc.edit}',
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
                if (showAuthorTag) ...[
                  const SizedBox(height: AppSpacing.xs),
                  RecordAuthorTag(
                    authorProfileId:
                        activity?.createdByAuthorProfileId ??
                        result.diary.createdByAuthorProfileId,
                    visible: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _reason(loc),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (guidance.requiresAttention) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const MedicalAttentionLabel(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

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

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({
    required this.initialQuery,
    required this.initialPreset,
    required this.profiles,
  });

  final HybridSearchQuery initialQuery;
  final SearchDatePreset initialPreset;
  final List<AuthorProfileEntity> profiles;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late SearchDatePreset _preset = widget.initialPreset;
  late SearchEventKind? _eventKind = widget.initialQuery.eventKind;
  late String? _authorProfileId = widget.initialQuery.authorProfileId;
  late final TextEditingController _temperatureController =
      TextEditingController(
        text: widget.initialQuery.temperature?.value.toString() ?? '',
      );

  @override
  void dispose() {
    _temperatureController.dispose();
    super.dispose();
  }

  void _apply() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final (from, until) = switch (_preset) {
      SearchDatePreset.today => (today, today.add(const Duration(days: 1))),
      SearchDatePreset.last7Days => (
        today.subtract(const Duration(days: 6)),
        today.add(const Duration(days: 1)),
      ),
      SearchDatePreset.last30Days => (
        today.subtract(const Duration(days: 29)),
        today.add(const Duration(days: 1)),
      ),
      _ => (null, null),
    };
    final temperature = double.tryParse(_temperatureController.text.trim());
    Navigator.pop(context, (
      query: HybridSearchQuery(
        text: widget.initialQuery.text,
        from: from,
        untilExclusive: until,
        eventKind: _eventKind,
        authorProfileId: _authorProfileId,
        temperature: temperature == null
            ? null
            : TemperatureFilter(
                value: temperature,
                comparison: NumericComparison.atLeast,
              ),
      ),
      preset: _preset,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.searchFilters,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<SearchDatePreset>(
              key: const Key('search-date-filter'),
              initialValue: _preset,
              decoration: InputDecoration(labelText: loc.searchDate),
              items: SearchDatePreset.values
                  .where((preset) => preset != SearchDatePreset.custom)
                  .map(
                    (preset) => DropdownMenuItem(
                      value: preset,
                      child: Text(_datePresetLabel(loc, preset)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _preset = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<SearchEventKind?>(
              key: const Key('search-event-filter'),
              initialValue: _eventKind,
              decoration: InputDecoration(labelText: loc.searchEventType),
              items: [
                DropdownMenuItem(value: null, child: Text(loc.searchAll)),
                ...SearchEventKind.values.map(
                  (kind) => DropdownMenuItem(
                    value: kind,
                    child: Text(_eventLabel(loc, kind)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _eventKind = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              key: const Key('search-author-filter'),
              initialValue: _authorProfileId,
              decoration: InputDecoration(labelText: loc.searchAuthor),
              items: [
                DropdownMenuItem(value: null, child: Text(loc.searchAll)),
                ...widget.profiles.map(
                  (profile) => DropdownMenuItem(
                    value: profile.authorProfileId,
                    child: Text(profile.nickname),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _authorProfileId = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('search-temperature-filter'),
              controller: _temperatureController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: loc.searchTemperature,
                suffixText: '°C+',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('search-apply-filters'),
              onPressed: _apply,
              child: Text(loc.searchApplyFilters),
            ),
          ],
        ),
      ),
    );
  }
}

String _datePresetLabel(AppLocalizations loc, SearchDatePreset preset) =>
    switch (preset) {
      SearchDatePreset.all => loc.searchAllDates,
      SearchDatePreset.today => loc.searchToday,
      SearchDatePreset.last7Days => loc.searchLast7Days,
      SearchDatePreset.last30Days => loc.searchLast30Days,
      SearchDatePreset.custom => loc.searchCustomDate,
    };

String _eventLabel(AppLocalizations loc, SearchEventKind kind) =>
    switch (kind) {
      SearchEventKind.temperature => loc.searchEventTemperature,
      SearchEventKind.medication => loc.searchEventMedication,
      SearchEventKind.feeding => loc.searchEventFeeding,
      SearchEventKind.diaper => loc.searchEventDiaper,
      SearchEventKind.sleep => loc.searchEventSleep,
      SearchEventKind.hospital => loc.searchEventHospital,
    };
