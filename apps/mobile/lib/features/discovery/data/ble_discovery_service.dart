import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/peer_device.dart';
import '../../../services/discovery_service.dart';
import 'ble_advertisement_codec.dart';

/// Concrete implementation of [DiscoveryService] and [DiscoveryRepository]
/// for the Android BLE stack.
///
/// Responsibilities:
///   - Requests all necessary BLE permissions before starting.
///   - Starts BLE advertising via [FlutterBlePeripheral] so that
///     remote devices can discover this device.
///   - Scans for peers via [FlutterReactiveBle].
///   - Decodes manufacturer-specific data using [BleAdvertisementCodec].
///   - Merges, deduplicates, and expires stale peers.
///   - Emits a [List<PeerDevice>] snapshot every time the peer set changes.
///
/// Thread safety: all mutable state is accessed only from async callbacks
/// on the same event loop; no explicit locking is required.
class BleSynapseDiscoveryService implements DiscoveryService {
  BleSynapseDiscoveryService({
    required String deviceName,
    required PeerPlatform localPlatform,
  })  : _deviceName = deviceName,
        _localPlatform = localPlatform,
        _sessionId = BleAdvertisementCodec.generateSessionId();

  final String _deviceName;
  final PeerPlatform _localPlatform;
  final int _sessionId;

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  // Scan subscription from flutter_reactive_ble.
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  // Advertising state.
  bool _isAdvertising = false;

  // Peer state: keyed by peer ID (session ID hex string).
  final Map<String, _PeerEntry> _peers = {};

  // Output stream controller — broadcast so multiple listeners can attach.
  final StreamController<List<PeerDevice>> _peersController =
      StreamController<List<PeerDevice>>.broadcast();

  // Expiry timer — ticks every 5 seconds to remove stale peers.
  Timer? _expiryTimer;

  bool _active = false;

  // ── DiscoveryService interface ────────────────────────────────────

  @override
  bool get isActive => _active;

  @override
  Stream<PeerDevice> get peerStream =>
      // The DiscoveryService interface emits individual PeerDevice events.
      // We adapt our internal List<PeerDevice> stream to emit each peer
      // individually on every list update.
      _peersController.stream.expand((peers) => peers);

  /// Also exposed for DiscoveryRepository use — emits full peer list snapshots.
  Stream<List<PeerDevice>> get peersStream => _peersController.stream;

  @override
  Future<void> startDiscovery() async {
    if (_active) return;

    await _requestPermissions();

    _active = true;

    // Start advertising this device so peers can find it.
    await _startAdvertising();

    // Start scanning for peers.
    _startScanning();

    // Start the expiry timer.
    _expiryTimer = Timer.periodic(const Duration(seconds: 5), (_) => _expirePeers());
  }

  @override
  Future<void> stopDiscovery() async {
    if (!_active) return;
    _active = false;

    _expiryTimer?.cancel();
    _expiryTimer = null;

    await _scanSubscription?.cancel();
    _scanSubscription = null;

    await _stopAdvertising();

    _peers.clear();
    _emitPeers();
  }

  // ── Permission handling ───────────────────────────────────────────

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;

    // Determine which permissions are needed based on Android version.
    // permission_handler uses the Android SDK version under the hood.
    final List<Permission> permissions;

    if (await _isAndroid12OrHigher()) {
      permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ];
    } else {
      permissions = [
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ];
    }

    final statuses = await permissions.request();

    final denied = statuses.entries
        .where((e) => !e.value.isGranted)
        .map((e) => e.key.toString())
        .toList();

    if (denied.isNotEmpty) {
      throw DiscoveryException(
        'Required Bluetooth permissions were denied: ${denied.join(', ')}. '
        'Open Settings and grant the permissions to use discovery.',
      );
    }
  }

  Future<bool> _isAndroid12OrHigher() async {
    if (!Platform.isAndroid) return false;
    // Permission.bluetoothScan exists as a runtime permission on API 31+.
    // We check its status; on API < 31 the result will always be granted
    // because the permission is install-time only.
    final status = await Permission.bluetoothScan.status;
    // If the permission is not restricted (i.e. it's a real runtime permission),
    // we're on Android 12+.
    return !status.isRestricted;
  }

  // ── Advertising ───────────────────────────────────────────────────

  Future<void> _startAdvertising() async {
    try {
      final isSupported = await _peripheral.isSupported;
      if (!isSupported) {
        // Device does not support BLE peripheral mode — skip advertising.
        // This device can still discover others.
        debugPrint('[EtherSynapse] BLE peripheral mode not supported on this device');
        return;
      }

      final payload = BleAdvertisementCodec.encode(
        deviceName: _deviceName,
        platform: _localPlatform,
        sessionId: _sessionId,
      );

      final advertiseData = AdvertiseData(
        // Service UUID is reserved — see docs/protocol/ble-discovery.md.
        // We advertise without a service UUID and use manufacturer data
        // as the primary identification mechanism.
        serviceUuid: '',
        manufacturerId: AppConstants.bleCompanyId,
        manufacturerData: payload,
        includeDeviceName: false, // We encode the name in payload ourselves.
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
        connectable: false, // Discovery-only; connection happens over QUIC.
        timeout: 0, // Advertise indefinitely.
      );

      await _peripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      _isAdvertising = true;
      debugPrint('[EtherSynapse] BLE advertising started (sessionId: '
          '${_sessionId.toRadixString(16).padLeft(8, '0')})');
    } catch (e) {
      debugPrint('[EtherSynapse] BLE advertising failed: $e');
      // Non-fatal — the device can still discover peers even if it cannot advertise.
    }
  }

  Future<void> _stopAdvertising() async {
    if (!_isAdvertising) return;
    try {
      await _peripheral.stop();
      _isAdvertising = false;
      debugPrint('[EtherSynapse] BLE advertising stopped');
    } catch (e) {
      debugPrint('[EtherSynapse] BLE advertising stop error: $e');
    }
  }

  // ── Scanning ──────────────────────────────────────────────────────

  void _startScanning() {
    // Scan for all devices — we filter by manufacturer data in the handler.
    // flutter_reactive_ble will call onError if BLE is off or permissions denied.
    _scanSubscription = _ble
        .scanForDevices(
          withServices: const [],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          _onDeviceDiscovered,
          onError: _onScanError,
        );

    debugPrint('[EtherSynapse] BLE scanning started');
  }

  void _onDeviceDiscovered(DiscoveredDevice device) {
    // flutter_reactive_ble exposes manufacturer-specific data in
    // serviceData and manufacturerData fields.
    final mfgData = device.manufacturerData;
    if (mfgData.isEmpty) return;

    // flutter_reactive_ble strips the company ID prefix from manufacturer data;
    // what we receive starts at our byte 0 (protocol version).
    // However, on some Android versions it may include the company ID bytes.
    // We try decoding at offset 0 first, then offset 2 as a fallback.
    PeerDevice? peer = BleAdvertisementCodec.decode(
      data: mfgData,
      bleDeviceId: device.id,
      rssi: device.rssi,
    );

    // Fallback: try skipping 2-byte company ID prefix.
    if (peer == null && mfgData.length > 2) {
      peer = BleAdvertisementCodec.decode(
        data: mfgData.sublist(2),
        bleDeviceId: device.id,
        rssi: device.rssi,
      );
    }

    if (peer == null) return;

    // Ignore self-advertisements (same session ID).
    final selfId = _sessionId.toRadixString(16).padLeft(8, '0');
    if (peer.id == selfId) return;

    // Upsert the peer with a fresh last-seen timestamp.
    final existing = _peers[peer.id];
    _peers[peer.id] = _PeerEntry(
      peer: existing != null
          ? existing.peer.copyWith(
              signalStrength: peer.signalStrength,
              name: peer.name,
            )
          : peer,
      lastSeen: DateTime.now(),
    );

    _emitPeers();
  }

  void _onScanError(Object error) {
    debugPrint('[EtherSynapse] BLE scan error: $error');
    _peersController.addError(
      DiscoveryException('BLE scan failed', cause: error),
    );
  }

  // ── Peer expiry ───────────────────────────────────────────────────

  void _expirePeers() {
    final cutoff = DateTime.now().subtract(
      Duration(seconds: AppConstants.bleDiscoveryScanTimeoutSeconds),
    );

    final before = _peers.length;
    _peers.removeWhere((_, entry) => entry.lastSeen.isBefore(cutoff));

    if (_peers.length != before) {
      debugPrint('[EtherSynapse] Expired ${before - _peers.length} stale peer(s)');
      _emitPeers();
    }
  }

  // ── Stream emission ───────────────────────────────────────────────

  void _emitPeers() {
    if (_peersController.isClosed) return;
    final snapshot = _peers.values.map((e) => e.peer).toList(growable: false);
    _peersController.add(snapshot);
  }

  /// Disposes resources. Call when the owning provider is disposed.
  void dispose() {
    stopDiscovery();
    _peersController.close();
  }
}

/// Internal record pairing a [PeerDevice] with its last-seen timestamp
/// for expiry tracking.
class _PeerEntry {
  const _PeerEntry({required this.peer, required this.lastSeen});

  final PeerDevice peer;
  final DateTime lastSeen;
}
