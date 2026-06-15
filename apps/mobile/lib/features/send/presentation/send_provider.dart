import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../discovery/data/discovery_repository.dart';
import '../../discovery/data/ble_discovery_service.dart';
import '../../../shared/models/device_role.dart';
import '../../../shared/models/peer_device.dart';
import '../../../providers/app_providers.dart';

/// State for the send screen.
@immutable
class SendState {
  const SendState({
    this.receivers = const [],
    this.isScanning = false,
    this.bluetoothEnabled = true,
    this.error,
    this.lastUpdated,
  });

  /// Discovered receivers currently advertising Ether Synapse payloads.
  final List<PeerDevice> receivers;

  final bool isScanning;
  final bool bluetoothEnabled;
  final String? error;
  final DateTime? lastUpdated;

  bool get hasReceivers => receivers.isNotEmpty;
  bool get hasError => error != null;

  /// Receivers sorted by signal strength (strongest first).
  List<PeerDevice> get sortedReceivers {
    final list = List<PeerDevice>.of(receivers);
    list.sort((a, b) {
      final sa = a.signalStrength ?? -999;
      final sb = b.signalStrength ?? -999;
      return sb.compareTo(sa);
    });
    return list;
  }

  SendState copyWith({
    List<PeerDevice>? receivers,
    bool? isScanning,
    bool? bluetoothEnabled,
    String? error,
    bool clearError = false,
    DateTime? lastUpdated,
  }) =>
      SendState(
        receivers: receivers ?? this.receivers,
        isScanning: isScanning ?? this.isScanning,
        bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
        error: clearError ? null : (error ?? this.error),
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

/// Notifier for the send screen.
///
/// Starts a sender-role BLE repository (scan only, no advertising).
/// Only devices that successfully decode as Ether Synapse receivers appear.
class SendNotifier extends StateNotifier<SendState> {
  SendNotifier(this._ref) : super(const SendState());

  final Ref _ref;
  DiscoveryRepositoryImpl? _repo;
  StreamSubscription<List<PeerDevice>>? _peersSub;
  StreamSubscription<DiscoveryStatus>? _statusSub;

  Future<void> startScanning() async {
    if (state.isScanning) return;

    debugPrint('[EtherSynapse] Sender scanning for receivers');

    final deviceName = _ref.read(deviceNameProvider);
    _repo = DiscoveryRepositoryImpl(
      deviceName: deviceName,
      role: DeviceRole.sender,
    );

    state = state.copyWith(isScanning: true, clearError: true);

    try {
      await _repo!.startDiscovery();

      _peersSub = _repo!.peersStream.listen(_onPeers, onError: _onError);
      _statusSub = _repo!.service.statusStream.listen(_onStatus);
    } catch (e) {
      debugPrint('[EtherSynapse] SendNotifier start error: $e');
      if (mounted) {
        state = state.copyWith(isScanning: false, error: e.toString());
      }
    }
  }

  /// Pauses the background BLE scan without clearing discovered receivers.
  /// Used before initiating a GATT connection to avoid stack conflicts.
  Future<void> pauseScanning() async {
    debugPrint('[EtherSynapse] SendNotifier.pauseScanning()');
    await _repo?.stopScanning();
  }

  Future<void> stopScanning() async {
    await _peersSub?.cancel();
    _peersSub = null;
    await _statusSub?.cancel();
    _statusSub = null;
    await _repo?.stopDiscovery();
    _repo = null;
    if (mounted) {
      state = state.copyWith(
        isScanning: false,
        receivers: const [],
        clearError: true,
      );
    }
  }

  void _onPeers(List<PeerDevice> peers) {
    if (!mounted) return;
    debugPrint('[EtherSynapse] Receiver discovered: ${peers.length} device(s)');
    state = state.copyWith(receivers: peers, lastUpdated: DateTime.now());
  }

  void _onStatus(DiscoveryStatus status) {
    if (!mounted) return;
    state = state.copyWith(
      isScanning: status.isScanning,
      bluetoothEnabled: status.bluetoothEnabled,
    );
  }

  void _onError(Object error) {
    if (!mounted) return;
    state = state.copyWith(isScanning: false, error: error.toString());
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    _statusSub?.cancel();
    _repo?.dispose();
    super.dispose();
  }
}

final sendProvider =
    StateNotifierProvider.autoDispose<SendNotifier, SendState>((ref) {
  return SendNotifier(ref);
});
