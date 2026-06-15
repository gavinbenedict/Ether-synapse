import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/negotiation_state.dart';
import '../../../shared/models/peer_device.dart';
import '../../../features/send/presentation/send_provider.dart';
import '../../../providers/app_providers.dart';
import '../../../services/capability_service.dart';
import '../../../services/gatt_client_service.dart';
import '../../../services/transport_service.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

/// Drives the capability negotiation flow.
///
/// Phase 2 implementation:
///   1. Detect local capabilities via [CapabilityService].
///   2. Exchange capabilities using GATT (connect to peer's BLE MAC address).
///   3. Select best transport via [TransportService].
///   4. Emit [NegotiationPhase.complete] with a [TransportPlan].
class NegotiationNotifier extends StateNotifier<NegotiationState> {
  NegotiationNotifier(this._ref, this._peerId)
      : super(const NegotiationState());

  final Ref _ref;

  /// The ephemeral session-ID hex string (e.g. "03a188a7") used to look up
  /// the peer in the discovered list. NOT the BLE MAC address.
  final String _peerId;

  final _capService = CapabilityService();
  final _transportService = const TransportService();
  final _gattClient = GattClientService(ble: FlutterReactiveBle());

  Future<void> negotiate() async {
    if (state.phase != NegotiationPhase.detectingLocal) return;

    debugPrint('[EtherSynapse] NegotiationNotifier.negotiate() '
        '— peerId: $_peerId');

    try {
      // Step 1 — Detect local capabilities.
      final deviceName = _ref.read(deviceNameProvider); // this is displayName from settings
      final local = await _capService.detectLocalCapabilities(
        displayName: deviceName,
      );

      if (!mounted) return;
      debugPrint('[EtherSynapse] Local capabilities: $local');
      state = state.copyWith(
        phase: NegotiationPhase.exchangingCapabilities,
        localCapabilities: local,
      );

      // Step 2 — Find the peer in the discovered list and resolve its BLE MAC.
      final peers = _ref.read(sendProvider).receivers;
      final peer = peers.firstWhere(
        (p) => p.id == _peerId,
        orElse: () => PeerDevice(
          id: _peerId,
          name: 'Remote Device',
          platform: PeerPlatform.android,
        ),
      );

      // The GATT connection requires the actual BLE peripheral address (MAC),
      // NOT the session-ID. bleAddress is populated by BleAdvertisementCodec.
      final bleAddress = peer.bleAddress;
      if (bleAddress == null || bleAddress.isEmpty) {
        throw Exception(
          'Cannot initiate GATT: BLE MAC address is unavailable for peer '
          '"${peer.name}" (id: $_peerId). '
          'The peer may have been discovered without a valid advertisement.',
        );
      }

      debugPrint('[EtherSynapse] GATT connect start — peerId (session): $_peerId, '
          'bleAddress (MAC): $bleAddress, peerName: "${peer.name}"');

      // Step 3 — GATT exchange with 15-second timeout.
      final remote = await _gattClient
          .exchangeCapabilities(
            deviceId: bleAddress,
            localCapabilities: local,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
              'GATT negotiation timed out after 15 seconds. '
              'Ensure both devices have Bluetooth enabled and are nearby.',
            ),
          );

      debugPrint('[EtherSynapse] Remote capabilities (GATT): $remote');

      // Small artificial delay to show the "exchanging" phase in the UI.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // Step 4 — Select transport.
      final plan = _transportService.selectBestTransport(
        local: local,
        remote: remote,
      );

      debugPrint('[EtherSynapse] TransportPlan: $plan');

      state = state.copyWith(
        phase: NegotiationPhase.complete,
        remoteCapabilities: remote,
        transportPlan: plan,
      );
    } catch (e, st) {
      debugPrint('[EtherSynapse] NegotiationNotifier error: $e\n$st');
      if (mounted) {
        state = state.copyWith(
          phase: NegotiationPhase.failed,
          error: e.toString(),
        );
      }
    }
  }
}

/// Family provider — one instance per peerId.
final negotiationProvider = StateNotifierProvider.autoDispose.family<
    NegotiationNotifier, NegotiationState, String>((ref, peerId) {
  return NegotiationNotifier(ref, peerId);
});
