import 'package:flutter/material.dart';

import 'tokens.dart';

/// Typography: Fraunces (a soft, characterful serif) for headlines and card text,
/// Inter for everything you operate. Both are bundled, so the app stays offline.
abstract final class AppText {
  static TextStyle serif(double size, {int weight = 600, double? height, Color? color, double soft = 60}) => TextStyle(
        fontFamily: 'Fraunces',
        fontSize: size,
        height: height ?? 1.2,
        fontWeight: _w(weight),
        color: color,
        fontVariations: [
          FontVariation('wght', weight.toDouble()),
          FontVariation('opsz', size.clamp(9, 144).toDouble()),
          FontVariation('SOFT', soft),
          const FontVariation('WONK', 0),
        ],
      );

  static TextStyle sans(double size, {int weight = 400, double? height, Color? color, double? spacing}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        height: height ?? 1.4,
        fontWeight: _w(weight),
        letterSpacing: spacing,
        color: color,
        fontVariations: [
          FontVariation('wght', weight.toDouble()),
          FontVariation('opsz', size.clamp(14, 32).toDouble()),
        ],
      );

  static FontWeight _w(int w) => FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];
}

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentTint,
      onPrimaryContainer: c.ink,
      secondary: c.info,
      onSecondary: c.brightness == Brightness.dark ? const Color(0xFF0E1630) : Colors.white,
      secondaryContainer: c.infoTint,
      onSecondaryContainer: c.ink,
      tertiary: c.good,
      onTertiary: c.brightness == Brightness.dark ? const Color(0xFF06220F) : Colors.white,
      tertiaryContainer: c.goodTint,
      onTertiaryContainer: c.ink,
      error: c.danger,
      onError: c.brightness == Brightness.dark ? const Color(0xFF2B0A07) : Colors.white,
      errorContainer: c.dangerTint,
      onErrorContainer: c.ink,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkSoft,
      surfaceContainerLowest: c.paper,
      surfaceContainerLow: c.paper,
      surfaceContainer: c.surfaceDim,
      surfaceContainerHigh: c.surfaceDim,
      surfaceContainerHighest: c.surfaceDim,
      outline: c.inkSoft,
      outlineVariant: c.line,
      shadow: const Color(0xFF1F2430),
      scrim: Colors.black,
    );

    final text = TextTheme(
      displayLarge: AppText.serif(44, weight: 700, color: c.ink),
      displayMedium: AppText.serif(36, weight: 700, color: c.ink),
      displaySmall: AppText.serif(30, weight: 600, color: c.ink, height: 1.22),
      headlineLarge: AppText.serif(28, weight: 650, color: c.ink),
      headlineMedium: AppText.serif(24, weight: 650, color: c.ink),
      headlineSmall: AppText.serif(21, weight: 600, color: c.ink, height: 1.25),
      titleLarge: AppText.serif(20, weight: 600, color: c.ink),
      titleMedium: AppText.sans(16, weight: 650, color: c.ink),
      titleSmall: AppText.sans(14, weight: 650, color: c.ink),
      bodyLarge: AppText.sans(16, color: c.ink, height: 1.5),
      bodyMedium: AppText.sans(14, color: c.ink, height: 1.45),
      bodySmall: AppText.sans(12.5, color: c.inkSoft),
      labelLarge: AppText.sans(14, weight: 650, color: c.ink),
      labelMedium: AppText.sans(12.5, weight: 600, color: c.inkSoft, spacing: 0.2),
      labelSmall: AppText.sans(11.5, weight: 600, color: c.inkSoft, spacing: 0.3),
    );

    final stadium = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.pill));
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      textTheme: text,
      fontFamily: 'Inter',
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.paper,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.serif(22, weight: 650, color: c.ink),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rd.card),
          side: BorderSide(color: c.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(64, 52),
          shape: stadium,
          textStyle: AppText.sans(16, weight: 650),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(64, 48),
          shape: stadium,
          side: BorderSide(color: c.line, width: 1.5),
          textStyle: AppText.sans(15, weight: 600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(48, 44),
          shape: stadium,
          textStyle: AppText.sans(14, weight: 650),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceDim,
        side: BorderSide.none,
        labelStyle: AppText.sans(12.5, weight: 600, color: c.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.chip)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.accentTint,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(AppText.sans(12, weight: 600, color: c.ink)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? c.accent : c.inkSoft, size: 26)),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rd.chip + 4), borderSide: BorderSide(color: c.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rd.chip + 4), borderSide: BorderSide(color: c.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rd.chip + 4), borderSide: BorderSide(color: c.accent, width: 2)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: AppText.sans(14, color: c.paper),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.chip + 4)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: c.accentTint,
          selectedForegroundColor: c.ink,
          foregroundColor: c.inkSoft,
          side: BorderSide(color: c.line),
          textStyle: AppText.sans(13, weight: 600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.onAccent : c.inkSoft),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceDim),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.line,
        circularTrackColor: c.line,
      ),
    );
  }
}
