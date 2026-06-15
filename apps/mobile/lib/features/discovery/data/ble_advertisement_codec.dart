import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/device_capabilities.dart';
import '../../../shared/models/peer_device.dart';

/// Encodes and decodes [PeerDevice] identity **and device capabilities** into
/// the BLE manufacturer-specific data payload (protocol v2).
///
/// ## Payload layout — v2 (22 bytes, company-ID prefix NOT included):
///
/// ```
/// Offset  Length  Field
/// ──────  ──────  ──────────────────────────────────────────────────────────
///   0       1     Protocol version (0x02)
///   1       1     Platform byte    (see [_platformToByte])
///   2       1     Capability flags:
///                   bit 0 = supportsHotspot
///                   bit 1 = supportsWifiDirect
///                   bit 2 = supportsLocalWifi (currently connected to WiFi)
///                   bits 3–5 = wifiScore (0–7, maps to WiFi generation)
///                   bits 6–7 = reserved (0)
///   3       1     Android SDK version (0 = unknown / non-Android)
///   4      14     Device name (UTF-8, zero-padded to 14 bytes)
///  18       4     Session ID (random uint32, big-endian)
/// ```
///
/// Total: 22 bytes.  The scanner reads manufacturer data starting at
/// offset 0 of the bytes returned by flutter_reactive_ble, which does NOT
/// include the 2-byte company-ID prefix.
///
/// ## Capability flags byte (byte 2) bit layout
/// ```
///  7  6  5  4  3  2  1  0
///  r  r  ──wifiScore──  W  D  H
///  │  │       │         │  │  └── supportsHotspot
///  │  │       │         │  └──── supportsWifiDirect
///  │  │       │         └─────── supportsLocalWifi
///  │  │       └───────────────── wifiScore (3 bits, 0-7)
///  └──┴───────────────────────── reserved (0)
/// ```
abstract final class BleAdvertisementCodec {
  BleAdvertisementCodec._();

  // ── Encoding ─────────────────────────────────────────────────────

  /// Encodes identity + capabilities into a 22-byte manufacturer payload.
  ///
  /// [capabilities] must be the **local** device's detected capabilities.
  /// Passing null falls back to all-false flags / zero SDK version.
  static Uint8List encode({
    required String displayName,
    required PeerPlatform platform,
    required int sessionId,
    DeviceCapabilities? capabilities,
  }) {
    final buf = Uint8List(AppConstants.bleManufacturerDataLength);
    int offset = 0;

    // Byte 0: protocol version
    buf[offset++] = AppConstants.bleProtocolVersion;

    // Byte 1: platform
    buf[offset++] = _platformToByte(platform);

    // Byte 2: capability flags
    buf[offset++] = _encodeCapabilityFlags(capabilities);

    // Byte 3: Android SDK version (capped at 255)
    buf[offset++] =
        (capabilities?.androidSdkVersion ?? 0).clamp(0, 255).toInt();

    // Bytes 4–17: display name (UTF-8, max 14 bytes, zero-padded)
    final nameBytes = _encodeNameBytes(displayName);
    buf.setRange(
        offset, offset + AppConstants.bleDeviceNameMaxBytes, nameBytes);
    offset += AppConstants.bleDeviceNameMaxBytes;

    // Bytes 18–21: session ID (big-endian uint32)
    buf[offset++] = (sessionId >> 24) & 0xFF;
    buf[offset++] = (sessionId >> 16) & 0xFF;
    buf[offset++] = (sessionId >> 8) & 0xFF;
    buf[offset++] = sessionId & 0xFF;

    return buf;
  }

  // ── Decoding ─────────────────────────────────────────────────────

  /// Decoding result — returned together so callers don't decode twice.
  static ({PeerDevice? peer, DeviceCapabilities? capabilities}) decode({
    required List<int> data,
    required String bleDeviceId,
    required int rssi,
  }) {
    const empty = (peer: null, capabilities: null);

    if (data.length < AppConstants.bleManufacturerDataLength) return empty;

    int offset = 0;

    // Byte 0: protocol version guard (accept both v1 and v2)
    final version = data[offset++];
    if (version != AppConstants.bleProtocolVersion &&
        version != 0x01) return empty;

    // Byte 1: platform
    final platform = _byteToAppPlatform(data[offset++]);

    // Byte 2: capability flags (v2 only; v1 peers get null caps)
    DeviceCapabilities? caps;
    int sdkVersion = 0;
    if (version == AppConstants.bleProtocolVersion) {
      final flagByte = data[offset++];
      sdkVersion = data[offset++];
      caps = _decodeCapabilityFlags(flagByte, sdkVersion);
    } else {
      // v1 packet: skip 0 capability bytes (layout is different — just guard)
      // name starts at offset 2 in v1
    }

    // Bytes 4–17 (v2) or 2–17 (v1): device name
    final nameStart = (version == AppConstants.bleProtocolVersion) ? 4 : 2;
    final nameLen = (version == AppConstants.bleProtocolVersion)
        ? AppConstants.bleDeviceNameMaxBytes
        : 16; // v1 used 16

    if (data.length < nameStart + nameLen + 4) return empty;
    final nameBytes = data.sublist(nameStart, nameStart + nameLen);
    final name = _decodeNameBytes(nameBytes);

    // Last 4 bytes: session ID
    final sidOffset = nameStart + nameLen;
    final sessionId = (data[sidOffset] << 24) |
        (data[sidOffset + 1] << 16) |
        (data[sidOffset + 2] << 8) |
        data[sidOffset + 3];
    final peerId = sessionId.toRadixString(16).padLeft(8, '0');

    final peer = PeerDevice(
      id: peerId,
      name: name.isEmpty ? 'Unknown Device' : name,
      displayName: name.isEmpty ? 'Unknown Device' : name,
      platform: platform,
      signalStrength: rssi,
      source: DiscoverySource.ble,
      bleAddress: bleDeviceId,   // BLE MAC address — used for GATT connect
      remoteCapabilities: caps,
    );

    return (peer: peer, capabilities: caps);
  }

  // ── Session ID ────────────────────────────────────────────────────

  /// Generates a random 32-bit session ID, re-randomised per advertising start.
  static int generateSessionId() {
    final rng = Random.secure();
    return rng.nextInt(0x7FFFFFFF) + 1; // non-zero, positive
  }

  // ── Capability flags helpers ──────────────────────────────────────

  /// WiFi generation → 3-bit score (0–7):
  ///   unknown=0, wifi4=4, wifi5=5, wifi6=6, wifi6e=7, wifi7=7
  static int _wifiStandardToScore(String standard) => switch (standard) {
        'wifi4' => 4,
        'wifi5' => 5,
        'wifi6' => 6,
        'wifi6e' => 7,
        'wifi7' => 7,
        _ => 0,
      };

  static String _scoreToWifiStandard(int score) => switch (score) {
        4 => 'wifi4',
        5 => 'wifi5',
        6 => 'wifi6',
        7 => 'wifi6e',
        _ => 'unknown',
      };

  static int _encodeCapabilityFlags(DeviceCapabilities? caps) {
    if (caps == null) return 0;
    int flags = 0;
    if (caps.supportsHotspot) flags |= 0x01;
    if (caps.supportsWifiDirect) flags |= 0x02;
    if (caps.supportsLocalWifi) flags |= 0x04;
    final score = _wifiStandardToScore(caps.wifiStandard).clamp(0, 7);
    flags |= (score << 3);
    return flags;
  }

  static DeviceCapabilities _decodeCapabilityFlags(
      int flags, int sdkVersion) {
    final supportsHotspot = (flags & 0x01) != 0;
    final supportsWifiDirect = (flags & 0x02) != 0;
    final supportsLocalWifi = (flags & 0x04) != 0;
    final wifiScore = (flags >> 3) & 0x07;
    return DeviceCapabilities(
      deviceName: 'Unknown Device', // model from GATT
      displayName: 'Unknown', // name from advertisement
      deviceModel: 'Unknown Device', // model from GATT
      appVersion: '', // not in payload; assumed same
      androidSdkVersion: sdkVersion,
      wifiStandard: _scoreToWifiStandard(wifiScore),
      supportsHotspot: supportsHotspot,
      supportsWifiDirect: supportsWifiDirect,
      supportsLocalWifi: supportsLocalWifi,
    );
  }

  // ── Name helpers ──────────────────────────────────────────────────

  static Uint8List _encodeNameBytes(String name) {
    final encoded = utf8.encode(name);
    final truncated = encoded.length > AppConstants.bleDeviceNameMaxBytes
        ? encoded.sublist(0, AppConstants.bleDeviceNameMaxBytes)
        : encoded;
    final padded = Uint8List(AppConstants.bleDeviceNameMaxBytes);
    padded.setRange(0, truncated.length, truncated);
    return padded;
  }

  static String _decodeNameBytes(List<int> bytes) {
    int end = bytes.length;
    while (end > 0 && bytes[end - 1] == 0) {
      end--;
    }
    if (end == 0) return '';
    try {
      return utf8.decode(bytes.sublist(0, end));
    } catch (_) {
      return '';
    }
  }

  // ── Platform helpers ──────────────────────────────────────────────

  static int _platformToByte(PeerPlatform platform) => switch (platform) {
        PeerPlatform.android => 0x00,
        PeerPlatform.ios => 0x01,
        PeerPlatform.macos => 0x02,
        PeerPlatform.windows => 0x03,
        PeerPlatform.linux => 0x04,
        PeerPlatform.unknown => 0xFF,
      };

  static PeerPlatform _byteToAppPlatform(int byte) => switch (byte) {
        0x00 => PeerPlatform.android,
        0x01 => PeerPlatform.ios,
        0x02 => PeerPlatform.macos,
        0x03 => PeerPlatform.windows,
        0x04 => PeerPlatform.linux,
        _ => PeerPlatform.unknown,
      };
}
