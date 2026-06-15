import 'package:flutter/foundation.dart';

import 'device_capabilities.dart';

/// Represents a peer device discovered via BLE.
///
/// This is a pure value object — it carries no methods that perform I/O.
/// All fields are nullable where the discovery protocol does not guarantee
/// a value at the time of discovery.
///
/// In BLE v2, [remoteCapabilities] is populated directly from the decoded
/// advertisement payload — no GATT connection or estimation is needed.
@immutable
final class PeerDevice {
  const PeerDevice({
    required this.id,
    required this.name,
    required this.platform,
    this.displayName,
    this.signalStrength,
    this.isTrusted = false,
    this.source = DiscoverySource.ble,
    this.address,
    this.bleAddress,
    this.remoteCapabilities,
  });

  /// Ephemeral peer identifier derived from the BLE session ID.
  /// Never stored to persistent storage.
  final String id;

  /// User-configured display name of the peer device.
  /// Legacy field, same as [displayName].
  final String name;

  /// User-configured display name of the peer device (e.g. "Gavin").
  final String? displayName;

  /// The operating system of the peer device.
  final PeerPlatform platform;

  /// BLE RSSI value in dBm, or `null` for non-BLE peers.
  final int? signalStrength;

  /// Whether this peer was previously confirmed via PIN verification.
  final bool isTrusted;

  /// Which discovery mechanism surfaced this peer.
  final DiscoverySource source;

  /// Resolved network address (IP:port), available after transport setup.
  final String? address;

  /// The raw BLE peripheral MAC address (e.g. "AA:BB:CC:DD:EE:FF").
  /// This is the identifier used for GATT connections via flutter_reactive_ble.
  /// Distinct from [id] which is the ephemeral session-ID hex string.
  final String? bleAddress;

  /// Capabilities decoded from the BLE v2 advertisement payload.
  ///
  /// Non-null when the peer advertises protocol v2.
  /// Null for legacy v1 peers (all-false, hotspot fallback used).
  final DeviceCapabilities? remoteCapabilities;

  // ── Convenience ───────────────────────────────────────────────────

  /// Signal strength as a value 0.0–1.0, or `null` if unavailable.
  double? get signalStrengthNormalized {
    if (signalStrength == null) return null;
    const min = -90.0;
    const max = -30.0;
    return ((signalStrength! - min) / (max - min)).clamp(0.0, 1.0);
  }

  PeerDevice copyWith({
    String? id,
    String? name,
    String? displayName,
    PeerPlatform? platform,
    int? signalStrength,
    bool? isTrusted,
    DiscoverySource? source,
    String? address,
    String? bleAddress,
    DeviceCapabilities? remoteCapabilities,
  }) {
    return PeerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      platform: platform ?? this.platform,
      signalStrength: signalStrength ?? this.signalStrength,
      isTrusted: isTrusted ?? this.isTrusted,
      source: source ?? this.source,
      address: address ?? this.address,
      bleAddress: bleAddress ?? this.bleAddress,
      remoteCapabilities: remoteCapabilities ?? this.remoteCapabilities,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PeerDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PeerDevice(id: $id, name: $name, platform: $platform, '
      'bleAddress: $bleAddress, caps: $remoteCapabilities)';
}

/// The operating system reported by the peer device.
enum PeerPlatform {
  android,
  ios,
  macos,
  windows,
  linux,
  unknown;

  String get label => switch (this) {
        PeerPlatform.android => 'Android',
        PeerPlatform.ios => 'iOS',
        PeerPlatform.macos => 'macOS',
        PeerPlatform.windows => 'Windows',
        PeerPlatform.linux => 'Linux',
        PeerPlatform.unknown => 'Unknown',
      };
}

/// The mechanism by which a peer was discovered.
enum DiscoverySource {
  ble,
  mdns;

  String get label => switch (this) {
        DiscoverySource.ble => 'Bluetooth',
        DiscoverySource.mdns => 'Network',
      };
}
