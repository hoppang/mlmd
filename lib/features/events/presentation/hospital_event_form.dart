import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/stt_memo_text_field.dart';
import '../../attachments/domain/event_attachment.dart';
import '../domain/hospital_visit_record.dart';

class HospitalFormResult {
  const HospitalFormResult({
    required this.record,
    required this.details,
    required this.attachments,
  });

  final HospitalVisitRecord record;
  final String details;
  final List<EventAttachment> attachments;
}

class HospitalEventForm extends StatefulWidget {
  const HospitalEventForm({
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
  final ValueChanged<HospitalFormResult> onSave;
  final HospitalVisitRecord? initialRecord;
  final List<EventAttachment> initialAttachments;

  @override
  State<HospitalEventForm> createState() => _HospitalEventFormState();
}

class _HospitalEventFormState extends State<HospitalEventForm> {
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
    final isPrescription = type == AttachmentType.prescriptionBag;
    final fileName = isPrescription
        ? 'prescription_bag_${now.millisecondsSinceEpoch}.jpg'
        : 'attachment_${now.millisecondsSinceEpoch}.file';

    final attachment = EventAttachment(
      attachmentId: id,
      recordId: widget.initialRecord?.recordId ?? '',
      attachmentType: type,
      fileName: fileName,
      mimeType: isPrescription ? 'image/jpeg' : 'application/octet-stream',
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
    final record = HospitalVisitRecord(
      recordId: widget.initialRecord?.recordId,
      visitedAt: widget.occurredAt,
      note: noteText.isNotEmpty ? noteText : null,
    );

    widget.onSave(
      HospitalFormResult(
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
      key: const Key('hospital-event-form'),
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
              const Icon(Icons.local_hospital_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.hospitalEvent,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(loc.hospitalVisitTime),
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
          SttMemoTextField(
            controller: _noteController,
            labelText: loc.doctorNotesLabel,
            hintText: loc.doctorNotesHint,
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('add-prescription-bag-btn'),
                  onPressed: widget.saving
                      ? null
                      : () => _addAttachment(
                            type: AttachmentType.prescriptionBag,
                            sourceKind: AttachmentSourceKind.inAppCamera,
                          ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(loc.prescriptionBagButton),
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
              children: _attachments.map((att) {
                final isPrescription =
                    att.attachmentType == AttachmentType.prescriptionBag;
                final label = isPrescription
                    ? loc.attachmentPrescriptionBag
                    : loc.attachmentGeneral;
                final icon = isPrescription
                    ? Icons.medication_outlined
                    : Icons.insert_drive_file_outlined;

                return Chip(
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  onDeleted: widget.saving
                      ? null
                      : () => _removeAttachment(att.attachmentId),
                );
              }).toList(),
            ),
          ],
          if (widget.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('save-hospital-event'),
            onPressed: widget.saving ? null : _save,
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
