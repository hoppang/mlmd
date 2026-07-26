import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/stt_memo_text_field.dart';
import '../../attachments/domain/event_attachment.dart';
import '../domain/bath_record.dart';

class BathFormResult {
  const BathFormResult({
    required this.record,
    required this.details,
    required this.attachments,
  });

  final BathRecord record;
  final String details;
  final List<EventAttachment> attachments;
}

class BathEventForm extends StatefulWidget {
  const BathEventForm({
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
  final ValueChanged<BathFormResult> onSave;
  final BathRecord? initialRecord;
  final List<EventAttachment> initialAttachments;

  @override
  State<BathEventForm> createState() => _BathEventFormState();
}

class _BathEventFormState extends State<BathEventForm> {
  late final TextEditingController _noteController;
  late List<EventAttachment> _attachments;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
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

  void _addAttachment({
    required AttachmentType type,
    required AttachmentSourceKind sourceKind,
  }) {
    final id = _uuid.v4();
    final now = DateTime.now();
    final fileName = 'bath_attachment_${now.millisecondsSinceEpoch}.jpg';

    final attachment = EventAttachment(
      attachmentId: id,
      recordId: widget.initialRecord?.recordId ?? '',
      attachmentType: type,
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
    final noteText = _noteController.text.trim();
    final record = BathRecord(
      recordId: widget.initialRecord?.recordId,
      childId: widget.initialRecord?.childId,
      occurredAt: widget.occurredAt,
      isQuickBath: true,
      note: noteText.isNotEmpty ? noteText : null,
      createdByAuthorProfileId: widget.initialRecord?.createdByAuthorProfileId,
      createdByDeviceProfileId: widget.initialRecord?.createdByDeviceProfileId,
      createdAt: widget.initialRecord?.createdAt,
      lastModified: widget.initialRecord?.lastModified,
    );

    widget.onSave(
      BathFormResult(
        record: record,
        details: noteText,
        attachments: _attachments,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      key: const Key('bath-event-form'),
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
              const Icon(Icons.bathtub_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.bathFormTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      loc.bathOneTouchHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('quick-record-time'),
            onPressed: widget.saving ? null : widget.onChangeTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              '${loc.recordTimeLabel} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(widget.occurredAt))}',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SttMemoTextField(
            key: const Key('bath-note-field'),
            controller: _noteController,
            labelText: loc.eventDetailOptionalLabel,
            hintText: loc.eventDetailOptionalHint,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('attach-photo-btn'),
                  onPressed: widget.saving
                      ? null
                      : () => _addAttachment(
                            type: AttachmentType.general,
                            sourceKind: AttachmentSourceKind.inAppCamera,
                          ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(loc.attachmentGeneral),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('attach-file-btn'),
                  onPressed: widget.saving
                      ? null
                      : () => _addAttachment(
                            type: AttachmentType.general,
                            sourceKind: AttachmentSourceKind.filePicker,
                          ),
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
                for (final att in _attachments)
                  Chip(
                    key: Key('attachment-chip-${att.attachmentId}'),
                    avatar: Icon(
                      att.sourceKind == AttachmentSourceKind.inAppCamera
                          ? Icons.image
                          : Icons.insert_drive_file,
                      size: 18,
                    ),
                    label: Text(
                      att.fileName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: widget.saving
                        ? null
                        : () => _removeAttachment(att.attachmentId),
                  ),
              ],
            ),
          ],
          if (widget.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.error!,
              key: const Key('quick-record-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('save-bath-record'),
            onPressed: widget.saving ? null : _save,
            icon: widget.saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(
              widget.saving ? loc.savingQuickRecord : loc.saveBathRecord,
            ),
          ),
        ],
      ),
    );
  }
}
