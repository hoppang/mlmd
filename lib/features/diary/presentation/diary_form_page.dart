import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/diary_entity.dart';
import '../../../repositories/record_draft_repository.dart';
import '../../../services/llm_diary_service.dart';
import '../../../services/llm_title_service.dart';
import '../../drafts/application/draft_autosave_controller.dart';
import '../../drafts/application/active_draft_registry.dart';
import '../application/diary_draft_payload.dart';
import '../application/diary_list_notifier.dart';

class DiaryFormPage extends ConsumerStatefulWidget {
  final DiaryEntity? diary;
  final String? draftId;

  const DiaryFormPage({super.key, this.diary, this.draftId});

  @override
  ConsumerState<DiaryFormPage> createState() => _DiaryFormPageState();
}

// ---------------------------------------------------------------------------
// 입력 모드
// ---------------------------------------------------------------------------
enum _InputMode { simple, manual }

// ---------------------------------------------------------------------------
// 이벤트 항목 (UI용 가변 모델)
// ---------------------------------------------------------------------------
class _EditableActivity {
  final TextEditingController typeController;
  final TextEditingController detailController;
  DateTime? occurredAt;

  _EditableActivity({
    required String type,
    required String detail,
    this.occurredAt,
  }) : typeController = TextEditingController(text: type),
       detailController = TextEditingController(text: detail);

  String get type => typeController.text.trim();
  String get detail => detailController.text.trim();

  void dispose() {
    typeController.dispose();
    detailController.dispose();
  }
}

class _DiaryFormPageState extends ConsumerState<DiaryFormPage>
    with WidgetsBindingObserver {
  // 공통
  late final TextEditingController _titleController;

  // 간단 입력 모드
  late final TextEditingController _rawController;
  bool _isAnalyzing = false;

  // 직접 입력 모드
  late final TextEditingController _summaryController;
  final List<_EditableActivity> _activities = [];
  late DateTime _occurredAt;

  _InputMode _mode = _InputMode.simple;
  late final DiaryDraftPayload _baselinePayload;
  late final DraftAutosaveController _draftController;
  late final bool _sourceChangedSinceDraft;
  DraftSaveStatus _draftStatus = DraftSaveStatus.idle;
  bool _isDisposing = false;
  bool _allowPop = false;
  bool _handlingPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final d = widget.diary;
    final defaultOccurredAt = d?.date ?? DateTime.now();
    _baselinePayload = DiaryDraftPayload(
      inputMode: d == null ? 'simple' : 'manual',
      title: d?.title ?? '',
      rawText: d?.content ?? '',
      summary: d?.summary ?? '',
      occurredAt: defaultOccurredAt,
      activities:
          d?.activities
              .map(
                (activity) => DiaryDraftActivity(
                  type: activity.type,
                  detail: activity.details,
                  occurredAt: activity.hasExactTime ? activity.time : null,
                ),
              )
              .toList(growable: false) ??
          const [],
    );

    final repository = ref.read(recordDraftRepositoryProvider);
    final targetRecordId = d == null ? null : (d.recordId ?? 'local:${d.id}');
    final existingDraft = widget.draftId != null
        ? repository.getByDraftId(widget.draftId!)
        : targetRecordId == null
        ? null
        : repository.getEditDraft(targetRecordId);
    _sourceChangedSinceDraft =
        d != null &&
        existingDraft?.baseLastModified != null &&
        !existingDraft!.baseLastModified!.isAtSameMomentAs(d.lastModified);

    var initialPayload = _baselinePayload;
    if (existingDraft != null &&
        DiaryDraftPayload.supportsSchemaVersion(
          existingDraft.payloadSchemaVersion,
        )) {
      try {
        final decodedPayload = DiaryDraftPayload.decode(
          existingDraft.fieldPayloadJson,
        );
        if (existingDraft.payloadSchemaVersion == 1) {
          initialPayload = decodedPayload.withFallbackTimes(_baselinePayload);
          if (d == null && decodedPayload.occurredAt == null) {
            initialPayload = initialPayload.withRecordTime(
              existingDraft.createdAt,
            );
          }
        } else {
          initialPayload = decodedPayload.withFallbackRecordTime(
            _baselinePayload.occurredAt,
          );
        }
      } on FormatException {
        initialPayload = _baselinePayload;
      }
    }
    _draftStatus = existingDraft == null
        ? DraftSaveStatus.idle
        : DraftSaveStatus.saved;

    _mode = initialPayload.inputMode == 'manual'
        ? _InputMode.manual
        : _InputMode.simple;
    _titleController = TextEditingController(text: initialPayload.title);
    _rawController = TextEditingController(text: initialPayload.rawText);
    _summaryController = TextEditingController(text: initialPayload.summary);
    _occurredAt = initialPayload.occurredAt ?? defaultOccurredAt;
    for (final activity in initialPayload.activities) {
      _activities.add(
        _EditableActivity(
          type: activity.type,
          detail: activity.detail,
          occurredAt: activity.occurredAt,
        ),
      );
    }

    _draftController = DraftAutosaveController(
      repository: repository,
      draftId: existingDraft?.draftId ?? widget.draftId ?? const Uuid().v4(),
      draftKind: d == null ? 'createRecord' : 'editRecord',
      recordType: 'diary',
      targetRecordId: targetRecordId,
      baseLastModified: existingDraft?.baseLastModified ?? d?.lastModified,
      payloadSchemaVersion: DiaryDraftPayload.schemaVersion,
      existingDraft: existingDraft,
      capturePayload: () => _capturePayload().encode(),
      hasMeaningfulChanges: _hasMeaningfulChanges,
      onStatusChanged: (status) {
        if (mounted && !_isDisposing) {
          setState(() => _draftStatus = status);
        }
      },
      onDraftListChanged: () {
        ref.read(recordDraftListProvider.notifier).reload();
      },
    );
    ActiveDraftRegistry.instance.register(_draftController.flush);
    _titleController.addListener(_onFieldChanged);
    _rawController.addListener(_onFieldChanged);
    _summaryController.addListener(_onFieldChanged);
    for (final activity in _activities) {
      _attachActivityListeners(activity);
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    ActiveDraftRegistry.instance.unregister(_draftController.flush);
    _draftController.dispose();
    _titleController.dispose();
    _rawController.dispose();
    _summaryController.dispose();
    for (final activity in _activities) {
      activity.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _draftController.flush();
    }
  }

  DiaryDraftPayload _capturePayload() => DiaryDraftPayload(
    inputMode: _mode.name,
    title: _titleController.text,
    rawText: _rawController.text,
    summary: _summaryController.text,
    occurredAt: _occurredAt,
    activities: _activities
        .map(
          (activity) => DiaryDraftActivity(
            type: activity.typeController.text,
            detail: activity.detailController.text,
            occurredAt: activity.occurredAt,
          ),
        )
        .toList(growable: false),
  );

  bool _hasMeaningfulChanges() {
    final current = _capturePayload();
    return widget.diary == null
        ? current.hasContent
        : !current.hasSameRecordContent(_baselinePayload);
  }

  void _onFieldChanged() => _draftController.schedule();

  void _attachActivityListeners(_EditableActivity activity) {
    activity.typeController.addListener(_onFieldChanged);
    activity.detailController.addListener(_onFieldChanged);
  }

  // ---------------------------------------------------------------------------
  // AI 분석 (간단 입력 모드)
  // ---------------------------------------------------------------------------
  Future<void> _onAnalyze() async {
    final raw = _rawController.text.trim();
    if (raw.isEmpty) return;
    _draftController.flush();
    setState(() => _isAnalyzing = true);
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final result = await LlmDiaryService().generate(
        raw,
        languageCode: locale,
      );
      if (!mounted) return;
      setState(() {
        // 봸석 결과를 상세 필드에 반영
        _titleController.text = result.title;
        _summaryController.text = result.summary;
        for (final activity in _activities) {
          activity.dispose();
        }
        _activities
          ..clear()
          ..addAll(
            result.activities.map(
              (a) => _EditableActivity(
                type: a.type,
                detail: a.detail,
                occurredAt: a.occurredAt,
              ),
            ),
          );
        for (final activity in _activities) {
          _attachActivityListeners(activity);
        }
        // 분석 완료 후 자동으로 상세 탭으로 전환
        _mode = _InputMode.manual;
      });
      _draftController.flush();
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 저장
  // ---------------------------------------------------------------------------
  Future<void> _onConfirm() async {
    final loc = AppLocalizations.of(context)!;
    _draftController.flush();

    if (_mode == _InputMode.simple && widget.diary == null) {
      final raw = _rawController.text.trim();
      if (raw.isEmpty) return;
      // 간단 입력 모드에서 확인(FAB) 클릭 시, LLM 분석 수행 후 상세 모드로 자동 전환 (저장 안 함)
      await _onAnalyze();
      return;
    }

    String title = _titleController.text.trim();
    // 상세 입력 모드
    String summary = _summaryController.text.trim();
    // 간단 입력한 원문은 만약을 위해 저장(content)만 하고, 수정 시 UI에선 숨겨짐
    String content = _rawController.text.trim().isNotEmpty
        ? _rawController.text.trim()
        : _synthesizeRaw();

    if (content.isEmpty && summary.isEmpty) return;

    // 제목 미입력 시 LLM
    if (title.isEmpty && (content.isNotEmpty || summary.isNotEmpty)) {
      final base = summary.isNotEmpty ? summary : content;
      final locale = Localizations.localeOf(context).languageCode;
      title = await LlmTitleService().generate(base, languageCode: locale);
    }

    List<ActivitySummary> activities = _activities
        .where((a) => a.type.isNotEmpty)
        .map(
          (a) => ActivitySummary(
            type: a.type,
            detail: a.detail,
            occurredAt: a.occurredAt,
          ),
        )
        .toList();

    if (!mounted) return;

    if (widget.diary != null) {
      await ref
          .read(diaryListProvider.notifier)
          .updateDiary(
            widget.diary!,
            title,
            summary,
            content,
            occurredAt: _occurredAt,
            activitySummaries: activities,
            consumedDraftId: _draftController.draftId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.diaryUpdated),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await ref
          .read(diaryListProvider.notifier)
          .addDiary(
            title,
            summary,
            content,
            occurredAt: _occurredAt,
            activitySummaries: activities,
            consumedDraftId: _draftController.draftId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.diaryAdded),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _draftController.markCommitted();
    Navigator.pop(context);
  }

  void _onDelete() {
    final loc = AppLocalizations.of(context)!;
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.deleteConfirmTitle),
        content: Text(loc.deleteConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(loc.delete),
          ),
        ],
      ),
    ).then((confirmed) {
      if (!mounted) return;
      if (confirmed == true) {
        _draftController.discard();
        ref.read(diaryListProvider.notifier).deleteDiary(widget.diary!.id);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.diaryDeleted),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 이벤트 편집 (manual)
  // ---------------------------------------------------------------------------
  void _addActivity() {
    final activity = _EditableActivity(
      type: '',
      detail: '',
      occurredAt: _occurredAt,
    );
    _attachActivityListeners(activity);
    setState(() => _activities.add(activity));
    _draftController.schedule();
  }

  void _removeActivity(int index) {
    setState(() => _activities.removeAt(index).dispose());
    _draftController.schedule();
  }

  String _formatDateTime(BuildContext context, DateTime value) {
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(value)} · '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  Future<DateTime?> _selectDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _editRecordTime() async {
    final selected = await _selectDateTime(_occurredAt);
    if (selected == null || !mounted) return;
    setState(() => _occurredAt = selected);
    _draftController.schedule();
  }

  Future<void> _editActivityTime(_EditableActivity activity) async {
    final selected = await _selectDateTime(activity.occurredAt ?? _occurredAt);
    if (selected == null || !mounted) return;
    setState(() => activity.occurredAt = selected);
    _draftController.schedule();
  }

  void _clearActivityTime(_EditableActivity activity) {
    setState(() => activity.occurredAt = null);
    _draftController.schedule();
  }

  Future<void> _confirmDiscardDraft() async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.discardDraftTitle),
        content: Text(loc.discardDraftDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.discardDraft),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _draftController.discard();
    Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.diary != null;
    final loc = AppLocalizations.of(context)!;

    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _handlingPop) return;
        if (!_draftController.flush()) return;
        _handlingPop = true;
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(result);
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEdit ? loc.editDiary : loc.newDiary,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            if (isEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _onDelete,
              ),
            if (_draftStatus != DraftSaveStatus.idle)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'discardDraft') _confirmDiscardDraft();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'discardDraft',
                    child: Text(loc.discardDraft),
                  ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            // 모드 토글 (새 일기 작성 시에만 표시)
            if (!isEdit) _buildModeToggle(loc),
            if (_draftStatus != DraftSaveStatus.idle)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    switch (_draftStatus) {
                      DraftSaveStatus.saving => loc.draftSaving,
                      DraftSaveStatus.saved => loc.draftSaved,
                      DraftSaveStatus.failed => loc.draftSaveFailed,
                      DraftSaveStatus.idle => '',
                    },
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _draftStatus == DraftSaveStatus.failed
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            if (_sourceChangedSinceDraft)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  loc.draftSourceChanged,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _mode == _InputMode.simple
                    ? _buildSimpleMode(loc)
                    : _buildManualMode(loc),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isAnalyzing ? null : _onConfirm,
          backgroundColor: Colors.teal.shade600,
          foregroundColor: Colors.white,
          icon: _isAnalyzing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  (_mode == _InputMode.simple && !isEdit)
                      ? Icons.auto_awesome
                      : Icons.check,
                ),
          label: Text(
            isEdit
                ? loc.edit
                : (_mode == _InputMode.simple
                      ? loc.analyzeButton
                      : loc.confirm),
          ),
        ),
      ),
    );
  }

  // --- 모드 토글 ---
  Widget _buildModeToggle(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<_InputMode>(
        segments: [
          ButtonSegment(
            value: _InputMode.simple,
            label: Text(loc.simpleModeLabel),
            icon: const Icon(Icons.auto_awesome, size: 16),
          ),
          ButtonSegment(
            value: _InputMode.manual,
            label: Text(loc.manualModeLabel),
            icon: const Icon(Icons.edit_note, size: 16),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (s) {
          final newMode = s.first;
          if (newMode == _InputMode.simple && _mode == _InputMode.manual) {
            // 상세 → 간단: summary + 이벤트로 간단 입력 합성
            final synthesized = _synthesizeRaw();
            if (synthesized.isNotEmpty) {
              _rawController.text = synthesized;
            }
          }
          setState(() => _mode = newMode);
          _draftController.schedule();
        },
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  /// 상세 필드(summary + 이벤트)를 합산하여 간단 입력 텍스트를 생성합니다.
  String _synthesizeRaw() {
    final parts = <String>[];
    final summary = _summaryController.text.trim();
    if (summary.isNotEmpty) parts.add(summary);
    final eventsStr = _activities
        .where((a) => a.type.isNotEmpty)
        .map((a) => a.detail.isNotEmpty ? '${a.type}: ${a.detail}' : a.type)
        .join('\n');
    if (eventsStr.isNotEmpty) parts.add(eventsStr);
    return parts.join('\n');
  }

  // ---------------------------------------------------------------------------
  // 간단 입력 모드 UI
  // ---------------------------------------------------------------------------
  Widget _buildRecordTimeField(AppLocalizations loc) {
    return Semantics(
      button: true,
      label: loc.recordTimeLabel,
      value: _formatDateTime(context, _occurredAt),
      child: InkWell(
        onTap: _editRecordTime,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: loc.recordTimeLabel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.event, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(_formatDateTime(context, _occurredAt))),
              const Icon(Icons.edit_outlined, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleMode(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _buildRecordTimeField(loc),
        const SizedBox(height: 12),
        // 제목 (AI 분석 후 수정 가능)
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: loc.titleLabel,
            hintText: loc.titleHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 간단 입력 필드
        TextField(
          controller: _rawController,
          maxLines: 10,
          autofocus: widget.diary == null,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            labelText: loc.simpleModeLabel,
            hintText: loc.contentHint,
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 80), // FAB 여백
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 직접 입력 모드 UI
  // ---------------------------------------------------------------------------
  Widget _buildManualMode(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _buildRecordTimeField(loc),
        const SizedBox(height: 12),
        // 제목
        TextField(
          controller: _titleController,
          autofocus: widget.diary == null,
          decoration: InputDecoration(
            labelText: loc.titleLabel,
            hintText: loc.titleHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 요약
        TextField(
          controller: _summaryController,
          maxLines: 4,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            labelText: loc.summaryLabel,
            hintText: loc.summaryHint,
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 이벤트 목록
        Row(
          children: [
            const Icon(Icons.event_note, size: 18, color: Colors.teal),
            const SizedBox(width: 6),
            Text(
              loc.eventTypeLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addActivity,
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc.addEventButton),
              style: TextButton.styleFrom(foregroundColor: Colors.teal),
            ),
          ],
        ),
        ..._activities.asMap().entries.map((entry) {
          final idx = entry.key;
          final act = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 종류
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: act.typeController,
                        decoration: InputDecoration(
                          hintText: loc.eventTypeHint,
                          labelText: loc.eventTypeLabel,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 상세
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: act.detailController,
                        decoration: InputDecoration(
                          hintText: loc.eventDetailHint,
                          labelText: loc.eventDetailLabel,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    // 삭제
                    IconButton(
                      tooltip: loc.delete,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _removeActivity(idx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _editActivityTime(act),
                      icon: const Icon(Icons.schedule, size: 16),
                      label: Text(
                        act.occurredAt == null
                            ? loc.eventTimeUnknown
                            : _formatDateTime(context, act.occurredAt!),
                      ),
                    ),
                    if (act.occurredAt != null)
                      IconButton(
                        tooltip: loc.clearEventTime,
                        onPressed: () => _clearActivityTime(act),
                        icon: const Icon(Icons.event_busy, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 80), // FAB 여백
      ],
    );
  }
}
