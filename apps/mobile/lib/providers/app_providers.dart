import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// Shown in the peer list of remote devices.
/// Default is derived from the host platform at runtime.
/// Persisted to local preferences (persistence layer is not yet implemented).
final deviceNameProvider = StateProvider<String>((ref) => 'My Device');

// ── App lifecycle ─────────────────────────────────────────────────

/// Whether the application is in the foreground and actively visible.
///
/// Used by discovery and transfer providers to pause background operations
/// when the app is hidden.
final appInForegroundProvider = StateProvider<bool>((ref) => true);
