import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main.dart');
});

/// Global Riverpod providers used across the application.
///
/// Feature-specific providers live in their respective
/// `features/<name>/presentation/<name>_provider.dart` files.
/// This file contains only cross-cutting application-level state.

// ── Theme ─────────────────────────────────────────────────────────

/// Controls the app-wide [ThemeMode].
///
/// Default: [ThemeMode.system] — respects the user's OS setting.
/// The settings screen writes to this provider to allow manual override.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// ── Device name ───────────────────────────────────────────────────

/// The user-configured display name for this device.
///
/// Derived from [settingsProvider] so it always reflects the persisted value.
/// Any change in Settings propagates here immediately.
final deviceNameProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).deviceName;
});

// ── App lifecycle ─────────────────────────────────────────────────

/// Whether the application is in the foreground and actively visible.
///
/// Used by discovery and transfer providers to pause background operations
/// when the app is hidden.
final appInForegroundProvider = StateProvider<bool>((ref) => true);
