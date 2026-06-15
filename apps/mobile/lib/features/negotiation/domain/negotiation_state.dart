import 'package:flutter/foundation.dart';

import '../../../shared/models/device_capabilities.dart';
import '../../../shared/models/transport_plan.dart';

/// Possible phases of a capability negotiation session.
enum NegotiationPhase {
  /// Detecting local device capabilities.
  detectingLocal,

  /// Waiting for remote capabilities (future: GATT exchange).
  /// In Phase 2 this is skipped — remote capabilities are estimated from BLE data.
  exchangingCapabilities,

  /// Transport has been selected; ready to proceed.
  complete,

  /// Negotiation failed (BLE disconnected, timeout, etc.).
  failed,
}

/// Immutable state for the negotiation screen.
@immutable
class NegotiationState {
  const NegotiationState({
    this.phase = NegotiationPhase.detectingLocal,
    this.localCapabilities,
    this.remoteCapabilities,
    this.transportPlan,
    this.error,
  });

  final NegotiationPhase phase;

  /// Capabilities detected on this (sender) device.
  final DeviceCapabilities? localCapabilities;

  /// Capabilities received from the remote (receiver) device.
  ///
  /// In Phase 2, this is estimated from BLE advertisement data
  /// (device name, platform) + conservative defaults. Full GATT
  /// exchange is deferred to Phase 3.
  final DeviceCapabilities? remoteCapabilities;

  /// The selected transport plan — non-null when [phase] == [NegotiationPhase.complete].
  final TransportPlan? transportPlan;

  final String? error;

  bool get hasError => error != null;
  bool get isComplete => phase == NegotiationPhase.complete;
  bool get isFailed => phase == NegotiationPhase.failed;

  NegotiationState copyWith({
    NegotiationPhase? phase,
    DeviceCapabilities? localCapabilities,
    DeviceCapabilities? remoteCapabilities,
    TransportPlan? transportPlan,
    String? error,
  }) =>
      NegotiationState(
        phase: phase ?? this.phase,
        localCapabilities: localCapabilities ?? this.localCapabilities,
        remoteCapabilities: remoteCapabilities ?? this.remoteCapabilities,
        transportPlan: transportPlan ?? this.transportPlan,
        error: error ?? this.error,
      );
}
