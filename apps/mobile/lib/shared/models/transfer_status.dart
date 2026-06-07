/// Transfer lifecycle states for a [TransferJob].
///
/// These values mirror the events emitted by the Rust core
/// through the flutter_rust_bridge event stream. The mapping:
///
///   Rust event          → Dart [TransferStatus]
///   ─────────────────────────────────────────────
///   TransferOffer       → [offering]
///   TransferProgress    → [transferring]
///   TransferComplete    → [complete]
///   TransferError       → [error]
///
/// The [idle] state is a client-side initial value only;
/// it is never emitted by the Rust core.
enum TransferStatus {
  /// Initial state before any bridge event has been received.
  idle,

  /// The sender has offered a file; the receiver is deciding whether to accept.
  offering,

  /// Transfer is in progress — bytes are flowing.
  transferring,

  /// Transfer completed successfully. SHA-256 verified by Rust.
  complete,

  /// Transfer failed. See [TransferJob.errorMessage] for the reason.
  error;

  /// Human-readable label for display in the UI.
  String get label => switch (this) {
        TransferStatus.idle => 'Idle',
        TransferStatus.offering => 'Incoming',
        TransferStatus.transferring => 'Transferring',
        TransferStatus.complete => 'Complete',
        TransferStatus.error => 'Failed',
      };

  /// Whether this status represents an active (non-terminal) transfer.
  bool get isActive =>
      this == TransferStatus.offering || this == TransferStatus.transferring;
}
