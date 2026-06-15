import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../discovery/data/discovery_repository.dart';
import '../../discovery/data/ble_discovery_service.dart';
import '../../../shared/models/device_role.dart';
import '../../../providers/app_providers.dart';

/// State for the receive screen.
@immutable
class ReceiveState {
  const ReceiveState({
    this.isAdvertising = false,
    this.bluetoothEnabled = true,
    this.hasBluetoothPermission = true,
    this.error,
  });

  final bool isAdvertising;
  final bool bluetoothEnabled;
  final bool hasBluetoothPermission;
  final String? error;

  bool get hasError => error != null;

  ReceiveState copyWith({
    bool? isAdvertising,
    bool? bluetoothEnabled,
    bool? hasBluetoothPermission,
    String? error,
    bool clearError = false,
  }) =>
      ReceiveState(
        isAdvertising: isAdvertising ?? this.isAdvertising,
        bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
        hasBluetoothPermission:
            hasBluetoothPermission ?? this.hasBluetoothPermission,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Notifier for the receive screen.
///
/// Starts BLE advertising (receiver role) and exposes advertising + BT state.
///
/// Bug-3 fix: a boolean [_isStarting] flag prevents concurrent [startReceiving]
/// calls from spawning multiple advertising sessions before the first one has
/// reported its status back through [_statusSub].
///
/// Bug-1 fix: [_deviceName] is read from [deviceNameProvider] fresh on every
/// [startReceiving] call so that the persisted name (from Settings) is always
/// used, even if it was changed since the provider was constructed.
class ReceiveNotifier extends StateNotifier<ReceiveState> {
  ReceiveNotifier(this._ref) : super(const ReceiveState());

  final Ref _ref;

  /// The active advertising repository.  Null when not advertising.
  DiscoveryRepositoryImpl? _repo;
  StreamSubscription<DiscoveryStatus>? _statusSub;

  /// Prevents concurrent startReceiving() calls from starting multiple
  /// BLE advertising sessions (Bug 3 fix).
  bool _isStarting = false;

  /// Start BLE advertising.
  ///
  /// Idempotent — silently returns if already advertising or already starting.
  /// Always stops any existing session first so that a device-name change
  /// (Bug 1) is picked up on the next call.
  Future<void> startReceiving() async {
    // Guard: already advertising or start in progress.
    if (state.isAdvertising || _isStarting) {
      debugPrint(
        '[EtherSynapse] ReceiveNotifier.startReceiving() — already '
        '${state.isAdvertising ? "advertising" : "starting"}, skip.',
      );
      return;
    }

    _isStarting = true;

    // Stop any zombie session before creating a fresh one.
    // This ensures the device name from Settings is always current (Bug 1).
    await _stopSession();

    // Read device name live from the settings-backed provider (Bug 1 fix).
    final deviceName = _ref.read(deviceNameProvider);
    debugPrint(
      '[EtherSynapse] ReceiveNotifier.startReceiving() '
      '— deviceName: "$deviceName"',
    );

    _repo = DiscoveryRepositoryImpl(
      deviceName: deviceName,
      role: DeviceRole.receiver,
    );

    try {
      await _repo!.startDiscovery();
      _statusSub = _repo!.service.statusStream.listen(_onStatus);
    } catch (e) {
      debugPrint('[EtherSynapse] ReceiveNotifier start error: $e');
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
    } finally {
      _isStarting = false;
    }
  }

  /// Stop BLE advertising.
  Future<void> stopReceiving() async {
    _isStarting = false;
    await _stopSession();
    if (mounted) {
      state = state.copyWith(isAdvertising: false, clearError: true);
    }
  }

  Future<void> _stopSession() async {
    await _statusSub?.cancel();
    _statusSub = null;
    await _repo?.stopDiscovery();
    _repo?.dispose();
    _repo = null;
  }

  void _onStatus(DiscoveryStatus status) {
    if (!mounted) return;
    state = state.copyWith(
      isAdvertising: status.isAdvertising,
      bluetoothEnabled: status.bluetoothEnabled,
    );
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _repo?.dispose();
    super.dispose();
  }
}

final receiveProvider =
    StateNotifierProvider.autoDispose<ReceiveNotifier, ReceiveState>((ref) {
  return ReceiveNotifier(ref);
});
