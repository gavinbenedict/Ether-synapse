/// Application-wide constants for Ether Synapse.
///
/// All magic strings and numeric values referenced across multiple files
/// are centralised here. Feature-specific constants belong in their
/// respective feature directories.
abstract final class AppConstants {
  AppConstants._();

  // ── Application metadata ────────────────────────────────────────
  static const String appName = 'Ether Synapse';
  static const String appVersion = '0.1.0';

  // ── BLE discovery ───────────────────────────────────────────────
  /// Maximum display length for a device name in the peer list.
  static const int maxDeviceNameLength = 24;

  /// Scan timeout in seconds. After this period, a passive scan
  /// result is considered stale and removed from the peer list.
  static const int bleDiscoveryScanTimeoutSeconds = 30;

  // ── Transfer ────────────────────────────────────────────────────
  /// Default chunk size in bytes (64 KiB — see transfer-protocol.md).
  static const int defaultChunkSizeBytes = 65536;

  /// Maximum number of concurrent file transfers (v1 — single session).
  static const int maxConcurrentTransfers = 1;

  // ── Pairing ─────────────────────────────────────────────────────
  /// Seconds before a pending pairing attempt is automatically aborted.
  static const int pairingTimeoutSeconds = 60;

  /// Number of digits in the verification PIN.
  static const int pinLength = 6;

  // ── UI ──────────────────────────────────────────────────────────
  /// Duration for most page transition animations.
  static const Duration pageTransitionDuration = Duration(milliseconds: 280);

  /// Duration for micro-animations (chip appearance, list items, etc.).
  static const Duration microAnimationDuration = Duration(milliseconds: 160);

  /// Duration for status badge fades.
  static const Duration statusFadeDuration = Duration(milliseconds: 200);
}
