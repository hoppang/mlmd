import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/diary_entity.dart';
import '../../../models/record_draft_entity.dart';
import '../../../repositories/diary_repository.dart';
import '../../../repositories/record_draft_repository.dart';
import '../../../transfer/canonical_transfer_document.dart';
import '../../../transfer/diary_transfer_exception.dart';
import '../../../transfer/diary_transfer_service.dart';
import '../../../utils/logger.dart';
import '../../../widgets/import_preview_dialog.dart';
import '../../../widgets/transfer_progress_dialog.dart';
import '../../drafts/presentation/draft_resume_card.dart';
import '../../search/presentation/diary_search_page.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../application/diary_draft_payload.dart';
import '../application/diary_list_notifier.dart';
import 'diary_form_page.dart';

class DiaryDemoPage extends ConsumerStatefulWidget {
  const DiaryDemoPage({super.key});

  @override
  ConsumerState<DiaryDemoPage> createState() => _DiaryDemoPageState();
}

class _DiaryDemoPageState extends ConsumerState<DiaryDemoPage> {
  int _selectedTab = 0;

  void _navigateToFormPage(
    BuildContext context, [
    DiaryEntity? diary,
    String? draftId,
  ]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryFormPage(diary: diary, draftId: draftId),
      ),
    );
  }

  void _openDraft(
    BuildContext context,
    RecordDraftEntity draft,
    List<DiaryEntity> diaries,
  ) {
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
    _navigateToFormPage(context, diary, draft.draftId);
  }

  DiaryTransferService get _transferService =>
      DiaryTransferService(repository: ref.read(diaryRepositoryProvider));

  String _draftDescription(BuildContext context, RecordDraftEntity draft) {
    var label = AppLocalizations.of(context)!.newDiary;
    try {
      final payload = DiaryDraftPayload.decode(draft.fieldPayloadJson);
      final candidate = [payload.title, payload.summary, payload.rawText]
          .map((value) => value.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (candidate.isNotEmpty) label = candidate.split('\n').first;
    } on FormatException {
      // 손상된 초안도 목록 자체는 숨기지 않는다.
    }
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(draft.lastSavedAt));
    return '$label · $time';
  }

  Future<void> _exportDiaries() async {
    final loc = AppLocalizations.of(context)!;
    final count = ref.read(diaryListProvider).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.exportWarningTitle),
        content: Text(loc.exportWarning(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.exportDiary),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    var progressShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransferProgressDialog(message: loc.exporting),
    );
    try {
      await Future<void>.delayed(Duration.zero);
      final result = await _transferService.exportToPlatform(
        dialogTitle: loc.exportDiary,
        shareSubject: loc.exportDiary,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressShown = false;
      if (!result.cancelled) {
        await _showTransferMessage(
          context,
          loc.exportDiary,
          loc.exportSuccess(
            result.diaryCount,
            result.schemaVersion,
            result.fileName,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _logTransferError('export', error);
      await _showTransferMessage(context, loc.exportDiary, loc.transferError);
    }
  }

  Future<void> _importDiaries() async {
    final loc = AppLocalizations.of(context)!;
    var progressShown = false;
    try {
      final service = _transferService;
      final prepared = await service.pickAndPrepareImport(
        dialogTitle: loc.importDiary,
      );
      if (prepared == null || !mounted) return;
      final policy = await showDialog<ImportConflictPolicy>(
        context: context,
        builder: (_) => ImportPreviewDialog(
          prepared: prepared,
          previewFor: (policy) => service.preview(prepared, policy),
        ),
      );
      if (policy == null || !mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TransferProgressDialog(message: loc.importing),
      );
      progressShown = true;
      await Future<void>.delayed(Duration.zero);
      final result = service.apply(prepared, policy);
      ref.read(diaryListProvider.notifier).reload();
      final embeddingFailed = await ref
          .read(diaryListProvider.notifier)
          .regenerateEmbeddings(result.affectedRecordIds);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressShown = false;
      final message = StringBuffer(
        loc.importResult(result.inserted, result.updated, result.skipped),
      );
      if (embeddingFailed > 0) {
        message
          ..writeln()
          ..write(loc.embeddingFailed(embeddingFailed));
      }
      await _showTransferMessage(context, loc.importDiary, message.toString());
    } catch (error) {
      if (!mounted) return;
      if (progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _logTransferError('import', error);
      await _showTransferMessage(context, loc.importDiary, loc.transferError);
    }
  }

  Future<void> _showTransferMessage(
    BuildContext context,
    String title,
    String message,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.close),
        ),
      ],
    ),
  );

  void _logTransferError(String stage, Object error) {
    final code = error is DiaryTransferException
        ? error.code
        : error.runtimeType.toString();
    logger.e('[transfer] $stage failed ($code)');
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          SettingsDialog(onExport: _exportDiaries, onImport: _importDiaries),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    RecordDraftEntity? latestCreateDraft;
    for (final draft in drafts) {
      if (draft.draftKind == 'createRecord' && draft.recordType == 'diary') {
        latestCreateDraft = draft;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTab == 0 ? loc.appTitle : loc.searchTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal.shade700,
        elevation: 4,
        centerTitle: true,
        actions: [
          if (_selectedTab == 0)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () => _showSettingsDialog(context),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          Column(
            children: [
              if (drafts.isNotEmpty)
                DraftResumeCard(
                  count: drafts.length,
                  description: _draftDescription(context, drafts.first),
                  onContinue: () => _openDraft(context, drafts.first, diaries),
                  onStartNew: () => _navigateToFormPage(context),
                ),
              Expanded(
                child: diaries.isEmpty
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
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: diaries.length,
                        itemBuilder: (context, index) {
                          final diary = diaries[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () =>
                                    _navigateToFormPage(context, diary),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                        _buildEventChips(diary),
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
          DiarySearchPage(
            onEditDiary: (diary) => _navigateToFormPage(context, diary),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: loc.todayTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: loc.searchTab,
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                if (todayDiary != null) {
                  _navigateToFormPage(context, todayDiary);
                } else if (latestCreateDraft != null) {
                  _openDraft(context, latestCreateDraft, diaries);
                } else {
                  _navigateToFormPage(context);
                }
              },
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
              icon: Icon(todayDiary != null ? Icons.edit : Icons.add),
              label: Text(todayDiary != null ? loc.edit : loc.newDiary),
            )
          : null,
    );
  }

  /// 일기 카드에 이벤트 칩을 표시합니다.
  Widget _buildEventChips(DiaryEntity diary) {
    return Wrap(
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

/// 일기 작성 및 수정을 위한 페이지
