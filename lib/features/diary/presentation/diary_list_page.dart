import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/presentation/app_empty_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/diary_entity.dart';
import '../application/diary_list_notifier.dart';

class DiaryListPage extends ConsumerStatefulWidget {
  final void Function(DiaryEntity) onEditDiary;

  const DiaryListPage({super.key, required this.onEditDiary});

  @override
  ConsumerState<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends ConsumerState<DiaryListPage> {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  void _changeDay(int delta) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(
        _selectedDate.add(Duration(days: delta)),
      );
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDate = DateUtils.dateOnly(picked);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final diaries = ref.watch(diaryListProvider);
    final loc = AppLocalizations.of(context)!;
    final selectedDiaries =
        diaries.where((diary) => _isSameDay(diary.date, _selectedDate)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return AdaptiveContentFrame(
      child: Column(
        children: [
          Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('date-previous-button'),
                    onPressed: () => _changeDay(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).previousPageTooltip,
                  ),
                  Expanded(
                    child: InkWell(
                      key: const Key('date-picker-button'),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      onTap: _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              MaterialLocalizations.of(
                                context,
                              ).formatFullDate(_selectedDate),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('date-next-button'),
                    onPressed: () => _changeDay(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: selectedDiaries.isEmpty
                ? AppEmptyState(
                    icon: Icons.book_outlined,
                    title: loc.noDiaryTitle,
                    description: loc.noDiaryDesc,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    itemCount: selectedDiaries.length,
                    itemBuilder: (context, index) {
                      final diary = selectedDiaries[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Card(
                          child: InkWell(
                            onTap: () => widget.onEditDiary(diary),
                            child: Padding(
                              padding: AppInsets.card,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          diary.title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.xs,
                                          vertical: AppSpacing.xxs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.control,
                                          ),
                                        ),
                                        child: Text(
                                          MaterialLocalizations.of(
                                            context,
                                          ).formatShortDate(diary.date),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    diary.summary.isNotEmpty
                                        ? diary.summary
                                        : diary.content,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (diary.activities.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xxs,
                                      children: diary.activities.map((a) {
                                        return Chip(
                                          label: Text(
                                            '${a.type} ${a.details}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xxs,
                                            vertical: 0,
                                          ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
