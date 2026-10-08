import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Design tokens. One accent (a warm vermilion), warm paper neutrals, and a small set of
/// subject hues. Every text/background pair used for reading is checked against WCAG AA
/// in test/design_test.dart.
class AppColors {
  const AppColors._({
    required this.paper,
    required this.surface,
    required this.surfaceDim,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.accentTint,
    required this.good,
    required this.goodTint,
    required this.warn,
    required this.warnTint,
    required this.danger,
    required this.dangerTint,
    required this.info,
    required this.infoTint,
    required this.brightness,
  });

  final Color paper, surface, surfaceDim, ink, inkSoft, line;
  final Color accent, onAccent, accentTint;
  final Color good, goodTint, warn, warnTint, danger, dangerTint, info, infoTint;
  final Brightness brightness;

  static const light = AppColors._(
    paper: Color(0xFFFBF7F0),
    surface: Color(0xFFFFFFFF),
    surfaceDim: Color(0xFFF3EDE2),
    ink: Color(0xFF1F2430),
    inkSoft: Color(0xFF5A6070),
    line: Color(0xFFE5DDCF),
    accent: Color(0xFFC2410C),
    onAccent: Color(0xFFFFFFFF),
    accentTint: Color(0xFFFFF0E6),
    good: Color(0xFF166534),
    goodTint: Color(0xFFDDF3E4),
    warn: Color(0xFF8A5A00),
    warnTint: Color(0xFFFFF0CC),
    danger: Color(0xFFB42318),
    dangerTint: Color(0xFFFDE3DF),
    info: Color(0xFF1D4ED8),
    infoTint: Color(0xFFE0E9FF),
    brightness: Brightness.light,
  );

  static const dark = AppColors._(
    paper: Color(0xFF14161C),
    surface: Color(0xFF1E212B),
    surfaceDim: Color(0xFF262A36),
    ink: Color(0xFFF1EDE4),
    inkSoft: Color(0xFFB4B2AA),
    line: Color(0xFF343949),
    accent: Color(0xFFF4A261),
    onAccent: Color(0xFF2B1400),
    accentTint: Color(0xFF3A2A1F),
    good: Color(0xFF7BD99C),
    goodTint: Color(0xFF173626),
    warn: Color(0xFFF2C14E),
    warnTint: Color(0xFF3A2F12),
    danger: Color(0xFFFF8F84),
    dangerTint: Color(0xFF3C1E1B),
    info: Color(0xFF9DB8FF),
    infoTint: Color(0xFF1C2744),
    brightness: Brightness.dark,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Spacing and shape scale (logical pixels).
abstract final class Sp {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 24.0, xxl = 32.0;
}

abstract final class Rd {
  static const chip = 12.0, card = 20.0, hero = 28.0, pill = 999.0;
}

/// WCAG 2.x contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) => 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  final la = lum(a), lb = lum(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
