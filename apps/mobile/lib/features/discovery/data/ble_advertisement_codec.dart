import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/peer_device.dart';

/// Encodes and decodes [PeerDevice] identity into the BLE
/// manufacturer-specific data payload.
///
/// ## Payload layout (22 bytes, excluding the 2-byte company ID prefix
/// that flutter_ble_peripheral prepends automatically):
///
/// ```
/// Offset  Length  Field
/// ──────  ──────  ──────────────────────────────────────────────
///   0       1     Protocol version (0x01)
///   1       1     Platform byte    (see [_platformToByte])
///   2      16     Device name      (UTF-8, zero-padded to 16 bytes)
///  18       4     Session ID       (random uint32, big-endian)
/// ```
///
/// Total: 22 bytes.  The scanner reads manufacturer data starting at
/// offset 0 of the bytes returned by flutter_reactive_ble, which
/// does NOT include the company ID prefix.
abstract final class BleAdvertisementCodec {
  BleAdvertisementCodec._();

  // ── Encoding ─────────────────────────────────────────────────────

  /// Encodes [deviceName], [platform], and [sessionId] into a 22-byte
  /// manufacturer data payload suitable for [flutter_ble_peripheral].
  ///
  /// [sessionId] must be a 4-byte (uint32) value.
  static Uint8List encode({
    required String deviceName,
    required PeerPlatform platform,
    required int sessionId,
  }) {
    final buf = Uint8List(AppConstants.bleManufacturerDataLength);
    int offset = 0;

    // Byte 0: protocol version
    buf[offset++] = AppConstants.bleProtocolVersion;

    // Byte 1: platform
    buf[offset++] = _platformToByte(platform);

    // Bytes 2–17: device name (UTF-8, max 16 bytes, zero-padded)
    final nameBytes = _encodeNameBytes(deviceName);
    buf.setRange(offset, offset + AppConstants.bleDeviceNameMaxBytes, nameBytes);
    offset += AppConstants.bleDeviceNameMaxBytes;

    // Bytes 18–21: session ID (big-endian uint32)
    buf[offset++] = (sessionId >> 24) & 0xFF;
    buf[offset++] = (sessionId >> 16) & 0xFF;
    buf[offset++] = (sessionId >> 8) & 0xFF;
    buf[offset++] = sessionId & 0xFF;

    return buf;
  }

  // ── Decoding ─────────────────────────────────────────────────────

  /// Attempts to decode a [PeerDevice] from raw manufacturer data bytes.
  ///
  /// Returns `null` if:
  ///   - [data] is too short
  ///   - The protocol version byte does not match [AppConstants.bleProtocolVersion]
  ///
  /// [bleDeviceId] is the BLE MAC address or UUID from the scanner,
  /// used as a stable deduplication key within this session.
  ///
  /// [rssi] is the received signal strength in dBm.
  static PeerDevice? decode({
    required List<int> data,
    required String bleDeviceId,
    required int rssi,
  }) {
    // Minimum length check.
    if (data.length < AppConstants.bleManufacturerDataLength) return null;

    int offset = 0;

    // Byte 0: protocol version guard
    final version = data[offset++];
    if (version != AppConstants.bleProtocolVersion) return null;

    // Byte 1: platform
    final platform = _byteToAppPlatform(data[offset++]);

    // Bytes 2–17: device name
    final nameBytes = data.sublist(offset, offset + AppConstants.bleDeviceNameMaxBytes);
    offset += AppConstants.bleDeviceNameMaxBytes;
    final name = _decodeNameBytes(nameBytes);

    // Bytes 18–21: session ID → peer ID string
    final sessionId =
        (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
    final peerId = sessionId.toRadixString(16).padLeft(8, '0');

    return PeerDevice(
      id: peerId,
      name: name.isEmpty ? 'Unknown Device' : name,
      platform: platform,
      signalStrength: rssi,
      source: DiscoverySource.ble,
    );
  }

  // ── Session ID generation ─────────────────────────────────────────

  /// Generates a random 32-bit session ID, re-randomised per app boot.
  static int generateSessionId() {
    final rng = Random.secure();
    return rng.nextInt(0x7FFFFFFF) + 1; // non-zero, positive
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static Uint8List _encodeNameBytes(String name) {
    // Truncate to fit in [bleDeviceNameMaxBytes] when UTF-8 encoded.
    final encoded = utf8.encode(name);
    final truncated = encoded.length > AppConstants.bleDeviceNameMaxBytes
        ? encoded.sublist(0, AppConstants.bleDeviceNameMaxBytes)
        : encoded;
    final padded = Uint8List(AppConstants.bleDeviceNameMaxBytes);
    padded.setRange(0, truncated.length, truncated);
    return padded;
  }

  static String _decodeNameBytes(List<int> bytes) {
    // Strip trailing zero bytes before decoding.
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
