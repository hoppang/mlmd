import 'package:flutter/material.dart';

/// Centers content on wide screens while keeping full width on small screens.
class AdaptiveContentFrame extends StatelessWidget {
  const AdaptiveContentFrame({
    super.key,
    required this.child,
    this.contentMaxWidth = 720,
    this.horizontalPadding = 0,
  });

  final Widget child;
  final double contentMaxWidth;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth = constraints.maxWidth < contentMaxWidth
            ? constraints.maxWidth
            : contentMaxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: maxContentWidth,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
