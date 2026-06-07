import 'package:flutter/foundation.dart';

/// Represents a peer device discovered via BLE or mDNS.
///
/// This is a pure value object — it carries no methods that perform I/O.
/// All fields are nullable where the discovery protocol does not guarantee
/// a value at the time of discovery (e.g. [signalStrength] for mDNS peers).
@immutable
final class PeerDevice {
  const PeerDevice({
    required this.id,
    required this.name,
    required this.platform,
    this.signalStrength,
    this.isTrusted = false,
    this.source = DiscoverySource.ble,
    this.address,
  });

  /// Ephemeral, non-persistent peer identifier.
  ///
  /// For BLE peers: derived from the BLE device address (not stored).
  /// For mDNS peers: the `id` field from the TXT record (re-randomised per boot).
  ///
  /// Used for deduplication in the peer list. Never stored to persistent storage.
  final String id;

  /// User-configured display name of the peer device.
  final String name;

  /// The operating system of the peer device.
  final PeerPlatform platform;

  /// BLE RSSI value, or `null` for mDNS-only peers.
  ///
  /// Ranges from approximately -30 (very close) to -90 (far / weak).
  final int? signalStrength;

  /// Whether this peer was previously confirmed via PIN verification.
  ///
  /// Note: this is a UI-only hint. Re-pairing is always required
  /// per the no-persistent-identity architecture rule.
  final bool isTrusted;

  /// Which discovery mechanism surfaced this peer.
  final DiscoverySource source;

  /// Resolved network address (IP:port), available after pairing.
  /// Opaque — do not parse. Forwarded to Rust as-is.
  final String? address;

  // ── Convenience ───────────────────────────────────────────────────

  /// Signal strength as a value 0.0–1.0, or `null` if unavailable.
  double? get signalStrengthNormalized {
    if (signalStrength == null) return null;
    // Map -30 (strong) → 1.0, -90 (weak) → 0.0
    const min = -90.0;
    const max = -30.0;
    return ((signalStrength! - min) / (max - min)).clamp(0.0, 1.0);
  }

  PeerDevice copyWith({
    String? id,
    String? name,
    PeerPlatform? platform,
    int? signalStrength,
    bool? isTrusted,
    DiscoverySource? source,
    String? address,
  }) {
    return PeerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      signalStrength: signalStrength ?? this.signalStrength,
      isTrusted: isTrusted ?? this.isTrusted,
      source: source ?? this.source,
      address: address ?? this.address,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PeerDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PeerDevice(id: $id, name: $name, platform: $platform)';
}

/// The operating system reported by the peer device.
enum PeerPlatform {
  android,
  ios,
  macos,
  windows,
  linux,
  unknown;

  /// Human-readable label for display in the UI.
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
