import '../../../shared/models/peer_device.dart';
import '../../../services/discovery_service.dart';

/// Data layer for the discovery feature.
///
/// Owns the interface between the discovery Riverpod provider and the
/// platform-specific [DiscoveryService] implementations (BLE platform channel
/// and Rust mDNS bridge).
///
/// DO NOT add BLE implementation here.
/// DO NOT add mDNS implementation here.
/// DO NOT add bridge calls here — those belong in the concrete [DiscoveryService].
abstract interface class DiscoveryRepository {
  /// Start discovery using all available backends.
  Future<void> startDiscovery();

  /// Stop discovery and clear the peer list.
  Future<void> stopDiscovery();

  /// Merged, deduplicated stream of discovered peers from all backends.
  ///
  /// BLE peers and mDNS peers are merged by the repository using the
  /// peer [PeerDevice.id] as the deduplication key.
  Stream<List<PeerDevice>> get peersStream;

  /// Whether discovery is currently active.
  bool get isActive;
}
