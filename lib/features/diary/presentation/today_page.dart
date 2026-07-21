import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/diary_entity.dart';
import '../../../models/record_draft_entity.dart';
import '../../../repositories/record_draft_repository.dart';
import '../application/diary_list_notifier.dart';
import '../../drafts/presentation/draft_resume_card.dart';
import '../application/diary_draft_payload.dart';

class TodayPage extends ConsumerWidget {
  final void Function(DiaryEntity?, String?) onNavigateToForm;

  const TodayPage({super.key, required this.onNavigateToForm});

  String _draftDescription(BuildContext context, RecordDraftEntity draft) {
    var label = AppLocalizations.of(context)!.newDiary;
    try {
      final payload = DiaryDraftPayload.decode(draft.fieldPayloadJson);
      final candidate = [payload.title, payload.summary, payload.rawText]
          .map((value) => value.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (candidate.isNotEmpty) label = candidate.split('\n').first;
    } on FormatException {
      // 손상된 초안
    }
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(draft.lastSavedAt));
    return '$label · $time';
  }

  void _openDraft(BuildContext context, RecordDraftEntity draft, List<DiaryEntity> diaries) {
    DiaryEntity? diary;
    if (draft.targetRecordId != null) {
      for (final candidate in diaries) {
        if (candidate.recordId == draft.targetRecordId ||
            'local:${candidate.id}' == draft.targetRecordId) {
          diary = candidate;
          break;
        }
      }
      if (diary == null) return;
    }
    onNavigateToForm(diary, draft.draftId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaries = ref.watch(diaryListProvider);
    final drafts = ref.watch(recordDraftListProvider);
    final loc = AppLocalizations.of(context)!;

    final now = DateTime.now();
    DiaryEntity? todayDiary;
    for (final diary in diaries) {
      if (diary.date.year == now.year &&
          diary.date.month == now.month &&
          diary.date.day == now.day) {
        todayDiary = diary;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (drafts.isNotEmpty)
          DraftResumeCard(
            count: drafts.length,
            description: _draftDescription(context, drafts.first),
            onContinue: () => _openDraft(context, drafts.first, diaries),
            onStartNew: () => onNavigateToForm(null, null),
          ),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            loc.todayStatusTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        
        if (todayDiary != null && todayDiary.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              color: Colors.teal.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.teal.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.teal.shade700),
                        const SizedBox(width: 8),
                        Text(
                          loc.todayTab,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      todayDiary.summary,
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            loc.todayTimelineTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        Expanded(
          child: _buildTimeline(context, todayDiary),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context, DiaryEntity? todayDiary) {
    if (todayDiary == null || (todayDiary.activities.isEmpty && todayDiary.content.isEmpty)) {
      final loc = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              loc.noDiaryTitle,
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // 간단한 타임라인 뷰
    final items = <Widget>[];
    
    // 원본 내용(메모)이 있으면 맨 위에 표시
    if (todayDiary.content.isNotEmpty) {
      items.add(
        _TimelineItem(
          timeLabel: MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(todayDiary.date)),
          title: todayDiary.title.isNotEmpty ? todayDiary.title : AppLocalizations.of(context)!.searchMemoResult,
          content: todayDiary.content,
          icon: Icons.notes,
        )
      );
    }

    // 활동 내역들
    final sortedActivities = todayDiary.activities.toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    for (final activity in sortedActivities) {
      items.add(
        _TimelineItem(
          timeLabel: MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(activity.time)),
          title: activity.type,
          content: activity.details,
          icon: Icons.check_circle_outline,
        )
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80), // 하단 FAB를 위한 여백
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String timeLabel;
  final String title;
  final String content;
  final IconData icon;

  const _TimelineItem({
    required this.timeLabel,
    required this.title,
    required this.content,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              timeLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Column(
            children: [
              Icon(icon, size: 20, color: Colors.teal.shade300),
              Container(
                width: 2,
                height: 40,
                color: Colors.grey.shade200,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
