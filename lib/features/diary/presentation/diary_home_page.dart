import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/adaptive_detail.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/diary_entity.dart';
import '../../../repositories/diary_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../../transfer/canonical_transfer_document.dart';
import '../../../transfer/diary_transfer_exception.dart';
import '../../../transfer/diary_transfer_service.dart';
import '../../../utils/logger.dart';
import '../../../widgets/import_preview_dialog.dart';
import '../../../widgets/transfer_progress_dialog.dart';
import '../../search/presentation/diary_search_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../events/domain/event_catalog.dart';
import '../../events/presentation/record_entry_sheet.dart';
import '../../medical_briefing/presentation/medical_briefing_page.dart';
import '../../duplicate_review/presentation/duplicate_review_page.dart';
import '../application/diary_list_notifier.dart';
import 'diary_form_page.dart';
import 'diary_list_page.dart';
import 'today_page.dart';

class DiaryDemoPage extends ConsumerStatefulWidget {
  const DiaryDemoPage({super.key});

  @override
  ConsumerState<DiaryDemoPage> createState() => _DiaryDemoPageState();
}

class _DiaryDemoPageState extends ConsumerState<DiaryDemoPage> {
  int _selectedTab = 0;
  final ValueNotifier<int> _searchFocusRequest = ValueNotifier(0);

  @override
  void dispose() {
    _searchFocusRequest.dispose();
    super.dispose();
  }

  void _focusSearch() {
    setState(() => _selectedTab = 2);
    _searchFocusRequest.value++;
  }

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

  DiaryTransferService get _transferService =>
      DiaryTransferService(repository: ref.read(diaryRepositoryProvider));

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
      final result = await service.applyWithAutomaticBackup(prepared, policy);
      ref.read(authorProfileListProvider.notifier).reload();
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

  void _showSettingsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          onExport: _exportDiaries,
          onImport: _importDiaries,
          backupOverview: () {
            final diaries = ref.read(diaryListProvider);
            return BackupOverview(
              diaryCount: diaries.length,
              activityCount: diaries.fold(
                0,
                (count, diary) => count + diary.activities.length,
              ),
              estimatedBackupBytes: _transferService.buildExportBytes().length,
            );
          },
        ),
      ),
    );
  }

  void _showMedicalBriefingPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicalBriefingPage(
          onOpenOriginal: (diary) => _navigateToFormPage(context, diary),
        ),
      ),
    );
  }

  void _showDuplicateReviewPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DuplicateReviewPage(
          onOpenOriginal: (diary) => _navigateToFormPage(context, diary),
        ),
      ),
    );
  }

  Future<void> _showRecordEntry() async {
    final diaries = ref.read(diaryListProvider);
    var openDetailedRecord = false;
    final savedType = await showAdaptiveDetail<String>(
      context: context,
      builder: (sheetContext) => RecordEntrySheet(
        recentPresets: buildRecentEventPresets(diaries),
        onSave: (type, details, occurredAt, structuredDataJson) => ref
            .read(diaryListProvider.notifier)
            .addActivityRecord(
              type: type,
              details: details,
              occurredAt: occurredAt,
              structuredDataJson: structuredDataJson,
            ),
        onSaveCustom: (customEventTypeId, nameSnapshot, memo, occurredAt) => ref
            .read(diaryListProvider.notifier)
            .addCustomEventRecord(
              customEventTypeId: customEventTypeId,
              nameSnapshot: nameSnapshot,
              memo: memo,
              occurredAt: occurredAt,
            ),
        onOpenDetailedRecord: () {
          openDetailedRecord = true;
          Navigator.pop(sheetContext);
        },
      ),
    );
    if (!mounted) return;
    if (openDetailedRecord) {
      _navigateToFormPage(context);
      return;
    }
    if (savedType != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.quickRecordSaved(savedType),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
      },
      child: Focus(
        autofocus: true,
        debugLabel: 'home shortcuts',
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                _selectedTab == 0
                    ? loc.appTitle
                    : (_selectedTab == 1 ? loc.dateTab : loc.searchTitle),
              ),
              actions: [
                if (_selectedTab == 0) ...[
                  IconButton(
                    key: const Key('medical-briefing-button'),
                    icon: const Icon(Icons.medical_information_outlined),
                    tooltip: loc.medicalBriefingTitle,
                    onPressed: () => _showMedicalBriefingPage(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: loc.settingsTitle,
                    onPressed: () => _showSettingsPage(context),
                  ),
                ],
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.only(
                bottom: AppSizes.recordEntryClearance,
              ),
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  TodayPage(
                    onNavigateToForm: (diary, draftId) =>
                        _navigateToFormPage(context, diary, draftId),
                    onOpenDuplicateReviews: () =>
                        _showDuplicateReviewPage(context),
                  ),
                  DiaryListPage(
                    onEditDiary: (diary) => _navigateToFormPage(context, diary),
                  ),
                  DiarySearchPage(
                    onEditDiary: (diary) => _navigateToFormPage(context, diary),
                    focusRequest: _searchFocusRequest,
                  ),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedTab,
              onDestinationSelected: (index) =>
                  setState(() => _selectedTab = index),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.today_outlined),
                  selectedIcon: const Icon(Icons.today),
                  label: loc.todayTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_month_outlined),
                  selectedIcon: const Icon(Icons.calendar_month),
                  label: loc.dateTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.search_outlined),
                  selectedIcon: const Icon(Icons.search),
                  label: loc.searchTab,
                ),
              ],
            ),
            floatingActionButton: SizedBox(
              width: 168,
              height: 56,
              child: FloatingActionButton.extended(
                key: const Key('record-entry-button'),
                onPressed: _showRecordEntry,
                icon: const Icon(Icons.add),
                label: Text(loc.recordAction),
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          ),
        ),
      ),
    );
  }
}

/// 일기 작성 및 수정을 위한 페이지
