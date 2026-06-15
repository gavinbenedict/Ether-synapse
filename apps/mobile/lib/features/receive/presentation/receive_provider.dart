import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../discovery/data/discovery_repository.dart';
import '../../discovery/data/ble_discovery_service.dart';
import '../../../shared/models/device_capabilities.dart';
import '../../../shared/models/device_role.dart';
import '../../../providers/app_providers.dart';
import '../../../services/capability_service.dart';
import '../../../services/gatt_service.dart';

/// State for the receive screen.
@immutable
class ReceiveState {
  const ReceiveState({
    this.isAdvertising = false,
    this.bluetoothEnabled = true,
    this.hasBluetoothPermission = true,
    this.error,
    this.senderCapabilities,
    this.localCapabilities,
    this.navigateToTransfer = false,
  });

  final bool isAdvertising;
  final bool bluetoothEnabled;
  final bool hasBluetoothPermission;
  final String? error;

  /// Capabilities received from the sender via GATT write.
  /// Non-null once a sender has connected and exchanged capabilities.
  final DeviceCapabilities? senderCapabilities;

  /// Local capabilities detected during advertising setup.
  /// Contains localIpAddress used as the TCP server host.
  final DeviceCapabilities? localCapabilities;

  /// Becomes true once a sender's capabilities arrive and the TCP server
  /// should start. The ReceiveScreen watches this to navigate.
  final bool navigateToTransfer;

  bool get hasError => error != null;

  /// The local IP address to use as the TCP server bind address / advertised host.
  String? get localIpAddress => localCapabilities?.localIpAddress;

  ReceiveState copyWith({
    bool? isAdvertising,
    bool? bluetoothEnabled,
    bool? hasBluetoothPermission,
    String? error,
    bool clearError = false,
    DeviceCapabilities? senderCapabilities,
    DeviceCapabilities? localCapabilities,
    bool? navigateToTransfer,
  }) =>
      ReceiveState(
        isAdvertising: isAdvertising ?? this.isAdvertising,
        bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
        hasBluetoothPermission:
            hasBluetoothPermission ?? this.hasBluetoothPermission,
        error: clearError ? null : (error ?? this.error),
        senderCapabilities: senderCapabilities ?? this.senderCapabilities,
        localCapabilities: localCapabilities ?? this.localCapabilities,
        navigateToTransfer: navigateToTransfer ?? this.navigateToTransfer,
      );
}

/// Notifier for the receive screen.
///
/// Responsibilities:
///   1. Starts BLE advertising (receiver role) and exposes advertising state.
///   2. Subscribes to [GattService.onSenderCapabilitiesReceived] so that when
///      the Sender writes its capabilities, the Receiver is notified and can
///      navigate to TransferScreen(isHost: true) to start the TCP server.
///   3. Detects local capabilities (including localIpAddress) so the IP can
///      be passed to TransferScreen as the host address.
///
/// Bug-3 fix: a boolean [_isStarting] flag prevents concurrent [startReceiving]
/// calls from spawning multiple advertising sessions.
///
/// Bug-1 fix: [_deviceName] is read from [deviceNameProvider] fresh on every
/// [startReceiving] call so the persisted name from Settings is always used.
class ReceiveNotifier extends StateNotifier<ReceiveState> {
  ReceiveNotifier(this._ref) : super(const ReceiveState());

  final Ref _ref;

  /// The active advertising repository. Null when not advertising.
  DiscoveryRepositoryImpl? _repo;
  StreamSubscription<DiscoveryStatus>? _statusSub;
  StreamSubscription<DeviceCapabilities>? _gattSub;

  final _capabilityService = CapabilityService();

  /// Prevents concurrent startReceiving() calls from starting multiple
  /// BLE advertising sessions.
  bool _isStarting = false;

  // ── Public API ─────────────────────────────────────────────────────

  /// Start BLE advertising.
  ///
  /// Idempotent — silently returns if already advertising or already starting.
  /// Stops any existing session first so device-name changes are always picked up.
  Future<void> startReceiving() async {
    debugPrint(
      '[EtherSynapse] ReceiveNotifier.startReceiving() '
      '— state: ${state.isAdvertising}',
    );

    if (state.isAdvertising || _isStarting) {
      debugPrint(
        '[EtherSynapse] ReceiveNotifier.startReceiving() — already '
        '${state.isAdvertising ? "advertising" : "starting"}, skip.',
      );
      return;
    }

    _isStarting = true;

    // Stop any zombie session before creating a fresh one.
    await _stopSession();

    // Read device name live from the settings-backed provider (Bug 1 fix).
    final deviceName = _ref.read(deviceNameProvider);
    debugPrint(
      '[EtherSynapse] ReceiveNotifier.startReceiving() '
      '— deviceName: "$deviceName"',
    );

    // Detect local capabilities (specifically localIpAddress) so we can
    // pass the correct host IP to TransferScreen when a sender connects.
    try {
      final caps = await _capabilityService.detectLocalCapabilities(
        displayName: deviceName,
      );
      debugPrint(
        '[EtherSynapse] ReceiveNotifier local capabilities detected: $caps',
      );
      if (mounted) {
        state = state.copyWith(localCapabilities: caps);
      }
    } catch (e) {
      debugPrint('[EtherSynapse] ReceiveNotifier capability detection error: $e');
    }

    // Subscribe to GATT: when a sender writes its capabilities, this fires.
    // This is the trigger to navigate to TransferScreen on the receiver.
    _gattSub?.cancel();
    _gattSub = GattService.onSenderCapabilitiesReceived.listen(
      (senderCaps) {
        debugPrint(
          '[EtherSynapse] ReceiveNotifier: Sender capabilities received via GATT '
          '— sender: ${senderCaps.deviceName}, '
          'localIp: ${state.localIpAddress}',
        );
        if (mounted) {
          state = state.copyWith(
            senderCapabilities: senderCaps,
            navigateToTransfer: true,
          );
        }
      },
      onError: (Object e) {
        debugPrint('[EtherSynapse] ReceiveNotifier GATT stream error: $e');
      },
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
    debugPrint('[EtherSynapse] ReceiveNotifier.stopReceiving()');
    _isStarting = false;
    await _stopSession();
    if (mounted) {
      state = state.copyWith(isAdvertising: false, clearError: true);
    }
  }

  /// Called from ReceiveScreen after it has initiated navigation to
  /// TransferScreen, so the flag is not re-triggered on a rebuild.
  void clearNavigateToTransfer() {
    if (mounted) {
      state = state.copyWith(navigateToTransfer: false);
    }
  }

  // ── Private ───────────────────────────────────────────────────────

  Future<void> _stopSession() async {
    debugPrint(
      '[EtherSynapse] ReceiveNotifier._stopSession() '
      '— repo active: ${_repo != null}',
    );
    await _statusSub?.cancel();
    _statusSub = null;
    await _gattSub?.cancel();
    _gattSub = null;
    await _repo?.stopDiscovery();
    _repo?.dispose();
    _repo = null;
  }

  void _onStatus(DiscoveryStatus status) {
    if (!mounted) {
      debugPrint(
        '[EtherSynapse] ReceiveNotifier._onStatus() ignored — notifier unmounted',
      );
      return;
    }
    state = state.copyWith(
      isAdvertising: status.isAdvertising,
      bluetoothEnabled: status.bluetoothEnabled,
    );
  }

  @override
  void dispose() {
    debugPrint('[EtherSynapse] ReceiveNotifier.dispose()');
    _statusSub?.cancel();
    _gattSub?.cancel();
    _repo?.dispose();
    super.dispose();
  }
}

final receiveProvider =
    StateNotifierProvider.autoDispose<ReceiveNotifier, ReceiveState>((ref) {
  return ReceiveNotifier(ref);
});
