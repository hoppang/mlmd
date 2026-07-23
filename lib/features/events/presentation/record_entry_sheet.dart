import 'package:flutter/material.dart';

import '../../../core/presentation/app_section_header.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/event_catalog.dart';

typedef SaveEventRecord =
    Future<void> Function(String type, String details, DateTime occurredAt);

class RecordEntrySheet extends StatefulWidget {
  const RecordEntrySheet({
    required this.recentPresets,
    required this.onSave,
    required this.onOpenDetailedRecord,
    super.key,
  });

  final List<RecentEventPreset> recentPresets;
  final SaveEventRecord onSave;
  final VoidCallback onOpenDetailedRecord;

  @override
  State<RecordEntrySheet> createState() => _RecordEntrySheetState();
}

class _RecordEntrySheetState extends State<RecordEntrySheet> {
  final _detailsController = TextEditingController();
  EventCatalogItem? _selectedItem;
  DateTime _occurredAt = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _select(EventCatalogItem item, {String details = ''}) {
    setState(() {
      _selectedItem = item;
      _detailsController.text = details;
      _occurredAt = DateTime.now();
      _error = null;
    });
  }

  Future<void> _changeTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        _occurredAt.year,
        _occurredAt.month,
        _occurredAt.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final selected = _selectedItem;
    if (selected == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        selected.label(AppLocalizations.of(context)!),
        _detailsController.text.trim(),
        _occurredAt,
      );
      if (mounted) {
        Navigator.pop(context, selected.label(AppLocalizations.of(context)!));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppLocalizations.of(context)!.quickRecordSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItem;
    return SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: selected == null
            ? _EventPicker(
                key: const ValueKey('event-picker'),
                recentPresets: widget.recentPresets,
                onSelect: _select,
                onOpenDetailedRecord: widget.onOpenDetailedRecord,
              )
            : _EventForm(
                key: ValueKey(selected.id),
                item: selected,
                detailsController: _detailsController,
                occurredAt: _occurredAt,
                saving: _saving,
                error: _error,
                onBack: () => setState(() {
                  _selectedItem = null;
                  _error = null;
                }),
                onChangeTime: _changeTime,
                onSave: _save,
              ),
      ),
    );
  }
}

class _EventPicker extends StatelessWidget {
  const _EventPicker({
    required this.recentPresets,
    required this.onSelect,
    required this.onOpenDetailedRecord,
    super.key,
  });

  final List<RecentEventPreset> recentPresets;
  final void Function(EventCatalogItem item, {String details}) onSelect;
  final VoidCallback onOpenDetailedRecord;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final quickItems = defaultQuickEventIds.map(eventCatalogItem).toList();
    return SingleChildScrollView(
      key: const Key('record-entry-picker'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.recordSheetTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSectionHeader(title: loc.quickRecordsTitle),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final item in quickItems)
                _EventChoiceChip(
                  key: Key('quick-record-${item.id.name}'),
                  item: item,
                  onTap: () => onSelect(item),
                ),
            ],
          ),
          if (recentPresets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppSectionHeader(title: loc.recentRecordsTitle),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final preset in recentPresets)
                  ActionChip(
                    key: Key('recent-record-${preset.item.id.name}'),
                    avatar: Icon(preset.item.icon, size: 18),
                    label: Text(preset.label(loc)),
                    onPressed: () =>
                        onSelect(preset.item, details: preset.details),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppSectionHeader(title: loc.allCategoriesTitle),
          for (final category in EventCategoryId.values)
            ExpansionTile(
              key: Key('event-category-${category.name}'),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
              ),
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
              title: Text(eventCategoryLabel(category, loc)),
              children: [
                for (final item in eventCatalog.where(
                  (item) => item.category == category,
                ))
                  ListTile(
                    key: Key('category-event-${item.id.name}'),
                    leading: Icon(item.icon),
                    title: Text(item.label(loc)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onSelect(item),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('open-detailed-record'),
            onPressed: onOpenDetailedRecord,
            icon: const Icon(Icons.edit_note_outlined),
            label: Text(loc.writeDetailedRecord),
          ),
        ],
      ),
    );
  }
}

class _EventChoiceChip extends StatelessWidget {
  const _EventChoiceChip({required this.item, required this.onTap, super.key});

  final EventCatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(item.icon, size: 18),
      label: Text(item.label(AppLocalizations.of(context)!)),
      onPressed: onTap,
    );
  }
}

class _EventForm extends StatelessWidget {
  const _EventForm({
    required this.item,
    required this.detailsController,
    required this.occurredAt,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onChangeTime,
    required this.onSave,
    super.key,
  });

  final EventCatalogItem item;
  final TextEditingController detailsController;
  final DateTime occurredAt;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onChangeTime;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      key: const Key('record-entry-form'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('back-to-record-types'),
                tooltip: loc.backToRecordTypes,
                onPressed: saving ? null : onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(item.icon),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  item.label(loc),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('quick-record-details'),
            controller: detailsController,
            enabled: !saving,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: loc.eventDetailOptionalLabel,
              hintText: loc.eventDetailOptionalHint,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('quick-record-time'),
            onPressed: saving ? null : onChangeTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              '${loc.recordTimeLabel} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt))}',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              error!,
              key: const Key('quick-record-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('save-quick-record'),
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(saving ? loc.savingQuickRecord : loc.saveRecord),
          ),
        ],
      ),
    );
  }
}
