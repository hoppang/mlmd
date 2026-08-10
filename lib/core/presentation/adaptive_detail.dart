import 'package:flutter/material.dart';

/// Opens complex detail, input, and editing flows as a dedicated page.
///
/// The legacy name is retained to avoid churn at call sites, but this helper
/// deliberately no longer presents a dialog or bottom sheet.
Future<T?> showAdaptiveDetail<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxDialogWidth = 560,
  bool expandedDialog = false,
  double maxExpandedContentWidth = 960,
}) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      fullscreenDialog: true,
      builder: (pageContext) => Scaffold(
        key: const Key('adaptive-detail-page'),
        appBar: AppBar(
          leading: CloseButton(
            onPressed: () => Navigator.maybePop(pageContext),
          ),
        ),
        body: builder(pageContext),
      ),
    ),
  );
}
