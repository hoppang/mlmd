import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 같은 상세 내용을 Android에서는 하단 시트로, Windows에서는 중앙
/// 대화상자로 표시합니다. 표시 방식만 달라지고 내용과 반환값은 같습니다.
Future<T?> showAdaptiveDetail<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxDialogWidth = 560,
}) {
  if (defaultTargetPlatform != TargetPlatform.windows) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: builder,
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
        ),
        child: builder(dialogContext),
      ),
    ),
  );
}
