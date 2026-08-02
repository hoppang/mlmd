import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../repositories/stt_notice_repository.dart';
import '../services/stt_service.dart';
import '../features/settings/presentation/stt_notice_dialog.dart';

class SttMemoTextField extends ConsumerStatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final bool? overrideIsAndroid;
  final FocusNode? focusNode;

  const SttMemoTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.maxLines = 3,
    this.minLines = 1,
    this.onChanged,
    this.overrideIsAndroid,
    this.focusNode,
  });

  @override
  ConsumerState<SttMemoTextField> createState() => _SttMemoTextFieldState();
}

class _SttMemoTextFieldState extends ConsumerState<SttMemoTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  bool _isAndroidPlatform(BuildContext context) {
    if (widget.overrideIsAndroid != null) {
      return widget.overrideIsAndroid!;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> _handleMicPressed() async {
    final l10n = AppLocalizations.of(context)!;
    final noticeRepo = ref.read(sttNoticeRepositoryProvider);
    final sttService = ref.read(sttServiceProvider);

    if (_isListening) {
      await sttService.stopListening();
      setState(() {
        _isListening = false;
      });
      return;
    }

    // 1. 고지 동의 여부 확인
    if (!noticeRepo.isAccepted) {
      final accepted = await SttNoticeDialog.show(context);
      if (accepted != true) {
        return; // 키보드 입력 선택 시 이탈하지 않고 메모 내용 보존
      }
    }

    // 2. STT 서비스 시작
    final started = await sttService.startListening(
      onResult: (text) {
        if (!mounted) return;
        _insertTextAtCursor(text);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
        });
      },
    );

    if (started) {
      setState(() {
        _isListening = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.sttNotSupportedTooltip)));
      }
    }
  }

  void _insertTextAtCursor(String text) {
    final currentText = _controller.text;
    final selection = _controller.selection;

    if (selection.isValid && selection.start >= 0) {
      final newText = currentText.replaceRange(
        selection.start,
        selection.end,
        text,
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + text.length,
        ),
      );
    } else {
      // 커서 위치가 없으면 기존 텍스트에 공백 후 연결
      final separator = currentText.isNotEmpty && !currentText.endsWith(' ')
          ? ' '
          : '';
      final newText = currentText + separator + text;
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }

    widget.onChanged?.call(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isAndroid = _isAndroidPlatform(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isListening)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic,
                  size: 16,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.sttListeningStatus,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            suffixIcon: isAndroid
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                        tooltip: _isListening
                            ? l10n.sttStopAction
                            : l10n.sttMicButtonTooltip,
                        onPressed: _handleMicPressed,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        tooltip: l10n.sttNoticeTitle,
                        onPressed: () {
                          SttNoticeDialog.show(context);
                        },
                      ),
                    ],
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
