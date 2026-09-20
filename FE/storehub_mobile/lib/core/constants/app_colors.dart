import 'package:flutter/material.dart';
class AppColors {
  // ---- Legacy-named tokens (kept for backward compatibility) ----
  static const Color primary = Color(0xFF131B2E); // was blue, now brand slate
  static const Color primaryDark = Color(0xFF0B1220);
  static const Color accent = Color(0xFFFD761A); // safety orange CTA
  static const Color background = Color(0xFFF8F9FF);
  static const Color cardBg = Colors.white;
  static const Color surface = Color(0xFFF8F9FF);
  static const Color textPrimary = Color(0xFF0B1C30);
  static const Color textSecondary = Color(0xFF45464D);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFBA1A1A);
  static const Color border = Color(0xFFC6C6CD);

  // ---- Full design-system tokens ----
  static const Color primaryContainer = Color(0xFF131B2E);
  static const Color onPrimaryContainer = Color(0xFF7C839B);

  static const Color secondary = Color(0xFF9D4300);
  static const Color secondaryContainer = Color(0xFFFD761A);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF5C2400);
  static const Color secondaryFixed = Color(0xFFFFDBCA);
  static const Color onSecondaryFixed = Color(0xFF341100);

  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);

  static const Color onSurface = Color(0xFF0B1C30);
  static const Color onSurfaceVariant = Color(0xFF45464D);
  static const Color outline = Color(0xFF76777D);
  static const Color outlineVariant = Color(0xFFC6C6CD);

  static const Color warning = Color(0xFFF59E0B);
  static const Color errorContainer = Color(0xFFFFDAD6);
}
