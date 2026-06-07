import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/discovery_state.dart';
import '../../../shared/models/peer_device.dart';

/// Riverpod [StateNotifier] for the discovery screen.
///
/// Responsible for:
///   - Starting and stopping discovery via the repository.
///   - Merging peer stream events into [DiscoveryState].
///   - Exposing actions to the presentation layer.
///
/// DO NOT add BLE or mDNS logic here.
/// DO NOT call flutter_rust_bridge directly here — use the repository.
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier() : super(const DiscoveryState());

  // TODO(impl): Inject DiscoveryRepository via provider override.

  /// Start peer discovery.
  Future<void> startDiscovery() async {
    state = state.copyWith(isScanning: true, clearError: true);
    // TODO(impl): await _repository.startDiscovery();
    // TODO(impl): _repository.peersStream.listen(_onPeersUpdate);
  }

  /// Stop peer discovery.
  Future<void> stopDiscovery() async {
    // TODO(impl): await _repository.stopDiscovery();
    state = state.copyWith(isScanning: false);
  }

  /// Called when the peer list updates from the repository stream.
  void _onPeersUpdate(List<PeerDevice> peers) {
    state = state.copyWith(peers: peers);
  }

  /// Handle a discovery error from the repository.
  void _onError(Object error) {
    state = state.copyWith(
      isScanning: false,
      error: error.toString(),
    );
  }
}

/// Provider for [DiscoveryNotifier].
final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  return DiscoveryNotifier();
});
