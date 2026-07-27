import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/stt_typo_corrector.dart';
import '../../../widgets/stt_memo_text_field.dart';
import '../domain/memo_record.dart';

class MemoFormResult {
  const MemoFormResult({required this.record, required this.details});

  final MemoRecord record;
  final String details;
}

class MemoEventForm extends ConsumerStatefulWidget {
  const MemoEventForm({
    required this.occurredAt,
    required this.saving,
    required this.error,
    required this.onBack,
    required this.onChangeTime,
    required this.onSave,
    this.initialRecord,
    super.key,
  });

  final DateTime occurredAt;
  final bool saving;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onChangeTime;
  final ValueChanged<MemoFormResult> onSave;
  final MemoRecord? initialRecord;

  @override
  ConsumerState<MemoEventForm> createState() => _MemoEventFormState();
}

class _MemoEventFormState extends ConsumerState<MemoEventForm> {
  late final TextEditingController _contentController;
  late final FocusNode _focusNode;
  String _inputSource = 'typed';
  String? _rawSttText;
  String? _previousContent;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.initialRecord?.content ?? '',
    );
    _focusNode = FocusNode();
    _inputSource = widget.initialRecord?.inputSource ?? 'typed';
    _rawSttText = widget.initialRecord?.rawSttText;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _runTypoCorrection() {
    final currentText = _contentController.text;
    if (currentText.trim().isEmpty) return;

    final corrector = ref.read(sttTypoCorrectorProvider);
    final result = corrector.correct(currentText);

    if (!mounted) return;

    if (!result.hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('교정할 맞춤법이나 오탈자가 없습니다.')),
      );
      return;
    }

    _showCorrectionDialog(result);
  }

  void _showCorrectionDialog(SttTypoCorrectionResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '맞춤법·오탈자 교정 결과',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '원문:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      result.originalText,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Divider(height: 16),
                    Text(
                      '교정 후:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      result.correctedText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (result.changesSummary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '변경 항목: ${result.changesSummary.join(", ")}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _previousContent = _contentController.text;
                        if (_rawSttText == null && _inputSource == 'stt') {
                          _rawSttText = _contentController.text;
                        }
                        _contentController.text = result.correctedText;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('교정 내용이 적용되었습니다.')),
                      );
                    },
                    child: const Text('적용'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _undoCorrection() {
    if (_previousContent != null) {
      setState(() {
        _contentController.text = _previousContent!;
        _previousContent = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원문으로 되돌렸습니다.')),
      );
    }
  }

  void _save() {
    final loc = AppLocalizations.of(context)!;
    final text = _contentController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _validationError = '메모 내용을 입력해 주세요.';
      });
      return;
    }

    final record = MemoRecord(
      recordId: widget.initialRecord?.recordId,
      childId: widget.initialRecord?.childId,
      occurredAt: widget.occurredAt,
      content: text,
      inputSource: _inputSource,
      legacyTitle: widget.initialRecord?.legacyTitle,
      rawSttText: _rawSttText,
      createdByAuthorProfileId:
          widget.initialRecord?.createdByAuthorProfileId,
      createdByDeviceProfileId:
          widget.initialRecord?.createdByDeviceProfileId,
      createdAt: widget.initialRecord?.createdAt,
      lastModified: widget.initialRecord?.lastModified,
    );

    final details = record.buildDetails(loc);

    widget.onSave(MemoFormResult(record: record, details: details));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final timeStr = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(widget.occurredAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBack,
              tooltip: '뒤로 가기',
            ),
            Icon(Icons.notes_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              loc.memoEvent,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.access_time, size: 16),
              label: Text(timeStr),
              onPressed: widget.onChangeTime,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SttMemoTextField(
          controller: _contentController,
          focusNode: _focusNode,
          minLines: 4,
          maxLines: 8,
          hintText: '메모를 자유롭게 작성하세요',
          onChanged: (val) {
            if (_validationError != null) {
              setState(() => _validationError = null);
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              key: const Key('stt_typo_correction_btn'),
              icon: const Icon(Icons.spellcheck, size: 18),
              label: const Text('맞춤법·오탈자만 정리'),
              onPressed: _runTypoCorrection,
            ),
            if (_previousContent != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                key: const Key('stt_undo_correction_btn'),
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('되돌리기'),
                onPressed: _undoCorrection,
              ),
            ],
          ],
        ),
        if (_validationError != null) ...[
          const SizedBox(height: 8),
          Text(
            _validationError!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
        ],
        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.error!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          key: const Key('save_memo_record_btn'),
          onPressed: widget.saving ? null : _save,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: widget.saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(loc.saveRecord),
        ),
      ],
    );
  }
}
