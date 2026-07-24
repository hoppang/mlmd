import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/layout/adaptive_content_frame.dart';
import '../../../core/presentation/app_empty_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/diary_entity.dart';
import '../../../repositories/profile_repository.dart';
import '../../diary/application/diary_list_notifier.dart';
import '../../events/domain/event_catalog.dart';
import '../../profiles/presentation/record_author_tag.dart';
import '../domain/medical_briefing_snapshot.dart';

enum _BriefingRangePreset { today, last7Days, last30Days, custom }

class MedicalBriefingPage extends ConsumerStatefulWidget {
  const MedicalBriefingPage({required this.onOpenOriginal, super.key});

  final ValueChanged<DiaryEntity> onOpenOriginal;

  @override
  ConsumerState<MedicalBriefingPage> createState() =>
      _MedicalBriefingPageState();
}

class _MedicalBriefingPageState extends ConsumerState<MedicalBriefingPage> {
  _BriefingRangePreset _preset = _BriefingRangePreset.last7Days;
  late DateTime _start = _initialStart();
  late DateTime _endExclusive = _today().add(const Duration(days: 1));

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _initialStart() => _today().subtract(const Duration(days: 6));

  void _applyPreset(_BriefingRangePreset preset) {
    final today = _today();
    final start = switch (preset) {
      _BriefingRangePreset.today => today,
      _BriefingRangePreset.last7Days => today.subtract(const Duration(days: 6)),
      _BriefingRangePreset.last30Days => today.subtract(
        const Duration(days: 29),
      ),
      _BriefingRangePreset.custom => _start,
    };
    setState(() {
      _preset = preset;
      _start = start;
      _endExclusive = today.add(const Duration(days: 1));
    });
  }

  Future<void> _pickRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _start,
        end: _endExclusive.subtract(const Duration(days: 1)),
      ),
    );
    if (result == null) return;
    setState(() {
      _preset = _BriefingRangePreset.custom;
      _start = DateUtils.dateOnly(result.start);
      _endExclusive = DateUtils.dateOnly(
        result.end,
      ).add(const Duration(days: 1));
    });
  }

  Future<void> _copy(MedicalBriefingSnapshot snapshot) async {
    await Clipboard.setData(
      ClipboardData(text: _briefingText(context, snapshot)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.briefingCopied)),
      );
  }

  Future<void> _share(MedicalBriefingSnapshot snapshot) async {
    final loc = AppLocalizations.of(context)!;
    await SharePlus.instance.share(
      ShareParams(
        text: _briefingText(context, snapshot),
        subject: loc.medicalBriefingTitle,
      ),
    );
  }

  String _briefingText(BuildContext context, MedicalBriefingSnapshot snapshot) {
    final loc = AppLocalizations.of(context)!;
    final materialLoc = MaterialLocalizations.of(context);
    final buffer = StringBuffer()
      ..writeln(loc.medicalBriefingTitle)
      ..writeln(
        loc.briefingDateRange(
          materialLoc.formatShortDate(snapshot.start),
          materialLoc.formatShortDate(
            snapshot.endExclusive.subtract(const Duration(days: 1)),
          ),
        ),
      )
      ..writeln(loc.briefingFactCount(snapshot.facts.length))
      ..writeln();
    for (final fact in snapshot.facts) {
      final date = materialLoc.formatShortDate(fact.occurredAt);
      final time = fact.hasExactTime
          ? materialLoc.formatTimeOfDay(TimeOfDay.fromDateTime(fact.occurredAt))
          : loc.eventTimeUnknown;
      buffer.write('$date $time · ${fact.storedType}');
      if (fact.details.trim().isNotEmpty) {
        buffer.write(' · ${fact.details.trim()}');
      }
      buffer.writeln();
    }
    buffer
      ..writeln()
      ..write(loc.briefingSafetyNotice);
    return buffer.toString();
  }

  Future<void> _openFact(
    MedicalBriefingFact fact,
    List<DiaryEntity> diaries,
    bool showAuthorTag,
  ) async {
    final matches = diaries.where((diary) => diary.id == fact.diaryId);
    final diary = matches.isEmpty ? null : matches.first;
    final open = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final loc = AppLocalizations.of(context)!;
        final materialLoc = MaterialLocalizations.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: AppInsets.dialog,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fact.storedType,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Chip(label: Text(loc.searchReadOnly)),
                  ],
                ),
                Text(
                  '${materialLoc.formatShortDate(fact.occurredAt)} · '
                  '${fact.hasExactTime ? materialLoc.formatTimeOfDay(TimeOfDay.fromDateTime(fact.occurredAt)) : loc.eventTimeUnknown}',
                ),
                if (showAuthorTag) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RecordAuthorTag(
                      authorProfileId: fact.authorProfileId,
                      visible: true,
                    ),
                  ),
                ],
                if (fact.details.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  SelectableText(fact.details.trim()),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  loc.briefingSafetyNotice,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: const Key('briefing-open-original'),
                  onPressed: diary == null
                      ? null
                      : () => Navigator.pop(context, true),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(loc.briefingOpenOriginal),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (open == true && diary != null && mounted) {
      widget.onOpenOriginal(diary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diaries = ref.watch(diaryListProvider);
    final snapshot = const MedicalBriefingSnapshotBuilder().build(
      diaries,
      start: _start,
      endExclusive: _endExclusive,
    );
    final loc = AppLocalizations.of(context)!;
    final materialLoc = MaterialLocalizations.of(context);
    final showAuthorTags = shouldShowAuthorTags(
      diaries,
      ref.watch(profileRepositoryProvider),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.medicalBriefingTitle),
        actions: [
          IconButton(
            key: const Key('briefing-copy-button'),
            onPressed: snapshot.facts.isEmpty ? null : () => _copy(snapshot),
            tooltip: loc.briefingCopy,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            key: const Key('briefing-share-button'),
            onPressed: snapshot.facts.isEmpty ? null : () => _share(snapshot),
            tooltip: loc.briefingShare,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: AdaptiveContentFrame(
        child: ListView(
          padding: AppInsets.page,
          children: [
            Text(
              loc.medicalBriefingDescription,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              loc.briefingSafetyNotice,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<_BriefingRangePreset>(
              key: const Key('briefing-range-preset'),
              initialValue: _preset,
              decoration: InputDecoration(labelText: loc.briefingPeriod),
              items: [
                DropdownMenuItem(
                  value: _BriefingRangePreset.today,
                  child: Text(loc.searchToday),
                ),
                DropdownMenuItem(
                  value: _BriefingRangePreset.last7Days,
                  child: Text(loc.searchLast7Days),
                ),
                DropdownMenuItem(
                  value: _BriefingRangePreset.last30Days,
                  child: Text(loc.searchLast30Days),
                ),
                DropdownMenuItem(
                  value: _BriefingRangePreset.custom,
                  child: Text(loc.searchCustomDate),
                ),
              ],
              onChanged: (value) {
                if (value == _BriefingRangePreset.custom) {
                  _pickRange();
                } else if (value != null) {
                  _applyPreset(value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: const Key('briefing-custom-range'),
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                loc.briefingDateRange(
                  materialLoc.formatShortDate(_start),
                  materialLoc.formatShortDate(
                    _endExclusive.subtract(const Duration(days: 1)),
                  ),
                ),
              ),
            ),
            if (snapshot.countsByKind.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final entry in snapshot.countsByKind.entries)
                    if (entry.value > 0)
                      Chip(
                        label: Text(
                          '${_kindLabel(entry.key, loc)} · ${entry.value}',
                        ),
                      ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (snapshot.facts.isEmpty)
              SizedBox(
                height: 260,
                child: AppEmptyState(
                  icon: Icons.medical_information_outlined,
                  title: loc.briefingNoFacts,
                  description: loc.briefingNoFactsHint,
                ),
              )
            else ...[
              Text(
                loc.briefingFactCount(snapshot.facts.length),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final fact in snapshot.facts.reversed)
                Card(
                  child: ListTile(
                    leading: Icon(_kindIcon(fact.kind)),
                    title: Text(fact.storedType),
                    subtitle: Text(
                      [
                        '${materialLoc.formatShortDate(fact.occurredAt)} · '
                            '${fact.hasExactTime ? materialLoc.formatTimeOfDay(TimeOfDay.fromDateTime(fact.occurredAt)) : loc.eventTimeUnknown}',
                        if (fact.details.trim().isNotEmpty) fact.details.trim(),
                      ].join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openFact(fact, diaries, showAuthorTags),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

EventTypeId _eventTypeForKind(MedicalFactKind kind) => switch (kind) {
  MedicalFactKind.temperature => EventTypeId.temperature,
  MedicalFactKind.medication => EventTypeId.medication,
  MedicalFactKind.symptom => EventTypeId.symptom,
  MedicalFactKind.hospital => EventTypeId.hospital,
  MedicalFactKind.vaccination => EventTypeId.vaccination,
  MedicalFactKind.accidentInjury => EventTypeId.accidentInjury,
};

String _kindLabel(MedicalFactKind kind, AppLocalizations loc) =>
    eventCatalogItem(_eventTypeForKind(kind)).label(loc);

IconData _kindIcon(MedicalFactKind kind) =>
    eventCatalogItem(_eventTypeForKind(kind)).icon;
