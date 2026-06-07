import 'package:flutter/material.dart';

/// Ether Synapse typography system.
///
/// Uses the Material 3 type scale with a clean system font stack.
/// The font stack resolves to Inter on most platforms via system fallback;
/// a bundled Inter font asset may be added later (see pubspec.yaml).
///
/// Scale rationale:
///   - Display: onboarding / error headers only — used sparingly.
///   - Headline: screen titles.
///   - Title: section headers, list item primaries.
///   - Body: content, descriptions, transfer details.
///   - Label: buttons, captions, metadata.
abstract final class AppTypography {
  AppTypography._();

  /// Builds the full [TextTheme] tinted to [color].
  ///
  /// Pass [ColorScheme.onSurface] for the default theme.
  static TextTheme textTheme(Color color) {
    return TextTheme(
      // ── Display ──────────────────────────────────────────────
      displayLarge: _style(57, FontWeight.w300, -0.25, color),
      displayMedium: _style(45, FontWeight.w300, 0, color),
      displaySmall: _style(36, FontWeight.w400, 0, color),

      // ── Headline ─────────────────────────────────────────────
      headlineLarge: _style(32, FontWeight.w600, 0, color),
      headlineMedium: _style(28, FontWeight.w600, 0, color),
      headlineSmall: _style(24, FontWeight.w600, 0, color),

      // ── Title ────────────────────────────────────────────────
      titleLarge: _style(22, FontWeight.w600, 0, color),
      titleMedium: _style(16, FontWeight.w600, 0.15, color),
      titleSmall: _style(14, FontWeight.w600, 0.1, color),

      // ── Body ─────────────────────────────────────────────────
      bodyLarge: _style(16, FontWeight.w400, 0.5, color),
      bodyMedium: _style(14, FontWeight.w400, 0.25, color),
      bodySmall: _style(12, FontWeight.w400, 0.4, color),

      // ── Label ────────────────────────────────────────────────
      labelLarge: _style(14, FontWeight.w600, 0.1, color),
      labelMedium: _style(12, FontWeight.w600, 0.5, color),
      labelSmall: _style(11, FontWeight.w500, 0.5, color),
    );
  }

  static TextStyle _style(
    double size,
    FontWeight weight,
    double letterSpacing,
    Color color,
  ) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
      height: _lineHeightFor(size),
    );
  }

  static double _lineHeightFor(double size) {
    // Tighter leading for large sizes; looser for small body text.
    if (size >= 32) return 1.25;
    if (size >= 22) return 1.3;
    if (size >= 16) return 1.5;
    return 1.6;
  }

  /// System font stack that resolves to a clean sans-serif on all platforms.
  /// Replace with 'Inter' once the font asset is bundled.
  static const String _fontFamily = '';
}
