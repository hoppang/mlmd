import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/stt_memo_text_field.dart';
import '../../attachments/domain/event_attachment.dart';
import '../domain/medical_guidance.dart';
import '../domain/vaccination_record.dart';

class VaccinationFormResult {
  const VaccinationFormResult({
    required this.record,
    required this.details,
    required this.attachments,
  });

  final VaccinationRecord record;
  final String details;
  final List<EventAttachment> attachments;
}

class VaccinationEventForm extends StatefulWidget {
  const VaccinationEventForm({
    required this.occurredAt,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onChangeTime,
    required this.onSave,
    this.initialRecord,
    this.initialAttachments = const [],
    this.launchExternal,
    super.key,
  });

  final DateTime occurredAt;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onChangeTime;
  final ValueChanged<VaccinationFormResult> onSave;
  final VaccinationRecord? initialRecord;
  final List<EventAttachment> initialAttachments;
  final Future<bool> Function(Uri uri)? launchExternal;

  @override
  State<VaccinationEventForm> createState() => _VaccinationEventFormState();
}

class _VaccinationEventFormState extends State<VaccinationEventForm> {
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
    final isVaccinationBook = type == AttachmentType.vaccinationRecord;
    final fileName = isVaccinationBook
        ? 'vaccination_book_${now.millisecondsSinceEpoch}.jpg'
        : 'attachment_${now.millisecondsSinceEpoch}.file';

    final attachment = EventAttachment(
      attachmentId: id,
      recordId: widget.initialRecord?.recordId ?? '',
      attachmentType: type,
      fileName: fileName,
      mimeType: isVaccinationBook ? 'image/jpeg' : 'application/octet-stream',
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

  Future<void> _openKdcaWebsite(BuildContext context) async {
    final uri = Uri.parse('https://nip.kdca.go.kr');
    if (!isApprovedGuidanceUri(uri)) {
      _showFailure(context);
      return;
    }
    try {
      final opened =
          await (widget.launchExternal?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && context.mounted) _showFailure(context);
    } catch (_) {
      if (context.mounted) _showFailure(context);
    }
  }

  void _showFailure(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.officialGuidanceOpenFailed,
          ),
        ),
      );
  }

  void _save() {
    final noteText = _noteController.text.trim();
    final record = VaccinationRecord(
      recordId: widget.initialRecord?.recordId,
      vaccinatedAt: widget.occurredAt,
      note: noteText.isNotEmpty ? noteText : null,
    );

    widget.onSave(
      VaccinationFormResult(
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
      key: const Key('vaccination-event-form'),
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
              const Icon(Icons.vaccines_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loc.vaccinationEvent,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(loc.vaccinationTime),
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
            labelText: loc.vaccinationNotesLabel,
            hintText: loc.vaccinationNotesHint,
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('add-vaccination-book-btn'),
                  onPressed: widget.saving
                      ? null
                      : () => _addAttachment(
                          type: AttachmentType.vaccinationRecord,
                          sourceKind: AttachmentSourceKind.inAppCamera,
                        ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(loc.vaccinationBookButton),
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
                final isVaccinationBook =
                    att.attachmentType == AttachmentType.vaccinationRecord;
                final label = isVaccinationBook
                    ? loc.attachmentVaccinationRecord
                    : loc.attachmentGeneral;
                final icon = isVaccinationBook
                    ? Icons.book_outlined
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
          const SizedBox(height: AppSpacing.lg),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: AppInsets.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '질병관리청 예방접종도우미',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    loc.checkKdcaVaccinationHistory,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('open-kdca-vaccination-link'),
                      onPressed: () => _openKdcaWebsite(context),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(loc.openInSystemBrowser),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    loc.kdcaVaccinationNotice,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('save-vaccination-event'),
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
