import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/peer_device.dart';
import '../../../shared/models/device_capabilities.dart';
import '../../../shared/models/device_role.dart';
import '../../../services/discovery_service.dart';
import '../../../services/capability_service.dart';
import '../../../services/gatt_service.dart';
import 'ble_advertisement_codec.dart';

/// Concrete implementation of [DiscoveryService] for the Android BLE stack.
///
/// Responsibilities:
///   - Requests all necessary BLE permissions before starting.
///   - For [DeviceRole.receiver]: detects local capabilities via
///     [CapabilityService] and encodes them into the advertisement payload
///     (protocol v2) so senders receive real capability data without GATT.
///   - Starts BLE advertising via [FlutterBlePeripheral].
///   - Scans for peers via [FlutterReactiveBle].
///   - Decodes manufacturer-specific data using [BleAdvertisementCodec].
///   - Merges, deduplicates, and expires stale peers.
///   - Emits a [List<PeerDevice>] snapshot every time the peer set changes.
///   - Emits advertising and scanning state changes for the UI.
///
/// Thread safety: all mutable state is accessed only from async callbacks
/// on the same event loop; no explicit locking is required.
class BleSynapseDiscoveryService implements DiscoveryService {
  BleSynapseDiscoveryService({
    required String deviceName,
    required PeerPlatform localPlatform,
    required DeviceRole role,
  })  : _deviceName = deviceName,
        _localPlatform = localPlatform,
        _role = role,
        _sessionId = BleAdvertisementCodec.generateSessionId();

  final String _deviceName;
  final PeerPlatform _localPlatform;
  final DeviceRole _role;
  final int _sessionId;

  static bool _isGlobalBleOperationPending = false;
  static final _peripheral = FlutterBlePeripheral();
  static final _ble = FlutterReactiveBle();
  final CapabilityService _capabilityService = CapabilityService();
  final GattService _gattService = GattService();

  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  bool _isAdvertising = false;
  bool _isScanning = false;
  bool _bluetoothEnabled = true;
  bool _active = false;

  /// Local capabilities detected before advertising starts.
  /// Null until detection completes (or if role is sender).
  DeviceCapabilities? _localCapabilities;

  final Map<String, _PeerEntry> _peers = {};

  final StreamController<List<PeerDevice>> _peersController =
      StreamController<List<PeerDevice>>.broadcast();

  final StreamController<DiscoveryStatus> _statusController =
      StreamController<DiscoveryStatus>.broadcast();

  Timer? _expiryTimer;

  // ── Public stream accessors ───────────────────────────────────────

  Stream<DiscoveryStatus> get statusStream => _statusController.stream;
  bool get isAdvertising => _isAdvertising;
  bool get isScanning => _isScanning;

  @override
  Stream<List<PeerDevice>> get peersStream => _peersController.stream;

  @override
  bool get isActive => _active;

  // ── Lifecycle ─────────────────────────────────────────────────────

  @override
  Future<void> startDiscovery() async {
    if (_active) return;
    _active = true;

    debugPrint(
      '[EtherSynapse] BleSynapseDiscoveryService.startDiscovery() '
      '— role: ${_role.name}, '
      'device: "$_deviceName", '
      'sessionId: ${_sessionId.toRadixString(16).padLeft(8, '0')}',
    );

    await _requestPermissions();

    // Start expiry timer (fires every 5 s).
    _expiryTimer = Timer.periodic(const Duration(seconds: 5), (_) => _expirePeers());

    if (_role == DeviceRole.receiver) {
      // Detect real local capabilities BEFORE building the advertisement.
      // These capabilities are encoded into the v2 payload so senders get
      // actual device data from the scan result — no GATT or estimation.
      await _detectAndAdvertise();
    } else {
      // Sender: scan only, no advertising.
      _startScanning();
    }
  }

  /// Detects local capabilities then starts advertising (receiver path).
  Future<void> _detectAndAdvertise() async {
    try {
      _localCapabilities = await _capabilityService.detectLocalCapabilities(
        displayName: _deviceName,
      );
      debugPrint(
        '[EtherSynapse] Local capabilities detected: $_localCapabilities',
      );
      
      // Start GATT Server with full local capabilities JSON payload
      if (_localCapabilities != null) {
        final success = await _gattService.startServer(_localCapabilities!);
        debugPrint('[EtherSynapse] GATT Server started: $success');
      }
    } catch (e) {
      debugPrint('[EtherSynapse] Capability detection error (non-fatal): $e');
      // Proceed with null capabilities — codec will use zero flags.
    }
    await _startAdvertising();
  }

  @override
  Future<void> stopDiscovery() async {
    if (!_active) return;
    debugPrint('[EtherSynapse] BleSynapseDiscoveryService.stopDiscovery() start');
    _active = false;

    _expiryTimer?.cancel();
    _expiryTimer = null;

    if (_role == DeviceRole.receiver) {
      await _gattService.stopServer();
    }

    await _stopScanning();
    await _stopAdvertising();

    _peers.clear();
    _localCapabilities = null;

    debugPrint('[EtherSynapse] BleSynapseDiscoveryService stopped');
  }

  // ── Permissions ───────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    final List<Permission> permissions;

    if (Platform.isAndroid && await _isAndroid12OrHigher()) {
      permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ];
      debugPrint('[EtherSynapse] Requesting Android 12+ BLE permissions');
    } else {
      permissions = [
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ];
      debugPrint('[EtherSynapse] Requesting legacy BLE permissions');
    }

    final statuses = await permissions.request();

    for (final entry in statuses.entries) {
      debugPrint(
        '[EtherSynapse] Permission ${entry.key}: '
        '${entry.value.isGranted ? "GRANTED" : "DENIED"}',
      );
    }

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

    debugPrint('[EtherSynapse] All BLE permissions granted');
  }

  Future<bool> _isAndroid12OrHigher() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.bluetoothScan.status;
    return !status.isRestricted;
  }

  // ── Advertising ───────────────────────────────────────────────────

  Future<void> _startAdvertising() async {
    try {
      final isSupported = await _peripheral.isSupported;
      if (!isSupported) {
        debugPrint(
          '[EtherSynapse] BLE peripheral mode not supported on this device '
          '— skipping advertising',
        );
        return;
      }

      // v2 payload: real capabilities encoded if available.
      final payload = BleAdvertisementCodec.encode(
        displayName: _deviceName,
        platform: _localPlatform,
        sessionId: _sessionId,
        capabilities: _localCapabilities,
      );

      final advertiseData = AdvertiseData(
        serviceUuid: null, // null = omit; '' = crash (IllegalArgumentException)
        manufacturerId: AppConstants.bleCompanyId,
        manufacturerData: payload,
        includeDeviceName: false,
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
        connectable: true,
        timeout: 0,
      );

      while (_isGlobalBleOperationPending) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      _isGlobalBleOperationPending = true;

      debugPrint(
        '[EtherSynapse] Starting BLE advertising '
        '(sessionId: ${_sessionId.toRadixString(16).padLeft(8, '0')}, '
        'device: "$_deviceName", '
        'caps: $_localCapabilities, '
        'payloadBytes: ${payload.length})',
      );

      await _peripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      _isAdvertising = true;
      _emitStatus();
      debugPrint('[EtherSynapse] BLE advertising STARTED successfully');
    } catch (e) {
      debugPrint('[EtherSynapse] Failed to start BLE advertising: $e');
      rethrow;
    } finally {
      _isGlobalBleOperationPending = false;
    }
  }

  Future<void> _stopAdvertising() async {
    if (!_isAdvertising) {
      debugPrint('[EtherSynapse] BleSynapseDiscoveryService._stopAdvertising() - not advertising, skipping');
      return;
    }
    
    while (_isGlobalBleOperationPending) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isGlobalBleOperationPending = true;

    try {
      debugPrint('[EtherSynapse] BleSynapseDiscoveryService._stopAdvertising() calling peripheral.stop()');
      await _peripheral.stop();
      _isAdvertising = false;
      _emitStatus();
      debugPrint('[EtherSynapse] BLE advertising STOPPED');
    } catch (e) {
      debugPrint('[EtherSynapse] Failed to stop BLE advertising: $e');
    } finally {
      _isGlobalBleOperationPending = false;
    }
  }

  // ── Scanning ──────────────────────────────────────────────────────

  void _startScanning() {
    _scanSubscription = _ble
        .scanForDevices(
          withServices: const [],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          _onDeviceDiscovered,
          onError: _onScanError,
        );

    _isScanning = true;
    _emitStatus();
    debugPrint('[EtherSynapse] BLE scanning STARTED');
  }

  Future<void> _stopScanning() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    _emitStatus();
    debugPrint('[EtherSynapse] BLE scanning STOPPED');
  }

  void _onDeviceDiscovered(DiscoveredDevice device) {
    final mfgData = device.manufacturerData;
    if (mfgData.isEmpty) return;

    // flutter_reactive_ble strips the company-ID prefix on most Android
    // versions. Try offset 0 first, fall back to offset 2.
    var result = BleAdvertisementCodec.decode(
      data: mfgData,
      bleDeviceId: device.id,
      rssi: device.rssi,
    );

    if (result.peer == null && mfgData.length > 2) {
      result = BleAdvertisementCodec.decode(
        data: mfgData.sublist(2),
        bleDeviceId: device.id,
        rssi: device.rssi,
      );
    }

    final peer = result.peer;
    if (peer == null) return;

    // Ignore self-advertisements (same session ID).
    final selfId = _sessionId.toRadixString(16).padLeft(8, '0');
    if (peer.id == selfId) return;

    final isNewPeer = !_peers.containsKey(peer.id);
    final existing = _peers[peer.id];

    // Merge — keep previously decoded capabilities if the new decode
    // returned null (e.g. a v1 peer or truncated packet on retry).
    final mergedCaps = peer.remoteCapabilities ??
        existing?.peer.remoteCapabilities;

    // Stamp the decoded capabilities with the peer's actual device name.
    final namedCaps = mergedCaps?.copyWith(deviceName: peer.name);

    _peers[peer.id] = _PeerEntry(
      peer: existing != null
          ? existing.peer.copyWith(
              signalStrength: peer.signalStrength,
              name: peer.name,
              bleAddress: peer.bleAddress,
              remoteCapabilities: namedCaps,
            )
          : peer.copyWith(remoteCapabilities: namedCaps),
      lastSeen: DateTime.now(),
    );

    if (isNewPeer) {
      debugPrint(
        '[EtherSynapse] Device DISCOVERED: '
        'id=${peer.id}, name="${peer.name}", '
        'platform=${peer.platform}, rssi=${peer.signalStrength} dBm, '
        'caps=$namedCaps',
      );
    }

    _emitPeers();
  }

  void _onScanError(Object error) {
    debugPrint('[EtherSynapse] BLE scan ERROR: $error');
    _bluetoothEnabled = false;
    _isScanning = false;
    _emitStatus();
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
    final expired = _peers.entries
        .where((e) => e.value.lastSeen.isBefore(cutoff))
        .map((e) => e.key)
        .toList();

    for (final id in expired) {
      final name = _peers[id]?.peer.name ?? id;
      _peers.remove(id);
      debugPrint('[EtherSynapse] Device LOST (timeout): id=$id, name="$name"');
    }

    if (_peers.length != before) _emitPeers();
  }

  // ── Stream emission ───────────────────────────────────────────────

  void _emitPeers() {
    if (_peersController.isClosed) return;
    _peersController.add(
      _peers.values.map((e) => e.peer).toList(growable: false),
    );
  }

  void _emitStatus() {
    if (_statusController.isClosed) return;
    _statusController.add(DiscoveryStatus(
      isAdvertising: _isAdvertising,
      isScanning: _isScanning,
      bluetoothEnabled: _bluetoothEnabled,
    ));
  }

  void dispose() {
    debugPrint('[EtherSynapse] BleSynapseDiscoveryService.dispose()');
    stopDiscovery();
    _peersController.close();
    _statusController.close();
  }
}

/// Status snapshot emitted by [BleSynapseDiscoveryService.statusStream].
class DiscoveryStatus {
  const DiscoveryStatus({
    required this.isAdvertising,
    required this.isScanning,
    required this.bluetoothEnabled,
  });

  final bool isAdvertising;
  final bool isScanning;
  final bool bluetoothEnabled;
}

/// Internal record pairing a [PeerDevice] with its last-seen timestamp.
class _PeerEntry {
  const _PeerEntry({required this.peer, required this.lastSeen});

  final PeerDevice peer;
  final DateTime lastSeen;
}
