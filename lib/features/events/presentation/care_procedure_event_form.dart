import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/stt_memo_text_field.dart';
import '../../attachments/domain/event_attachment.dart';
import '../domain/care_procedure_record.dart';

class CareProcedureFormResult {
  const CareProcedureFormResult({
    required this.record,
    required this.procedureName,
    required this.details,
    required this.attachments,
  });

  final CareProcedureRecord record;
  final String procedureName;
  final String details;
  final List<EventAttachment> attachments;
}

class CareProcedureEventForm extends StatefulWidget {
  const CareProcedureEventForm({
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
  final ValueChanged<CareProcedureFormResult> onSave;
  final CareProcedureRecord? initialRecord;
  final List<EventAttachment> initialAttachments;

  @override
  State<CareProcedureEventForm> createState() => _CareProcedureEventFormState();
}

class _CareProcedureEventFormState extends State<CareProcedureEventForm> {
  static const _uuid = Uuid();

  CareProcedureType? _selectedType;
  late final TextEditingController _bodyAreaController;
  late final TextEditingController _noteController;
  late List<EventAttachment> _attachments;
  String? _validationError;

  bool get _showsBodyArea =>
      _selectedType == CareProcedureType.woundCare ||
      _selectedType == CareProcedureType.hotColdPack;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialRecord?.procedureType;
    _bodyAreaController = TextEditingController(
      text: widget.initialRecord?.bodyArea ?? '',
    );
    _noteController = TextEditingController(
      text: widget.initialRecord?.note ?? '',
    );
    _attachments = List.of(widget.initialAttachments);
  }

  @override
  void dispose() {
    _bodyAreaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _selectType(CareProcedureType type) {
    setState(() {
      _selectedType = type;
      _validationError = null;
      if (!_showsBodyArea) {
        _bodyAreaController.clear();
      }
    });
  }

  void _addAttachment(AttachmentSourceKind sourceKind) {
    final now = DateTime.now();
    final isPhoto = sourceKind != AttachmentSourceKind.filePicker;
    final fileName = isPhoto
        ? 'care_procedure_${now.millisecondsSinceEpoch}.jpg'
        : 'care_procedure_${now.millisecondsSinceEpoch}.file';
    final attachment = EventAttachment(
      attachmentId: _uuid.v4(),
      recordId: widget.initialRecord?.recordId ?? '',
      attachmentType: AttachmentType.general,
      fileName: fileName,
      mimeType: isPhoto ? 'image/jpeg' : 'application/octet-stream',
      sourceKind: sourceKind,
      managedOriginalUri: 'app_storage://$fileName',
      createdAt: now,
    );
    setState(() => _attachments.add(attachment));
  }

  void _removeAttachment(String attachmentId) {
    setState(() {
      _attachments.removeWhere(
        (attachment) => attachment.attachmentId == attachmentId,
      );
    });
  }

  void _save() {
    final loc = AppLocalizations.of(context)!;
    final selectedType = _selectedType;
    final note = _noteController.text.trim();
    if (selectedType == null) {
      setState(() => _validationError = loc.careProcedureTypeRequired);
      return;
    }
    if (selectedType == CareProcedureType.other && note.isEmpty) {
      setState(() => _validationError = loc.careProcedureOtherRequired);
      return;
    }

    final record = CareProcedureRecord(
      recordId: widget.initialRecord?.recordId,
      childId: widget.initialRecord?.childId,
      occurredAt: widget.occurredAt,
      procedureType: selectedType,
      bodyArea: _showsBodyArea && _bodyAreaController.text.trim().isNotEmpty
          ? _bodyAreaController.text.trim()
          : null,
      note: note.isEmpty ? null : note,
      createdByAuthorProfileId: widget.initialRecord?.createdByAuthorProfileId,
      createdByDeviceProfileId: widget.initialRecord?.createdByDeviceProfileId,
      createdAt: widget.initialRecord?.createdAt,
      lastModified: widget.initialRecord?.lastModified,
    );
    widget.onSave(
      CareProcedureFormResult(
        record: record,
        procedureName: selectedType == CareProcedureType.other
            ? '${loc.careProcedureEvent} · ${selectedType.label(loc)}'
            : selectedType.label(loc),
        details: record.buildSupportingDetails(),
        attachments: _attachments,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      key: const Key('care-procedure-event-form'),
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
              const Icon(Icons.home_repair_service_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.careProcedureEvent,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(loc.careProcedureTime),
              trailing: TextButton.icon(
                onPressed: widget.saving ? null : widget.onChangeTime,
                icon: const Icon(Icons.schedule),
                label: Text(
                  '${widget.occurredAt.hour.toString().padLeft(2, '0')}:'
                  '${widget.occurredAt.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: AppInsets.card,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(loc.careProcedureScopeHelp)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(loc.careProcedureTypeLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final type in CareProcedureType.values)
                ChoiceChip(
                  key: Key('care-procedure-type-${type.name}'),
                  label: Text(type.label(loc)),
                  selected: _selectedType == type,
                  onSelected: widget.saving
                      ? null
                      : (selected) {
                          if (selected) _selectType(type);
                        },
                ),
            ],
          ),
          if (_showsBodyArea) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('care-procedure-body-area'),
              controller: _bodyAreaController,
              decoration: InputDecoration(
                labelText: loc.careProcedureBodyAreaLabel,
                hintText: loc.careProcedureBodyAreaHint,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SttMemoTextField(
            key: const Key('care-procedure-note'),
            controller: _noteController,
            labelText: _selectedType == CareProcedureType.other
                ? loc.careProcedureOtherNoteLabel
                : loc.careProcedureNoteLabel,
            hintText: loc.careProcedureNoteHint,
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('care-procedure-photo-button'),
                  onPressed: widget.saving
                      ? null
                      : () => _addAttachment(AttachmentSourceKind.inAppCamera),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(loc.careProcedurePhotoButton),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('care-procedure-file-button'),
                  onPressed: widget.saving
                      ? null
                      : () => _addAttachment(AttachmentSourceKind.filePicker),
                  icon: const Icon(Icons.attach_file),
                  label: Text(loc.attachFileButton),
                ),
              ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final attachment in _attachments)
                  Chip(
                    avatar: Icon(
                      attachment.isImage
                          ? Icons.image_outlined
                          : Icons.insert_drive_file_outlined,
                      size: 18,
                    ),
                    label: Text(attachment.fileName),
                    onDeleted: widget.saving
                        ? null
                        : () => _removeAttachment(attachment.attachmentId),
                  ),
              ],
            ),
          ],
          if (_validationError != null || widget.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _validationError ?? widget.error!,
              key: const Key('care-procedure-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('save-care-procedure-event'),
            onPressed: widget.saving ? null : _save,
            icon: widget.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(loc.saveRecord),
          ),
        ],
      ),
    );
  }
}
