import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/discovery_repository.dart';
import '../data/ble_discovery_service.dart';
import '../domain/discovery_state.dart';
import '../../../shared/models/peer_device.dart';
import '../../../shared/models/device_role.dart';
import '../../../providers/app_providers.dart';

/// Riverpod [StateNotifier] for the discovery screen.
///
/// Wires the real [DiscoveryRepositoryImpl] into the state machine:
///   - Creates the repository with the device name from [deviceNameProvider].
///   - Starts discovery on [startDiscovery].
///   - Subscribes to the peer list stream and the status stream.
///   - Merges all events into [DiscoveryState].
///   - Stops discovery and cancels subscriptions on [stopDiscovery].
///   - Disposes the repository when the notifier is disposed.
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier(this._ref) : super(const DiscoveryState());

  final Ref _ref;
  DiscoveryRepositoryImpl? _repository;
  StreamSubscription<List<PeerDevice>>? _peersSubscription;
  StreamSubscription<DiscoveryStatus>? _statusSubscription;

  /// Start peer discovery.
  Future<void> startDiscovery() async {
    if (state.isScanning) return;

    state = state.copyWith(isScanning: true, clearError: true);

    final deviceName = _ref.read(deviceNameProvider);
    _repository ??= DiscoveryRepositoryImpl(
      deviceName: deviceName,
      role: DeviceRole.sender, // legacy screen: scan-only
    );

    try {
      await _repository!.startDiscovery();

      // Subscribe to peer list updates.
      _peersSubscription = _repository!.peersStream.listen(
        _onPeersUpdate,
        onError: _onError,
      );

      // Subscribe to advertising / Bluetooth state changes.
      _statusSubscription = _repository!.service.statusStream.listen(
        _onStatusUpdate,
        onError: (_) {}, // status errors are non-fatal
      );
    } catch (e) {
      _onError(e);
    }
  }

  /// Stop peer discovery and clean up subscriptions.
  Future<void> stopDiscovery() async {
    await _peersSubscription?.cancel();
    _peersSubscription = null;

    await _statusSubscription?.cancel();
    _statusSubscription = null;

    await _repository?.stopDiscovery();

    state = state.copyWith(
      isScanning: false,
      isAdvertising: false,
      peers: const [],
    );
  }

  /// Called each time the repository emits an updated peer list snapshot.
  void _onPeersUpdate(List<PeerDevice> peers) {
    if (!mounted) return;
    state = state.copyWith(
      peers: peers,
      lastUpdated: DateTime.now(),
    );
  }

  /// Called when the BLE service emits a status change.
  void _onStatusUpdate(DiscoveryStatus status) {
    if (!mounted) return;
    state = state.copyWith(
      isScanning: status.isScanning,
      isAdvertising: status.isAdvertising,
      bluetoothEnabled: status.bluetoothEnabled,
    );
  }

  /// Called when the repository stream emits an error.
  void _onError(Object error) {
    if (!mounted) return;
    state = state.copyWith(
      isScanning: false,
      isAdvertising: false,
      error: error.toString(),
    );
  }

  @override
  void dispose() {
    _peersSubscription?.cancel();
    _statusSubscription?.cancel();
    _repository?.dispose();
    super.dispose();
  }
}

/// Provider for [DiscoveryNotifier].
///
/// Not autoDisposed — discovery persists for the lifetime of the app
/// so that BLE advertising continues while the user is in other screens.
final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  return DiscoveryNotifier(ref);
});
