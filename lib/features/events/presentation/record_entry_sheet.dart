import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/app_section_header.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/shared_custom_event_definition_entity.dart';
import '../application/custom_event_notifier.dart';
import '../domain/event_catalog.dart';

typedef SaveEventRecord =
    Future<void> Function(String type, String details, DateTime occurredAt);
typedef SaveCustomEventRecord =
    Future<void> Function(
      String customEventTypeId,
      String nameSnapshot,
      String memo,
      DateTime occurredAt,
    );

class RecordEntrySheet extends ConsumerStatefulWidget {
  const RecordEntrySheet({
    required this.recentPresets,
    required this.onSave,
    required this.onSaveCustom,
    required this.onOpenDetailedRecord,
    super.key,
  });

  final List<RecentEventPreset> recentPresets;
  final SaveEventRecord onSave;
  final SaveCustomEventRecord onSaveCustom;
  final VoidCallback onOpenDetailedRecord;

  @override
  ConsumerState<RecordEntrySheet> createState() => _RecordEntrySheetState();
}

class _RecordEntrySheetState extends ConsumerState<RecordEntrySheet> {
  final _detailsController = TextEditingController();
  EventCatalogItem? _selectedItem;
  SharedCustomEventDefinitionEntity? _selectedCustomEvent;
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
      _selectedCustomEvent = null;
      _detailsController.text = details;
      _occurredAt = DateTime.now();
      _error = null;
    });
  }

  void _selectCustom(SharedCustomEventDefinitionEntity definition) {
    setState(() {
      _selectedItem = null;
      _selectedCustomEvent = definition;
      _detailsController.clear();
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
    final custom = _selectedCustomEvent;
    if ((selected == null && custom == null) || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final loc = AppLocalizations.of(context)!;
      final savedName = custom?.name ?? selected!.label(loc);
      if (custom == null) {
        await widget.onSave(
          savedName,
          _detailsController.text.trim(),
          _occurredAt,
        );
      } else {
        await widget.onSaveCustom(
          custom.customEventTypeId,
          custom.name,
          _detailsController.text.trim(),
          _occurredAt,
        );
      }
      if (mounted) {
        Navigator.pop(context, savedName);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppLocalizations.of(context)!.quickRecordSaveFailed;
      });
    }
  }

  Future<String?> _requestCustomEventName({String initialName = ''}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _CustomEventNameDialog(initialName: initialName),
    );
  }

  Future<void> _createCustomEvent() async {
    final name = await _requestCustomEventName();
    if (name == null || !mounted) return;
    final definition = ref
        .read(customEventCatalogProvider.notifier)
        .create(name);
    _selectCustom(definition);
  }

  Future<void> _renameCustomEvent(
    SharedCustomEventDefinitionEntity definition,
  ) async {
    final name = await _requestCustomEventName(initialName: definition.name);
    if (name == null || !mounted) return;
    ref
        .read(customEventCatalogProvider.notifier)
        .rename(definition.customEventTypeId, name);
  }

  Future<void> _archiveCustomEvent(
    SharedCustomEventDefinitionEntity definition,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.archiveCustomEventTitle),
        content: Text(loc.archiveCustomEventDescription(definition.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            key: const Key('confirm-archive-custom-event'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.archiveCustomEvent),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(customEventCatalogProvider.notifier)
        .archive(definition.customEventTypeId);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItem;
    final custom = _selectedCustomEvent;
    final customState = ref.watch(customEventCatalogProvider);
    return SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: selected == null && custom == null
            ? _EventPicker(
                key: const ValueKey('event-picker'),
                recentPresets: widget.recentPresets,
                customState: customState,
                onSelect: _select,
                onSelectCustom: _selectCustom,
                onCreateCustom: _createCustomEvent,
                onRenameCustom: _renameCustomEvent,
                onArchiveCustom: _archiveCustomEvent,
                onToggleCustomPin: (definition) {
                  ref
                      .read(customEventCatalogProvider.notifier)
                      .setPinned(
                        definition.customEventTypeId,
                        pinned: !customState.isPinned(
                          definition.customEventTypeId,
                        ),
                      );
                },
                onOpenDetailedRecord: widget.onOpenDetailedRecord,
              )
            : _EventForm(
                key: ValueKey(custom?.customEventTypeId ?? selected!.id.name),
                label:
                    custom?.name ??
                    selected!.label(AppLocalizations.of(context)!),
                icon: custom == null ? selected!.icon : Icons.bookmark_outline,
                custom: custom != null,
                detailsController: _detailsController,
                occurredAt: _occurredAt,
                saving: _saving,
                error: _error,
                onBack: () => setState(() {
                  _selectedItem = null;
                  _selectedCustomEvent = null;
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
    required this.customState,
    required this.onSelect,
    required this.onSelectCustom,
    required this.onCreateCustom,
    required this.onRenameCustom,
    required this.onArchiveCustom,
    required this.onToggleCustomPin,
    required this.onOpenDetailedRecord,
    super.key,
  });

  final List<RecentEventPreset> recentPresets;
  final CustomEventCatalogState customState;
  final void Function(EventCatalogItem item, {String details}) onSelect;
  final ValueChanged<SharedCustomEventDefinitionEntity> onSelectCustom;
  final VoidCallback onCreateCustom;
  final ValueChanged<SharedCustomEventDefinitionEntity> onRenameCustom;
  final ValueChanged<SharedCustomEventDefinitionEntity> onArchiveCustom;
  final ValueChanged<SharedCustomEventDefinitionEntity> onToggleCustomPin;
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
              for (final definition in customState.pinnedDefinitions)
                ActionChip(
                  key: Key('quick-custom-${definition.customEventTypeId}'),
                  avatar: const Icon(Icons.bookmark_outline, size: 18),
                  label: Text(definition.name),
                  onPressed: () => onSelectCustom(definition),
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
          AppSectionHeader(title: loc.myRecordsTitle),
          for (final definition in customState.definitions)
            ListTile(
              key: Key('custom-event-${definition.customEventTypeId}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
              ),
              leading: const Icon(Icons.bookmark_outline),
              title: Text(definition.name),
              onTap: () => onSelectCustom(definition),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('pin-custom-${definition.customEventTypeId}'),
                    tooltip: customState.isPinned(definition.customEventTypeId)
                        ? loc.removeFromQuickRecords
                        : loc.pinToQuickRecords,
                    onPressed: () => onToggleCustomPin(definition),
                    icon: Icon(
                      customState.isPinned(definition.customEventTypeId)
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                    ),
                  ),
                  PopupMenuButton<_CustomEventAction>(
                    key: Key('manage-custom-${definition.customEventTypeId}'),
                    onSelected: (action) {
                      switch (action) {
                        case _CustomEventAction.rename:
                          onRenameCustom(definition);
                        case _CustomEventAction.archive:
                          onArchiveCustom(definition);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _CustomEventAction.rename,
                        child: Text(loc.renameCustomEvent),
                      ),
                      PopupMenuItem(
                        value: _CustomEventAction.archive,
                        child: Text(loc.archiveCustomEvent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            key: const Key('create-custom-event'),
            onPressed: onCreateCustom,
            icon: const Icon(Icons.add),
            label: Text(loc.createCustomEvent),
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
    required this.label,
    required this.icon,
    required this.custom,
    required this.detailsController,
    required this.occurredAt,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onChangeTime,
    required this.onSave,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool custom;
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
              Icon(icon),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
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
              labelText: custom
                  ? loc.customEventMemoOptionalLabel
                  : loc.eventDetailOptionalLabel,
              hintText: custom
                  ? loc.customEventMemoOptionalHint
                  : loc.eventDetailOptionalHint,
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

enum _CustomEventAction { rename, archive }

class _CustomEventNameDialog extends StatefulWidget {
  const _CustomEventNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_CustomEventNameDialog> createState() => _CustomEventNameDialogState();
}

class _CustomEventNameDialogState extends State<_CustomEventNameDialog> {
  late final TextEditingController _controller;
  bool _showRequired = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _looksLikeMedication {
    final normalized = _controller.text.trim().toLowerCase();
    return const [
      '약',
      '투약',
      '비타민',
      'medicine',
      'medication',
      'vitamin',
      '薬',
      '投薬',
      'ビタミン',
    ].any(normalized.contains);
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showRequired = true);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.initialName.isEmpty
            ? loc.createCustomEvent
            : loc.renameCustomEvent,
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('custom-event-name'),
                controller: _controller,
                autofocus: true,
                maxLength: 40,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _showRequired = false),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: loc.customEventNameLabel,
                  hintText: loc.customEventNameHint,
                  errorText: _showRequired ? loc.customEventNameRequired : null,
                ),
              ),
              if (_looksLikeMedication) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  loc.customEventMedicationHint,
                  key: const Key('custom-event-medication-hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        FilledButton(
          key: const Key('save-custom-event-name'),
          onPressed: _submit,
          child: Text(loc.saveRecord),
        ),
      ],
    );
  }
}
