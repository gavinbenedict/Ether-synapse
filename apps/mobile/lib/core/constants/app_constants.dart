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

  /// How long (seconds) before a peer that stops advertising is
  /// considered lost and removed from the visible list.
  static const int bleDiscoveryScanTimeoutSeconds = 15;

  /// Maximum number of bytes used to encode the device name in the
  /// BLE manufacturer-specific data payload (v2 layout: 14 bytes).
  ///
  /// Reduced from 16 to 14 in protocol v2 to accommodate the new
  /// capability-flags byte (byte 2) and SDK-version byte (byte 3).
  static const int bleDeviceNameMaxBytes = 14;

  /// BLE company identifier used in manufacturer-specific data.
  /// 0xFFFF is reserved for testing by the Bluetooth SIG.
  /// Replace with a registered company ID before production.
  static const int bleCompanyId = 0xFFFF;

  /// Protocol version byte embedded in every advertisement.
  /// v2: adds capability-flags byte and Android SDK version byte.
  static const int bleProtocolVersion = 0x02;

  /// Manufacturer data total length in bytes (v2 layout):
  ///   Byte 0   : protocol version (0x02)
  ///   Byte 1   : platform byte
  ///   Byte 2   : capability flags
  ///                bit 0 = supportsHotspot
  ///                bit 1 = supportsWifiDirect
  ///                bit 2 = supportsLocalWifi (connected to WiFi)
  ///                bits 3–5 = wifiScore (0–7)
  ///                bits 6–7 = reserved
  ///   Byte 3   : Android SDK version (0 = unknown / non-Android)
  ///   Bytes 4–17 : device name (UTF-8, zero-padded, 14 bytes)
  ///   Bytes 18–21: session ID (random uint32, big-endian)
  /// Total: 22 bytes (unchanged from v1; 2 bytes repurposed).
  static const int bleManufacturerDataLength = 22;

  // ── Transfer ────────────────────────────────────────────────────
  /// Default chunk size in bytes (64 KiB).
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
