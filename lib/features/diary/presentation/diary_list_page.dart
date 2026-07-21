import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/diary_entity.dart';
import '../application/diary_list_notifier.dart';

class DiaryListPage extends ConsumerWidget {
  final void Function(DiaryEntity) onEditDiary;

  const DiaryListPage({super.key, required this.onEditDiary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaries = ref.watch(diaryListProvider);
    final loc = AppLocalizations.of(context)!;

    if (diaries.isEmpty) {
      return Center(
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
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: diaries.length,
      itemBuilder: (context, index) {
        final diary = diaries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onEditDiary(diary),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            MaterialLocalizations.of(context)
                                .formatShortDate(diary.date),
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
                      diary.summary.isNotEmpty ? diary.summary : diary.content,
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
                            side: BorderSide(color: Colors.teal.shade100),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 0),
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
    );
  }
}
