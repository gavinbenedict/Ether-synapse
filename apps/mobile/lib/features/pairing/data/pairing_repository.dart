import '../../../shared/models/peer_device.dart';

/// Data layer for the pairing feature.
///
/// Owns the interface between the pairing Riverpod provider and the
/// platform BLE GATT layer. Opaque key bytes are passed through unchanged
/// to the Rust bridge — never interpreted here.
///
/// DO NOT add BLE GATT implementation here.
/// DO NOT add cryptographic logic here.
/// DO NOT call flutter_rust_bridge directly here.
abstract interface class PairingRepository {
  /// Begin the BLE GATT pairing handshake with [peer].
  ///
  /// Returns the 6-digit PIN string computed by the Rust core.
  /// Flutter must display this PIN for out-of-band visual verification.
  Future<String> initiatePairing(PeerDevice peer);

  /// Confirm that the user verified the PIN matches on both devices.
  ///
  /// Returns the QUIC endpoint address string (opaque, forwarded to Rust).
  Future<String> confirmPairing();

  /// Reject the pairing (PIN mismatch — user aborted).
  Future<void> rejectPairing();

  /// Abort any in-progress pairing and clean up resources.
  Future<void> cancel();
}
