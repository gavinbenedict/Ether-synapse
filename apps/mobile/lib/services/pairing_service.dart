import '../shared/models/peer_device.dart';

/// Contract for BLE-based peer pairing.
///
/// Pairing establishes a shared session key between two devices via
/// X25519 Diffie-Hellman. All cryptographic operations are delegated
/// to the Rust core via the bridge.
///
/// Flutter's role in pairing:
///   - Transport opaque bytes (public keys) over BLE GATT.
///   - Display the PIN string returned by Rust.
///   - Forward the user's accept/reject decision to Rust.
///
/// DO NOT add cryptographic logic here.
/// DO NOT add key material handling here.
/// DO NOT add BLE GATT implementation here.
abstract interface class PairingService {
  /// Initiate pairing with the given [peer].
  ///
  /// Returns a PIN string (6 digits, zero-padded) computed by the Rust core.
  /// Flutter must display this PIN for out-of-band user verification.
  ///
  /// Throws [PairingException] on GATT failure or timeout.
  Future<String> initiatePairing(PeerDevice peer);

  /// Accept the PIN (user confirmed it matches on both screens).
  ///
  /// Returns the QUIC endpoint address once the Rust core establishes
  /// the session. This address is an opaque string — do not parse it in Dart.
  Future<String> acceptPairing();

  /// Reject the PIN (user confirmed mismatch — abort pairing).
  Future<void> rejectPairing();

  /// Emits pairing state changes.
  Stream<PairingStatus> get statusStream;

  /// Cancel any in-progress pairing.
  Future<void> cancel();
}

/// Pairing status values surfaced via [PairingService.statusStream].
enum PairingStatus {
  idle,
  connecting,
  exchangingKeys,
  awaitingConfirmation,
  confirmed,
  rejected,
  failed,
}

/// Thrown when a [PairingService] operation fails.
final class PairingException implements Exception {
  const PairingException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PairingException: $message${cause != null ? ' ($cause)' : ''}';
}
