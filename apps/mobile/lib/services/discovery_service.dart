import '../shared/models/peer_device.dart';

/// Contract for peer discovery.
///
/// Implementations:
///   - BLE: Flutter platform channel implementation (per runner).
///   - mDNS: Rust core via flutter_rust_bridge (see bridge/src/api.rs).
///
/// Both implementations emit to the same [DiscoveryService] interface so that
/// the discovery Riverpod provider merges results into one peer list.
///
/// DO NOT add BLE or mDNS implementation here.
/// DO NOT add network I/O here.
abstract interface class DiscoveryService {
  /// Start advertising this device and scanning for peers.
  ///
  /// Throws [DiscoveryException] if the platform denies permissions.
  Future<void> startDiscovery();

  /// Stop advertising and scanning. Clears the active peer list.
  Future<void> stopDiscovery();

  /// Emits discovered peers. The stream remains open until [stopDiscovery].
  ///
  /// May emit duplicate peers; deduplication is the consumer's responsibility.
  Stream<PeerDevice> get peerStream;

  /// Returns `true` if discovery is currently active.
  bool get isActive;
}

/// Thrown when a [DiscoveryService] operation fails.
final class DiscoveryException implements Exception {
  const DiscoveryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'DiscoveryException: $message${cause != null ? ' ($cause)' : ''}';
}
