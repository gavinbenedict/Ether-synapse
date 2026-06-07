import 'package:flutter/material.dart';

/// Ether Synapse color system.
///
/// Palette rationale:
///   - Seed color: deep teal (#0D7377) — communicates trust, security, privacy.
///   - Light surface: near-white with cool undertone — clean, airy, modern.
///   - Dark surface: deep charcoal-navy — deliberate, professional, private.
///
/// Generated from Material 3 color utilities via seed colour.
/// Override individual roles below for fine-grained control.
abstract final class AppColorScheme {
  // ── Seed Color ────────────────────────────────────────────────────

  /// The single seed color from which the full palette is derived.
  static const Color _seed = Color(0xFF0D7377);

  // ── Light Scheme ──────────────────────────────────────────────────

  static ColorScheme light() {
    return ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      // Surface hierarchy: creates subtle depth without heavy shadows.
      surface: const Color(0xFFF6F8FA),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF0F4F7),
      surfaceContainer: const Color(0xFFE8EEF3),
      surfaceContainerHigh: const Color(0xFFDDE5EC),
      surfaceContainerHighest: const Color(0xFFD3DDE6),
    );
  }

  // ── Dark Scheme ───────────────────────────────────────────────────

  static ColorScheme dark() {
    return ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(
      // Dark surface hierarchy: deep, deliberate, high contrast ratios.
      surface: const Color(0xFF0E1218),
      surfaceContainerLowest: const Color(0xFF090D12),
      surfaceContainerLow: const Color(0xFF141B22),
      surfaceContainer: const Color(0xFF1A232C),
      surfaceContainerHigh: const Color(0xFF212D38),
      surfaceContainerHighest: const Color(0xFF283644),
    );
  }
}
