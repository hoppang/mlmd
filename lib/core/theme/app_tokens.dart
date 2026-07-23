import 'package:flutter/material.dart';

/// Shared visual constants for the application.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadii {
  static const double control = 12;
  static const double card = 16;
}

abstract final class AppSizes {
  static const double minimumInteractiveDimension = 48;
  static const double contentMaxWidth = 720;
  static const double compactFormBreakpoint = 520;
}

abstract final class AppInsets {
  static const EdgeInsets page = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.xl,
  );

  static const EdgeInsets card = EdgeInsets.all(AppSpacing.md);
  static const EdgeInsets dialog = EdgeInsets.all(AppSpacing.lg);
}
