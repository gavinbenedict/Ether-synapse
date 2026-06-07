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
    this.error,
  });

  /// Currently visible peers. Deduplicated and sorted by signal strength.
  final List<PeerDevice> peers;

  /// Whether an active BLE scan or mDNS listen is running.
  final bool isScanning;

  /// Non-null if discovery has encountered an unrecoverable error.
  final String? error;

  // ── Convenience ───────────────────────────────────────────────────

  bool get hasPeers => peers.isNotEmpty;
  bool get hasError => error != null;

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
    String? error,
    bool clearError = false,
  }) {
    return DiscoveryState(
      peers: peers ?? this.peers,
      isScanning: isScanning ?? this.isScanning,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveryState &&
          listEquals(other.peers, peers) &&
          other.isScanning == isScanning &&
          other.error == error;

  @override
  int get hashCode => Object.hash(peers, isScanning, error);
}
