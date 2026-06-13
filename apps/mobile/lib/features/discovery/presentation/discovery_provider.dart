import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/discovery_repository.dart';
import '../domain/discovery_state.dart';
import '../../../shared/models/peer_device.dart';
import '../../../providers/app_providers.dart';

/// Riverpod [StateNotifier] for the discovery screen.
///
/// Wires the real [DiscoveryRepositoryImpl] into the state machine:
///   - Creates the repository with the device name from [deviceNameProvider].
///   - Starts discovery on [startDiscovery].
///   - Subscribes to [DiscoveryRepositoryImpl.peersStream] and merges
///     snapshots into [DiscoveryState].
///   - Stops discovery and cancels subscriptions on [stopDiscovery].
///   - Disposes the repository when the notifier is disposed.
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier(this._ref) : super(const DiscoveryState());

  final Ref _ref;
  DiscoveryRepositoryImpl? _repository;
  StreamSubscription<List<PeerDevice>>? _peersSubscription;

  /// Start peer discovery.
  ///
  /// Creates the [DiscoveryRepositoryImpl] on the first call using the
  /// current device name from [deviceNameProvider].
  Future<void> startDiscovery() async {
    if (state.isScanning) return;

    state = state.copyWith(isScanning: true, clearError: true);

    final deviceName = _ref.read(deviceNameProvider);

    _repository ??= DiscoveryRepositoryImpl(deviceName: deviceName);

    try {
      await _repository!.startDiscovery();

      _peersSubscription = _repository!.peersStream.listen(
        _onPeersUpdate,
        onError: _onError,
      );
    } catch (e) {
      _onError(e);
    }
  }

  /// Stop peer discovery and clean up subscriptions.
  Future<void> stopDiscovery() async {
    await _peersSubscription?.cancel();
    _peersSubscription = null;

    await _repository?.stopDiscovery();

    state = state.copyWith(isScanning: false, peers: const []);
  }

  /// Called each time the repository emits an updated peer list snapshot.
  void _onPeersUpdate(List<PeerDevice> peers) {
    if (!mounted) return;
    state = state.copyWith(peers: peers);
  }

  /// Called when the repository stream emits an error.
  void _onError(Object error) {
    if (!mounted) return;
    state = state.copyWith(
      isScanning: false,
      error: error.toString(),
    );
  }

  @override
  void dispose() {
    _peersSubscription?.cancel();
    _repository?.dispose();
    super.dispose();
  }
}

/// Provider for [DiscoveryNotifier].
///
/// Not autoDisposed — discovery persists for the lifetime of the app
/// so that background BLE advertising continues while the user is in
/// the pairing or transfer screens.
final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  return DiscoveryNotifier(ref);
});
