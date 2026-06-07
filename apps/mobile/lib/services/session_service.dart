/// Contract for QUIC session lifecycle management.
///
/// A session is created after pairing is confirmed and an endpoint address
/// is known. The session manages the QUIC connection and its state machine
/// (Idle → Pairing → Connecting → Established → Transferring → Closed).
///
/// All QUIC transport operations are performed by the Rust core.
/// Flutter observes session state changes via this service's [statusStream].
///
/// DO NOT add QUIC implementation here.
/// DO NOT add transport logic here.
/// DO NOT add key material handling here.
abstract interface class SessionService {
  /// Open a QUIC connection to the peer at [endpointAddress].
  ///
  /// [endpointAddress] is the opaque `<IP>:<port>` string received from the
  /// BLE GATT ENDPOINT characteristic. Flutter does not parse this value.
  ///
  /// Throws [SessionException] if the connection cannot be established.
  Future<void> connect(String endpointAddress);

  /// Close the current session and release all resources.
  ///
  /// Safe to call when no session is active (no-op).
  Future<void> disconnect();

  /// Emits session status changes.
  Stream<SessionStatus> get statusStream;

  /// The current session status (synchronous read).
  SessionStatus get currentStatus;

  /// The endpoint address of the connected peer, or `null` if not connected.
  String? get connectedEndpoint;
}

/// Session state machine values surfaced via [SessionService.statusStream].
///
/// Corresponds to the state machine documented in
/// docs/protocol/session-establishment.md.
enum SessionStatus {
  idle,
  pairing,
  connecting,
  established,
  transferring,
  closed,
}

/// Thrown when a [SessionService] operation fails.
final class SessionException implements Exception {
  const SessionException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'SessionException: $message${cause != null ? ' ($cause)' : ''}';
}
