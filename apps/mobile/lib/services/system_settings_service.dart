import 'dart:io';

import 'package:flutter/services.dart';

/// Opens Android system settings screens via [MethodChannel].
///
/// All calls are fire-and-forget — Android handles the Intent.
/// Failures (e.g. unsupported action) are logged but not rethrown.
///
/// The corresponding Kotlin handler is in [MainActivity].
class SystemSettingsService {
  static const _channel = MethodChannel('dev.ethersynapse/settings');

  // ── Action keys (must match MainActivity.kt) ──────────────────────

  /// Opens the system Bluetooth settings panel.
  static const actionBluetooth = 'bluetooth';

  /// Opens the system WiFi settings panel.
  static const actionWifi = 'wifi';

  /// Opens the Hotspot / Tethering settings panel.
  static const actionHotspot = 'hotspot';

  /// Opens the app's own permission settings page.
  static const actionAppPermissions = 'app_permissions';

  /// Opens the Nearby Devices / "Nearby Share" permission settings.
  static const actionNearby = 'nearby';

  // ── Public API ────────────────────────────────────────────────────

  /// Open [action] system settings screen.
  ///
  /// Silently ignores calls on non-Android platforms.
  static Future<void> open(String action) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openSettings', {'action': action});
    } on PlatformException catch (e) {
      // Log but never crash — settings are always best-effort.
      assert(() {
        // ignore: avoid_print
        print('[EtherSynapse] SystemSettings open("$action") failed: $e');
        return true;
      }());
    }
  }
}
