import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/stt_memo_text_field.dart';
import '../../attachments/domain/event_attachment.dart';
import '../domain/accident_injury_record.dart';

class AccidentFormResult {
  const AccidentFormResult({
    required this.record,
    required this.details,
    required this.attachments,
  });

  final AccidentInjuryRecord record;
  final String details;
  final List<EventAttachment> attachments;
}

class AccidentEventForm extends StatefulWidget {
  const AccidentEventForm({
    required this.occurredAt,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onChangeTime,
    required this.onSave,
    this.initialRecord,
    this.initialAttachments = const [],
    super.key,
  });

  final DateTime occurredAt;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onChangeTime;
  final ValueChanged<AccidentFormResult> onSave;
  final AccidentInjuryRecord? initialRecord;
  final List<EventAttachment> initialAttachments;

  @override
  State<AccidentEventForm> createState() => _AccidentEventFormState();
}

class _AccidentEventFormState extends State<AccidentEventForm> {
  late AccidentCategory _selectedCategory;
  late AccidentInjuryType _selectedInjuryType;
  late final TextEditingController _noteController;
  late List<EventAttachment> _attachments;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _selectedCategory =
        widget.initialRecord?.category ?? AccidentCategory.traumatic;
    _selectedInjuryType =
        widget.initialRecord?.injuryType ??
        (_selectedCategory == AccidentCategory.traumatic
            ? AccidentInjuryType.bumpBruise
            : AccidentInjuryType.foreignIngestion);
    _noteController = TextEditingController(
      text: widget.initialRecord?.note ?? '',
    );
    _attachments = List.of(widget.initialAttachments);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(AccidentCategory category) {
    if (category == _selectedCategory) return;
    setState(() {
      _selectedCategory = category;
      final matchingTypes = AccidentInjuryType.values
          .where((t) => t.category == category)
          .toList();
      if (!matchingTypes.contains(_selectedInjuryType)) {
        _selectedInjuryType = matchingTypes.first;
      }
    });
  }

  void _addPhotoAttachment(AttachmentSourceKind sourceKind) {
    final id = _uuid.v4();
    final now = DateTime.now();
    final fileName = 'accident_photo_${now.millisecondsSinceEpoch}.jpg';

    final attachment = EventAttachment(
      attachmentId: id,
      recordId: widget.initialRecord?.recordId ?? '',
      attachmentType: AttachmentType.general,
      fileName: fileName,
      mimeType: 'image/jpeg',
      sourceKind: sourceKind,
      managedOriginalUri: 'app_storage://$fileName',
      createdAt: now,
    );

    setState(() {
      _attachments.add(attachment);
    });
  }

  void _removeAttachment(String attachmentId) {
    setState(() {
      _attachments.removeWhere((att) => att.attachmentId == attachmentId);
    });
  }

  void _save() {
    final loc = AppLocalizations.of(context)!;
    final noteText = _noteController.text.trim();
    final record = AccidentInjuryRecord(
      recordId: widget.initialRecord?.recordId,
      occurredAt: widget.occurredAt,
      category: _selectedCategory,
      injuryType: _selectedInjuryType,
      note: noteText.isNotEmpty ? noteText : null,
    );

    final details = record.buildDetails(loc);

    widget.onSave(
      AccidentFormResult(
        record: record,
        details: details,
        attachments: _attachments,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final currentCategoryTypes = AccidentInjuryType.values
        .where((type) => type.category == _selectedCategory)
        .toList();

    return SingleChildScrollView(
      key: const Key('accident-event-form'),
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
                onPressed: widget.saving ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.healing_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.accidentInjuryEvent,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(loc.accidentTime),
              trailing: TextButton.icon(
                onPressed: widget.saving ? null : widget.onChangeTime,
                icon: const Icon(Icons.schedule),
                label: Text(
                  '${widget.occurredAt.hour.toString().padLeft(2, '0')}:${widget.occurredAt.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(loc.accidentCategoryLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<AccidentCategory>(
            segments: [
              ButtonSegment<AccidentCategory>(
                value: AccidentCategory.traumatic,
                label: Text(loc.accidentCategoryTraumatic),
                icon: const Icon(Icons.healing),
              ),
              ButtonSegment<AccidentCategory>(
                value: AccidentCategory.nonTraumatic,
                label: Text(loc.accidentCategoryNonTraumatic),
                icon: const Icon(Icons.warning_amber),
              ),
            ],
            selected: {_selectedCategory},
            onSelectionChanged: (selected) {
              if (selected.isNotEmpty) {
                _onCategoryChanged(selected.first);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(loc.accidentInjuryTypeLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final type in currentCategoryTypes)
                ChoiceChip(
                  key: Key('accident-type-chip-${type.name}'),
                  label: Text(type.label(loc)),
                  selected: _selectedInjuryType == type,
                  onSelected: widget.saving
                      ? null
                      : (selected) {
                          if (selected) {
                            setState(() {
                              _selectedInjuryType = type;
                            });
                          }
                        },
                ),
            ],
          ),
          if (_selectedInjuryType.requiresAttention) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              key: const Key('accident-attention-card'),
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.accidentGuidanceAttentionTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            loc.accidentGuidanceFirstAidInfo,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SttMemoTextField(
            controller: _noteController,
            labelText: loc.accidentNotesLabel,
            hintText: loc.accidentNotesHint,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('attach-accident-photo-button'),
            onPressed: widget.saving
                ? null
                : () => _addPhotoAttachment(AttachmentSourceKind.inAppCamera),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(loc.accidentPhotoAttachmentButton),
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    for (final att in _attachments)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.image_outlined),
                        title: Text(att.fileName),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: widget.saving
                              ? null
                              : () => _removeAttachment(att.attachmentId),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (widget.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('save-accident-event-button'),
            onPressed: widget.saving ? null : _save,
            icon: widget.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(loc.confirm),
          ),
        ],
      ),
    );
  }
}
