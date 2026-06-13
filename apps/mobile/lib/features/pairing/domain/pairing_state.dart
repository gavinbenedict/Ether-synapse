import 'package:flutter/foundation.dart';

import '../../../shared/models/peer_device.dart';
import '../../../services/pairing_service.dart';

/// Domain state for the pairing feature.
///
/// Immutable snapshot updated by [PairingNotifier] as GATT and bridge
/// events arrive.
@immutable
final class PairingState {
  const PairingState({
    this.peer,
    this.status = PairingStatus.idle,
    this.pin,
    this.endpointAddress,
    this.error,
  });

  /// The peer device being paired with. `null` before pairing begins.
  final PeerDevice? peer;

  /// Current pairing lifecycle status.
  final PairingStatus status;

  /// 6-digit PIN string returned by the Rust core. `null` until derived.
  ///
  /// Flutter displays this value only — it does not process or store it.
  final String? pin;

  /// QUIC endpoint address returned after confirmation. Opaque string.
  final String? endpointAddress;

  /// Human-readable error description. Must not contain key material.
  final String? error;

  // ── Convenience ───────────────────────────────────────────────────

  bool get isPinReady => pin != null && pin!.isNotEmpty;
  bool get hasError => error != null;
  bool get isPaired => status == PairingStatus.confirmed && endpointAddress != null;

  /// Formatted PIN with a space in the middle for readability.
  /// e.g. "042817" → "042 817"
  String? get formattedPin {
    if (pin == null || pin!.length != 6) return pin;
    return '${pin!.substring(0, 3)} ${pin!.substring(3)}';
  }

  PairingState copyWith({
    PeerDevice? peer,
    PairingStatus? status,
    String? pin,
    String? endpointAddress,
    String? error,
    bool clearError = false,
    bool clearPin = false,
  }) {
    return PairingState(
      peer: peer ?? this.peer,
      status: status ?? this.status,
      pin: clearPin ? null : (pin ?? this.pin),
      endpointAddress: endpointAddress ?? this.endpointAddress,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairingState &&
          other.peer == peer &&
          other.status == status &&
          other.pin == pin &&
          other.endpointAddress == endpointAddress &&
          other.error == error;

  @override
  int get hashCode => Object.hash(peer, status, pin, endpointAddress, error);
}
