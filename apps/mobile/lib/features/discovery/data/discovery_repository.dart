import 'dart:io';

import '../../../shared/models/peer_device.dart';
import '../../../services/discovery_service.dart';
import 'ble_discovery_service.dart';

/// Concrete implementation of [DiscoveryRepository].
///
/// Wraps [BleSynapseDiscoveryService] and exposes the merged, deduplicated
/// [Stream<List<PeerDevice>>] that the provider listens to.
///
/// On Android: uses BLE advertising + scanning via flutter_ble_peripheral
/// and flutter_reactive_ble.
///
/// On other platforms: returns an error stream until platform-specific
/// implementations are added in future milestones.
class DiscoveryRepositoryImpl {
  DiscoveryRepositoryImpl({
    required String deviceName,
  }) : _service = BleSynapseDiscoveryService(
          deviceName: deviceName,
          localPlatform: _detectLocalPlatform(),
        );

  final BleSynapseDiscoveryService _service;

  bool get isActive => _service.isActive;

  Future<void> startDiscovery() => _service.startDiscovery();

  Future<void> stopDiscovery() => _service.stopDiscovery();

  Stream<List<PeerDevice>> get peersStream => _service.peersStream;

  void dispose() => _service.dispose();

  static PeerPlatform _detectLocalPlatform() {
    if (Platform.isAndroid) return PeerPlatform.android;
    if (Platform.isIOS) return PeerPlatform.ios;
    if (Platform.isMacOS) return PeerPlatform.macos;
    if (Platform.isWindows) return PeerPlatform.windows;
    if (Platform.isLinux) return PeerPlatform.linux;
    return PeerPlatform.unknown;
  }
}
