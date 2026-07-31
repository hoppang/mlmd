import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/symptom_record.dart';

class PredefinedSymptom {
  const PredefinedSymptom({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultKind,
  });

  final String id;
  final String name;
  final String category;
  final SymptomKind defaultKind;
}

const predefinedSymptoms = <PredefinedSymptom>[
  PredefinedSymptom(
    id: 'cough',
    name: '기침',
    category: '호흡기',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'runnyNose',
    name: '콧물',
    category: '호흡기',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'nasalCongestion',
    name: '코막힘',
    category: '호흡기',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'phlegm',
    name: '가래',
    category: '호흡기',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'vomiting',
    name: '구토',
    category: '소화기',
    defaultKind: SymptomKind.episodic,
  ),
  PredefinedSymptom(
    id: 'stomachAche',
    name: '복통',
    category: '소화기',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'lossOfAppetite',
    name: '식욕 저하',
    category: '소화기',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'rash',
    name: '발진',
    category: '피부',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'swelling',
    name: '붓기',
    category: '피부',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'itching',
    name: '가려움',
    category: '피부',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'lethargy',
    name: '처짐',
    category: '전반적 상태',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'fussiness',
    name: '보챔',
    category: '전반적 상태',
    defaultKind: SymptomKind.continuous,
  ),
  PredefinedSymptom(
    id: 'pain',
    name: '통증',
    category: '전반적 상태',
    defaultKind: SymptomKind.continuous,
  ),
];

enum SymptomOnsetOption { now, today, yesterday, custom }

class SymptomFormResult {
  const SymptomFormResult({
    required this.symptomName,
    required this.details,
    required this.record,
  });

  final String symptomName;
  final String details;
  final SymptomRecord record;
}

class SymptomEventForm extends StatefulWidget {
  const SymptomEventForm({
    required this.occurredAt,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onChangeTime,
    required this.onSave,
    this.activeEpisodes = const [],
    this.initialRecord,
    super.key,
  });

  final DateTime occurredAt;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onChangeTime;
  final ValueChanged<SymptomFormResult> onSave;
  final List<SymptomRecord> activeEpisodes;
  final SymptomRecord? initialRecord;

  @override
  State<SymptomEventForm> createState() => _SymptomEventFormState();
}

class _SymptomEventFormState extends State<SymptomEventForm> {
  PredefinedSymptom? _selectedPreset;
  late final TextEditingController _customNameController;
  late final TextEditingController _noteController;

  bool _isCustom = false;
  SymptomKind _customKind = SymptomKind.episodic;

  SymptomOnsetOption _onset = SymptomOnsetOption.today;
  SymptomSeverity? _severity;

  SymptomTrend? _selectedTrend;
  bool _isResolving = false;

  SymptomAmount? _amount;
  SymptomContext? _context;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecord;
    _customNameController = TextEditingController(
      text: _initialSymptomName(initial),
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
    if (initial != null) {
      _selectedPreset = predefinedSymptoms
          .where((preset) => preset.id == initial.symptomId)
          .firstOrNull;
      _isCustom = _selectedPreset == null;
      _customKind = initial.kind;
      _onset = initial.onsetPrecision == SymptomOnsetPrecision.dateOnly
          ? SymptomOnsetOption.custom
          : SymptomOnsetOption.today;
      _severity = initial.severity;
      _selectedTrend = initial.trend;
      _isResolving = initial.status == SymptomEpisodeStatus.resolved;
      _amount = initial.amount;
      _context = initial.context;
    }
    _customNameController.addListener(_onCustomNameChanged);
  }

  @override
  void dispose() {
    _customNameController.removeListener(_onCustomNameChanged);
    _customNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onCustomNameChanged() {
    final text = _customNameController.text.trim();
    if (text.isNotEmpty && !_isCustom) {
      setState(() {
        _isCustom = true;
        _selectedPreset = null;
      });
    } else if (text.isEmpty && _isCustom) {
      setState(() {
        _isCustom = false;
      });
    }
  }

  void _selectPreset(PredefinedSymptom preset) {
    setState(() {
      _selectedPreset = preset;
      _isCustom = false;
      _customNameController.clear();
      _selectedTrend = null;
      _isResolving = false;
      _severity = null;
      _amount = null;
      _context = null;
    });
  }

  SymptomRecord? _findActiveEpisode() {
    final symptomId = _isCustom
        ? 'custom:${_customNameController.text.trim()}'
        : _selectedPreset?.id;
    final symptomName = _isCustom
        ? _customNameController.text.trim()
        : _selectedPreset?.name;
    if (symptomId == null || symptomName == null) return null;

    for (final ep in widget.activeEpisodes) {
      if (ep.status == SymptomEpisodeStatus.active &&
          (ep.symptomId == symptomId || ep.symptomName == symptomName)) {
        return ep;
      }
    }
    return null;
  }

  void _submit() {
    final loc = AppLocalizations.of(context)!;
    final symptomName = _isCustom
        ? _customNameController.text.trim()
        : _selectedPreset?.name ?? '';
    final symptomId = _isCustom
        ? 'custom:$symptomName'
        : _selectedPreset?.id ?? 'custom';

    if (symptomName.isEmpty) return;

    final kind = _isCustom
        ? _customKind
        : (_selectedPreset?.defaultKind ?? SymptomKind.continuous);
    final activeEp = kind == SymptomKind.continuous
        ? _findActiveEpisode()
        : null;
    final initial = widget.initialRecord;
    final resolvedOnsetPrecision = _onset == SymptomOnsetOption.custom
        ? SymptomOnsetPrecision.dateOnly
        : (initial?.onsetPrecision ?? SymptomOnsetPrecision.exactTime);

    SymptomRecord record;
    if (kind == SymptomKind.continuous) {
      if (activeEp != null) {
        record = SymptomRecord(
          symptomId: symptomId,
          symptomName: symptomName,
          kind: SymptomKind.continuous,
          occurredAt: widget.occurredAt,
          episodeId: initial?.episodeId ?? activeEp.episodeId,
          status: _isResolving
              ? SymptomEpisodeStatus.resolved
              : SymptomEpisodeStatus.active,
          trend: _isResolving ? null : _selectedTrend,
          resolvedAt: _isResolving
              ? initial?.resolvedAt ?? widget.occurredAt
              : null,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      } else {
        record = SymptomRecord(
          symptomId: symptomId,
          symptomName: symptomName,
          kind: SymptomKind.continuous,
          occurredAt: widget.occurredAt,
          episodeId:
              initial?.episodeId ??
              'ep-${(widget.initialRecord?.occurredAt ?? widget.occurredAt).millisecondsSinceEpoch}',
          status: _isResolving
              ? SymptomEpisodeStatus.resolved
              : SymptomEpisodeStatus.active,
          onsetPrecision: resolvedOnsetPrecision,
          severity: _severity,
          resolvedAt: _isResolving
              ? initial?.resolvedAt ?? widget.occurredAt
              : null,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      }
    } else {
      record = SymptomRecord(
        symptomId: symptomId,
        symptomName: symptomName,
        kind: SymptomKind.episodic,
        occurredAt: widget.occurredAt,
        amount: _amount,
        context: _context,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
    }

    final details = symptomRecordDetails(loc, record);
    widget.onSave(
      SymptomFormResult(
        symptomName: symptomName,
        details: details,
        record: record,
      ),
    );
  }

  String _initialSymptomName(SymptomRecord? record) {
    if (record == null) return '';
    final preset = predefinedSymptoms
        .where((item) => item.id == record.symptomId)
        .firstOrNull;
    return preset?.name ?? record.symptomName;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentKind = _isCustom
        ? _customKind
        : (_selectedPreset?.defaultKind ?? SymptomKind.continuous);
    final activeEp = currentKind == SymptomKind.continuous
        ? _findActiveEpisode()
        : null;
    final canSave = _isCustom
        ? _customNameController.text.trim().isNotEmpty
        : _selectedPreset != null;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              Expanded(
                child: Text(
                  loc.symptomEvent,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onChangeTime,
                icon: const Icon(Icons.access_time, size: 16),
                label: Text(
                  '${widget.occurredAt.hour.toString().padLeft(2, '0')}:${widget.occurredAt.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ],
          ),

          // Preset Chips
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: [
              for (final preset in predefinedSymptoms)
                FilterChip(
                  key: Key('symptom-chip-${preset.id}'),
                  label: Text(preset.name),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selected: !_isCustom && _selectedPreset?.id == preset.id,
                  onSelected: (_) => _selectPreset(preset),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // Custom Symptom Entry
          TextField(
            key: const Key('custom-symptom-input'),
            controller: _customNameController,
            decoration: const InputDecoration(
              hintText: '기타 직접 입력 (예: 어지러움)',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
            ),
          ),
          if (_isCustom) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                ChoiceChip(
                  key: const Key('custom-episodic-btn'),
                  label: const Text('발생형 (1회)'),
                  visualDensity: VisualDensity.compact,
                  selected: _customKind == SymptomKind.episodic,
                  onSelected: (_) =>
                      setState(() => _customKind = SymptomKind.episodic),
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  key: const Key('custom-continuous-btn'),
                  label: const Text('지속형 (계속됨)'),
                  visualDensity: VisualDensity.compact,
                  selected: _customKind == SymptomKind.continuous,
                  onSelected: (_) =>
                      setState(() => _customKind = SymptomKind.continuous),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.xs),

          // Options for Continuous Symptom
          if (currentKind == SymptomKind.continuous &&
              (_selectedPreset != null || _isCustom)) ...[
            if (activeEp != null) ...[
              Text(
                '진행 중인 에피소드 상태 변화',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Wrap(
                spacing: AppSpacing.xxs,
                children: [
                  ChoiceChip(
                    key: const Key('trend-improved-chip'),
                    label: const Text('나아졌어요'),
                    visualDensity: VisualDensity.compact,
                    selected:
                        !_isResolving &&
                        _selectedTrend == SymptomTrend.improved,
                    onSelected: (_) => setState(() {
                      _selectedTrend = SymptomTrend.improved;
                      _isResolving = false;
                    }),
                  ),
                  ChoiceChip(
                    key: const Key('trend-same-chip'),
                    label: const Text('비슷해요'),
                    visualDensity: VisualDensity.compact,
                    selected:
                        !_isResolving && _selectedTrend == SymptomTrend.same,
                    onSelected: (_) => setState(() {
                      _selectedTrend = SymptomTrend.same;
                      _isResolving = false;
                    }),
                  ),
                  ChoiceChip(
                    key: const Key('trend-worsened-chip'),
                    label: const Text('심해졌어요'),
                    visualDensity: VisualDensity.compact,
                    selected:
                        !_isResolving &&
                        _selectedTrend == SymptomTrend.worsened,
                    onSelected: (_) => setState(() {
                      _selectedTrend = SymptomTrend.worsened;
                      _isResolving = false;
                    }),
                  ),
                  ChoiceChip(
                    key: const Key('trend-resolved-chip'),
                    label: const Text('끝났어요'),
                    visualDensity: VisualDensity.compact,
                    selected: _isResolving,
                    onSelected: (_) => setState(() {
                      _isResolving = true;
                      _selectedTrend = null;
                    }),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '발견 시점',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Wrap(
                          spacing: AppSpacing.xxs,
                          children: [
                            ChoiceChip(
                              key: const Key('onset-now-chip'),
                              label: const Text('지금 발견'),
                              visualDensity: VisualDensity.compact,
                              selected: _onset == SymptomOnsetOption.now,
                              onSelected: (_) => setState(
                                () => _onset = SymptomOnsetOption.now,
                              ),
                            ),
                            ChoiceChip(
                              key: const Key('onset-today-chip'),
                              label: const Text('오늘부터'),
                              visualDensity: VisualDensity.compact,
                              selected: _onset == SymptomOnsetOption.today,
                              onSelected: (_) => setState(
                                () => _onset = SymptomOnsetOption.today,
                              ),
                            ),
                            ChoiceChip(
                              key: const Key('onset-yesterday-chip'),
                              label: const Text('어제부터'),
                              visualDensity: VisualDensity.compact,
                              selected: _onset == SymptomOnsetOption.yesterday,
                              onSelected: (_) => setState(
                                () => _onset = SymptomOnsetOption.yesterday,
                              ),
                            ),
                            ChoiceChip(
                              key: const Key('onset-custom-chip'),
                              label: const Text('날짜 선택'),
                              visualDensity: VisualDensity.compact,
                              selected: _onset == SymptomOnsetOption.custom,
                              onSelected: (_) => setState(
                                () => _onset = SymptomOnsetOption.custom,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '정도',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Wrap(
                spacing: AppSpacing.xxs,
                children: [
                  ChoiceChip(
                    key: const Key('severity-mild-chip'),
                    label: const Text('약함'),
                    visualDensity: VisualDensity.compact,
                    selected: _severity == SymptomSeverity.mild,
                    onSelected: (_) =>
                        setState(() => _severity = SymptomSeverity.mild),
                  ),
                  ChoiceChip(
                    key: const Key('severity-moderate-chip'),
                    label: const Text('보통'),
                    visualDensity: VisualDensity.compact,
                    selected: _severity == SymptomSeverity.moderate,
                    onSelected: (_) =>
                        setState(() => _severity = SymptomSeverity.moderate),
                  ),
                  ChoiceChip(
                    key: const Key('severity-severe-chip'),
                    label: const Text('심함'),
                    visualDensity: VisualDensity.compact,
                    selected: _severity == SymptomSeverity.severe,
                    onSelected: (_) =>
                        setState(() => _severity = SymptomSeverity.severe),
                  ),
                ],
              ),
            ],
          ],

          // Options for Episodic Symptom
          if (currentKind == SymptomKind.episodic &&
              (_selectedPreset != null || _isCustom)) ...[
            Text(
              '양 (선택)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xxs,
              children: [
                ChoiceChip(
                  key: const Key('amount-mild-chip'),
                  label: const Text('조금'),
                  visualDensity: VisualDensity.compact,
                  selected: _amount == SymptomAmount.mild,
                  onSelected: (_) =>
                      setState(() => _amount = SymptomAmount.mild),
                ),
                ChoiceChip(
                  key: const Key('amount-moderate-chip'),
                  label: const Text('보통'),
                  visualDensity: VisualDensity.compact,
                  selected: _amount == SymptomAmount.moderate,
                  onSelected: (_) =>
                      setState(() => _amount = SymptomAmount.moderate),
                ),
                ChoiceChip(
                  key: const Key('amount-severe-chip'),
                  label: const Text('많이'),
                  visualDensity: VisualDensity.compact,
                  selected: _amount == SymptomAmount.severe,
                  onSelected: (_) =>
                      setState(() => _amount = SymptomAmount.severe),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '상황 (선택)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xxs,
              children: [
                ChoiceChip(
                  key: const Key('context-after-feeding-chip'),
                  label: const Text('수유 후'),
                  visualDensity: VisualDensity.compact,
                  selected: _context == SymptomContext.afterFeeding,
                  onSelected: (_) =>
                      setState(() => _context = SymptomContext.afterFeeding),
                ),
                ChoiceChip(
                  key: const Key('context-after-meal-chip'),
                  label: const Text('식사 후'),
                  visualDensity: VisualDensity.compact,
                  selected: _context == SymptomContext.afterMeal,
                  onSelected: (_) =>
                      setState(() => _context = SymptomContext.afterMeal),
                ),
                ChoiceChip(
                  key: const Key('context-after-cough-chip'),
                  label: const Text('기침 후'),
                  visualDensity: VisualDensity.compact,
                  selected: _context == SymptomContext.afterCough,
                  onSelected: (_) =>
                      setState(() => _context = SymptomContext.afterCough),
                ),
                ChoiceChip(
                  key: const Key('context-unknown-chip'),
                  label: const Text('모름'),
                  visualDensity: VisualDensity.compact,
                  selected: _context == SymptomContext.unknown,
                  onSelected: (_) =>
                      setState(() => _context = SymptomContext.unknown),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.xs),

          // Note Input
          TextField(
            key: const Key('symptom-note-input'),
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: '메모 (선택)',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Save Button
          ElevatedButton(
            key: const Key('save-symptom-btn'),
            onPressed: canSave && !widget.saving ? _submit : null,
            child: widget.saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(loc.saveRecord),
          ),
        ],
      ),
    );
  }
}
