import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatFullDate(_selectedDate),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 64,
                        color: Colors.teal.shade200,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.noDiaryTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.noDiaryDesc,
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: selectedDiaries.length,
                  itemBuilder: (context, index) {
                    final diary = selectedDiaries[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => widget.onEditDiary(diary),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
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
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        MaterialLocalizations.of(
                                          context,
                                        ).formatShortDate(diary.date),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.teal.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  diary.summary.isNotEmpty
                                      ? diary.summary
                                      : diary.content,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (diary.activities.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: diary.activities.map((a) {
                                      return Chip(
                                        label: Text(
                                          '${a.type} ${a.details}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        backgroundColor: Colors.teal.shade50,
                                        side: BorderSide(
                                          color: Colors.teal.shade100,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
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
    );
  }
}
