import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/presentation/adaptive_detail.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/activity_entity.dart';
import '../../../models/diary_entity.dart';
import '../../attachments/application/attachment_service.dart';
import '../../attachments/domain/event_attachment.dart';
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
import '../../events/domain/bath_record.dart';
import '../../events/domain/elimination_record.dart';
import '../../events/domain/intake_record.dart';
import '../../events/presentation/elimination_event_form.dart';
import '../../events/presentation/intake_event_form.dart';
import '../../events/presentation/record_entry_sheet.dart';
import '../../medical_briefing/presentation/medical_briefing_page.dart';
import '../../growth/presentation/growth_chart_page.dart';
import '../../tracking/application/tracking_preferences_notifier.dart';
import '../../tracking/domain/tracking_models.dart';
import '../../../repositories/tracking_repository.dart';
import '../../duplicate_review/presentation/duplicate_review_page.dart';
import '../../quick_launch/application/quick_launch_notifier.dart';
import '../../quick_launch/domain/quick_launch_models.dart';
import '../../quick_launch/presentation/quick_launch_editor_sheet.dart';
import '../../quick_launch/presentation/quick_launch_labels.dart'
    show quickLaunchCatalogItem;
import '../../quick_launch/presentation/quick_launch_recommendation_sheet.dart';
import '../application/diary_list_notifier.dart';
import '../application/top_undo_notifier.dart';
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
  int? _busyQuickLaunchSlot;
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

  Future<DiaryTransferService> _transferServiceWithAttachments() async {
    final fileStore = await ref.read(attachmentFileStoreProvider.future);
    return DiaryTransferService(
      repository: ref.read(diaryRepositoryProvider),
      attachmentManager: AttachmentManager(
        repository: ref.read(attachmentRepositoryProvider),
        fileStore: fileStore,
      ),
    );
  }

  Future<void> _exportDiaries(AttachmentExportMode mode) async {
    final loc = AppLocalizations.of(context)!;
    late final PreparedDiaryExport prepared;
    try {
      prepared = await (await _transferServiceWithAttachments()).prepareExport(
        mode: mode,
      );
    } catch (error) {
      _logTransferError('prepare export', error);
      if (mounted) {
        await _showTransferMessage(context, loc.exportDiary, loc.transferError);
      }
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.exportWarningTitle),
        content: Text(
          loc.exportBackupPreview(
            prepared.diaryCount,
            prepared.attachmentCount,
            _formatBytes(prepared.estimatedBytes),
            prepared.missingAttachmentCount,
          ),
        ),
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
      final result = await (await _transferServiceWithAttachments())
          .exportToPlatform(
            prepared: prepared,
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
      final service = await _transferServiceWithAttachments();
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kibibytes = bytes / 1024;
    if (kibibytes < 1024) return '${kibibytes.toStringAsFixed(1)} KB';
    return '${(kibibytes / 1024).toStringAsFixed(1)} MB';
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

  void _showGrowthChartPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GrowthChartPage(diaries: ref.read(diaryListProvider)),
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

  Future<void> _showRecordEntry({
    EventCatalogItem? initialItem,
    String? initialStructuredDataJson,
    ActivityEntity? editActivity,
    Widget? editContext,
  }) async {
    final diaries = ref.read(diaryListProvider);
    // Lightweight widget hosts may intentionally omit ObjectBox. The
    // production bootstrap always supplies it; default modes keep previews
    // and isolated tests usable without weakening persisted app behavior.
    Map<String, TrackingMode> trackingModes;
    try {
      trackingModes = ref.read(trackingPreferencesProvider);
    } catch (_) {
      trackingModes = const {};
    }
    final modesByEvent = {
      for (final id in EventTypeId.values)
        id: trackingModes[id.name] ?? TrackingMode.detailed,
    };
    final hiddenQuickIds = {
      for (final entry in modesByEvent.entries)
        if (entry.value == TrackingMode.hidden) entry.key,
    };
    var openDetailedRecord = false;
    var editQuickLaunch = false;
    final result = await showAdaptiveDetail<RecordEntryResult>(
      context: context,
      builder: (sheetContext) => RecordEntrySheet(
        recentPresets: buildRecentEventPresets(
          diaries,
          excludedIds: hiddenQuickIds,
        ),
        hiddenQuickEventIds: hiddenQuickIds,
        trackingModes: modesByEvent,
        initialItem: initialItem,
        initialStructuredDataJson: initialStructuredDataJson,
        editActivity: editActivity,
        editContext: editContext,
        onEditQuickLaunch: () {
          editQuickLaunch = true;
          Navigator.pop(sheetContext);
        },
        onSaveDailyCheckIn: (eventType, relativeState, memo) async {
          ref
              .read(trackingRepositoryProvider)
              .saveCoverage(
                childId: defaultTrackingChildId,
                localDate: DateTime.now(),
                eventCategory: eventType.name,
                coverage: TrackingCoverage.mostlyComplete,
                relativeState: relativeState,
                memo: memo,
              );
        },
        onSave: (type, details, occurredAt, structuredDataJson) async {
          return ref
              .read(diaryListProvider.notifier)
              .addActivityRecord(
                type: type,
                details: details,
                occurredAt: occurredAt,
                structuredDataJson: structuredDataJson,
              );
        },
        onUpdate:
            (
              recordId,
              details,
              structuredDataJson, {
              DateTime? occurredAt,
              String? type,
            }) => ref
                .read(diaryListProvider.notifier)
                .updateActivityDetails(
                  recordId: recordId,
                  details: details,
                  structuredDataJson: structuredDataJson,
                  occurredAt: occurredAt,
                  type: type,
                ),
        onDelete: (recordId) =>
            ref.read(diaryListProvider.notifier).deleteActivityRecord(recordId),
        onSaveCustom: (customEventTypeId, nameSnapshot, memo, occurredAt) => ref
            .read(diaryListProvider.notifier)
            .addCustomEventRecord(
              customEventTypeId: customEventTypeId,
              nameSnapshot: nameSnapshot,
              memo: memo,
              occurredAt: occurredAt,
            ),
        onStartSleep: (type, startedAt) async {
          final result = await ref
              .read(diaryListProvider.notifier)
              .startSleep(type: type, startedAt: startedAt);
          return result;
        },
        onOpenDetailedRecord: () {
          openDetailedRecord = true;
          Navigator.pop(sheetContext);
        },
      ),
    );
    if (!mounted) return;
    if (editQuickLaunch) {
      await _showQuickLaunchEditor();
      return;
    }
    if (openDetailedRecord) {
      _navigateToFormPage(context);
      return;
    }
    if (result == null) return;
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    switch (result.kind) {
      case RecordEntryResultKind.saved:
        if (editActivity != null) {
          messenger.showSnackBar(SnackBar(content: Text(loc.diaryUpdated)));
          break;
        }
        final recordId = result.recordId;
        if (recordId != null) {
          ref
              .read(topUndoProvider.notifier)
              .arm(
                () => ref
                    .read(diaryListProvider.notifier)
                    .deleteActivityRecord(recordId),
              );
        }
        messenger.showSnackBar(
          SnackBar(content: Text(loc.quickRecordSaved(result.savedName!))),
        );
      case RecordEntryResultKind.sleepAlreadyActive:
        messenger.showSnackBar(SnackBar(content: Text(loc.sleepAlreadyActive)));
      case RecordEntryResultKind.sleepStarted:
        final recordId = result.recordId;
        if (recordId != null) {
          ref
              .read(topUndoProvider.notifier)
              .arm(
                () => ref
                    .read(diaryListProvider.notifier)
                    .deleteActivityRecord(recordId),
              );
        }
        messenger.showSnackBar(SnackBar(content: Text(loc.sleepStarted)));
    }
  }

  void _editActivity(
    DiaryEntity _,
    ActivityEntity activity,
    Widget? editContext,
  ) {
    final item = eventCatalogItemForActivity(activity);
    _showRecordEntry(
      initialItem: item,
      initialStructuredDataJson: activity.structuredDataJson,
      editActivity: activity,
      editContext: editContext,
    );
  }

  Future<void> _showQuickLaunchEditor([int initialSlotIndex = 0]) {
    return showAdaptiveDetail<void>(
      context: context,
      builder: (_) =>
          QuickLaunchEditorSheet(initialSlotIndex: initialSlotIndex),
    );
  }

  Future<void> _reviewQuickLaunchRecommendation() async {
    final milestone = await showAdaptiveDetail<GrowthMilestone>(
      context: context,
      builder: (_) => const QuickLaunchRecommendationSheet(),
    );
    if (milestone == null || !mounted) return;
    final loc = AppLocalizations.of(context)!;
    ref.read(topUndoProvider.notifier).arm(() async {
      final restored = await ref
          .read(quickLaunchProvider.notifier)
          .undoRecommendation(milestone);
      if (!mounted || !restored) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.quickLaunchRecommendationUndone)),
      );
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(loc.quickLaunchRecommendationApplied)),
      );
  }

  Future<void> _runQuickLaunch(QuickLaunchSlot slot) async {
    final target = slot.eventTypeId;
    if (target == null || _busyQuickLaunchSlot != null) return;
    if (slot.executionMode == QuickLaunchExecutionMode.prefilledForm) {
      await _showRecordEntry(
        initialItem: quickLaunchCatalogItem(target),
        initialStructuredDataJson: slot.structuredPresetJson,
      );
      return;
    }

    setState(() => _busyQuickLaunchSlot = slot.slotIndex);
    final loc = AppLocalizations.of(context)!;
    final item = quickLaunchCatalogItem(target);
    final now = DateTime.now();
    String? recordId;
    try {
      switch (target) {
        case QuickLaunchEventTarget.feeding:
          final preset =
              IntakeRecord.decode(slot.structuredPresetJson ?? '') ??
              const IntakeRecord(
                kind: IntakeRecordKind.feeding,
                method: FeedingMethod.timeOnly,
              );
          final encoded = preset.encode();
          recordId = await ref
              .read(diaryListProvider.notifier)
              .addActivityRecord(
                type: item.label(loc),
                details: intakeRecordDetails(preset, loc),
                occurredAt: now,
                structuredDataJson: encoded,
              );
        case QuickLaunchEventTarget.diaper:
          final kind = _quickLaunchEliminationKind(slot.structuredPresetJson);
          final record = EliminationRecord(kind: kind, occurredAt: now);
          final encoded = record.encode();
          recordId = await ref
              .read(diaryListProvider.notifier)
              .addActivityRecord(
                type: item.label(loc),
                details: eliminationRecordDetails(loc, record),
                occurredAt: now,
                structuredDataJson: encoded,
              );
        case QuickLaunchEventTarget.sleep:
          final result = await ref
              .read(diaryListProvider.notifier)
              .startSleep(type: item.label(loc), startedAt: now);
          if (!result.created) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(loc.sleepAlreadyActive)));
            }
            return;
          }
          recordId = result.activity.recordId;
        case QuickLaunchEventTarget.bath:
          final record = BathRecord(occurredAt: now);
          final encoded = record.encode();
          recordId = await ref
              .read(diaryListProvider.notifier)
              .addActivityRecord(
                type: item.label(loc),
                details: record.buildDetails(loc),
                occurredAt: now,
                structuredDataJson: encoded,
              );
        default:
          await _showRecordEntry(
            initialItem: item,
            initialStructuredDataJson: slot.structuredPresetJson,
          );
          return;
      }
      if (mounted && recordId != null) {
        final savedRecordId = recordId;
        ref
            .read(topUndoProvider.notifier)
            .arm(
              () => ref
                  .read(diaryListProvider.notifier)
                  .deleteActivityRecord(savedRecordId),
            );
      }
    } finally {
      if (mounted) setState(() => _busyQuickLaunchSlot = null);
    }
  }

  EliminationKind _quickLaunchEliminationKind(String? source) {
    try {
      final value = jsonDecode(source ?? '');
      final kind = value is Map ? value['kind'] : null;
      return switch (kind) {
        'stool' => EliminationKind.stool,
        'both' => EliminationKind.both,
        _ => EliminationKind.urine,
      };
    } on FormatException {
      return EliminationKind.urine;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final topUndo = ref.watch(topUndoProvider);

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
              title: _selectedTab == 0
                  ? null
                  : Text(_selectedTab == 1 ? loc.dateTab : loc.searchTitle),
              actions: [
                if (topUndo != null)
                  IconButton(
                    key: const Key('top-undo-button'),
                    icon: const Icon(Icons.undo),
                    tooltip: loc.undo,
                    onPressed: () =>
                        ref.read(topUndoProvider.notifier).execute(),
                  ),
                if (_selectedTab == 0) ...[
                  IconButton(
                    key: const Key('growth-chart-button'),
                    icon: const Icon(Icons.show_chart),
                    tooltip: loc.growthChartTitle,
                    onPressed: () => _showGrowthChartPage(context),
                  ),
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
            body: IndexedStack(
              index: _selectedTab,
              children: [
                TodayPage(
                  onNavigateToForm: (diary, draftId) =>
                      _navigateToFormPage(context, diary, draftId),
                  onEditActivity: _editActivity,
                  onOpenDuplicateReviews: () =>
                      _showDuplicateReviewPage(context),
                  onQuickLaunch: _runQuickLaunch,
                  onEditQuickLaunch: _showQuickLaunchEditor,
                  onOpenAllRecords: () => _showRecordEntry(),
                  onReviewQuickLaunchRecommendation:
                      _reviewQuickLaunchRecommendation,
                  busyQuickLaunchSlot: _busyQuickLaunchSlot,
                ),
                DiaryListPage(
                  onEditDiary: (diary) => _navigateToFormPage(context, diary),
                ),
                DiarySearchPage(
                  onEditDiary: (diary) => _navigateToFormPage(context, diary),
                  onEditActivity: _editActivity,
                  focusRequest: _searchFocusRequest,
                ),
              ],
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
          ),
        ),
      ),
    );
  }
}

/// 일기 작성 및 수정을 위한 페이지
