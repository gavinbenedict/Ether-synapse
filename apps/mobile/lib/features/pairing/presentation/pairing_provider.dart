import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/pairing_state.dart';
import '../../../shared/models/peer_device.dart';
import '../../../services/pairing_service.dart';

/// Riverpod [StateNotifier] for the pairing screen.
///
/// Responsibilities:
///   - Drives the BLE GATT handshake via the repository.
///   - Exposes PIN to the presentation layer for display.
///   - Forwards user accept/reject to the repository.
///   - Transitions state machine: idle → connecting → exchangingKeys
///     → awaitingConfirmation → confirmed | rejected | failed.
///
/// DO NOT add BLE or crypto logic here.
class PairingNotifier extends StateNotifier<PairingState> {
  PairingNotifier() : super(const PairingState());

  // TODO(impl): Inject PairingRepository via provider override.

  /// Begin pairing with [peer].
  Future<void> startPairing(PeerDevice peer) async {
    state = state.copyWith(
      peer: peer,
      status: PairingStatus.connecting,
      clearError: true,
      clearPin: true,
    );
    // TODO(impl): final pin = await _repository.initiatePairing(peer);
    // TODO(impl): state = state.copyWith(
    //   status: PairingStatus.awaitingConfirmation,
    //   pin: pin,
    // );
  }

  /// User confirmed PIN matches — proceed.
  Future<void> confirmPin() async {
    state = state.copyWith(status: PairingStatus.confirmed);
    // TODO(impl): final endpoint = await _repository.confirmPairing();
    // TODO(impl): state = state.copyWith(endpointAddress: endpoint);
  }

  /// User rejected PIN — abort.
  Future<void> rejectPin() async {
    // TODO(impl): await _repository.rejectPairing();
    state = state.copyWith(status: PairingStatus.rejected);
  }

  /// Cancel in-progress pairing.
  Future<void> cancel() async {
    // TODO(impl): await _repository.cancel();
    state = const PairingState();
  }

  void _onError(Object error) {
    state = state.copyWith(
      status: PairingStatus.failed,
      error: error.toString(),
    );
  }
}

/// Provider for [PairingNotifier].
///
/// Scoped to the pairing navigation route — disposed when the user
/// navigates away from the pairing screen.
final pairingProvider =
    StateNotifierProvider.autoDispose<PairingNotifier, PairingState>((ref) {
  return PairingNotifier();
});
