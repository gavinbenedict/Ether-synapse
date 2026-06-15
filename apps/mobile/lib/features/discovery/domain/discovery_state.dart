import 'package:flutter/foundation.dart';

import '../../../shared/models/peer_device.dart';

/// Domain state for the discovery feature.
///
/// Immutable snapshot of the current discovery screen state.
/// The Riverpod provider updates this via [copyWith] as events arrive.
@immutable
final class DiscoveryState {
  const DiscoveryState({
    this.peers = const [],
    this.isScanning = false,
    this.isAdvertising = false,
    this.bluetoothEnabled = true,
    this.error,
    this.lastUpdated,
  });

  /// Currently visible peers. Deduplicated and sorted by signal strength.
  final List<PeerDevice> peers;

  /// Whether an active BLE scan is running.
  final bool isScanning;

  /// Whether BLE advertising is active.
  final bool isAdvertising;

  /// Whether Bluetooth is enabled on this device.
  final bool bluetoothEnabled;

  /// Non-null if discovery has encountered an unrecoverable error.
  final String? error;

  /// When the peer list was last updated (for display).
  final DateTime? lastUpdated;

  // ── Convenience ───────────────────────────────────────────────────

  bool get hasPeers => peers.isNotEmpty;
  bool get hasError => error != null;
  bool get isActive => isScanning || isAdvertising;

  /// Sorted peers — stronger signal first; unknown signal at the end.
  List<PeerDevice> get sortedPeers {
    final sorted = List<PeerDevice>.of(peers);
    sorted.sort((a, b) {
      final sa = a.signalStrength ?? -999;
      final sb = b.signalStrength ?? -999;
      return sb.compareTo(sa); // descending
    });
    return sorted;
  }

  DiscoveryState copyWith({
    List<PeerDevice>? peers,
    bool? isScanning,
    bool? isAdvertising,
    bool? bluetoothEnabled,
    String? error,
    bool clearError = false,
    DateTime? lastUpdated,
  }) {
    return DiscoveryState(
      peers: peers ?? this.peers,
      isScanning: isScanning ?? this.isScanning,
      isAdvertising: isAdvertising ?? this.isAdvertising,
      bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveryState &&
          listEquals(other.peers, peers) &&
          other.isScanning == isScanning &&
          other.isAdvertising == isAdvertising &&
          other.bluetoothEnabled == bluetoothEnabled &&
          other.error == error;

  @override
  int get hashCode =>
      Object.hash(peers, isScanning, isAdvertising, bluetoothEnabled, error);
}
