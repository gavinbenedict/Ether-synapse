import 'package:flutter/foundation.dart';

import '../shared/models/device_capabilities.dart';
import '../shared/models/transport_plan.dart';
import 'system_settings_service.dart';

/// Selects the best transport for a file transfer between two devices.
///
/// Priority (highest to lowest):
///   1. Local WiFi — both devices on the same SSID
///   2. WiFi Direct — P2P without infrastructure
///   3. Mobile Hotspot — user-assisted, universal fallback
///
/// The host for WiFi Direct and Hotspot is selected based on WiFi generation
/// score (higher = better host) to maximise throughput.
class TransportService {
  const TransportService();

  /// Select the best [TransportPlan] given the capabilities of both peers.
  ///
  /// [local] — this device (the sender).
  /// [remote] — the remote device (the receiver that was tapped).
  TransportPlan selectBestTransport({
    required DeviceCapabilities local,
    required DeviceCapabilities remote,
  }) {
    debugPrint(
      '[EtherSynapse] TransportService.selectBestTransport\n'
      '  local:  $local\n'
      '  remote: $remote',
    );

    // ── Priority 1: Local WiFi ──────────────────────────────────────
    if (local.supportsLocalWifi &&
        remote.supportsLocalWifi &&
        local.localSsid != null &&
        local.localSsid == remote.localSsid) {
      final plan = TransportPlan(
        type: TransportType.localWifi,
        hostDevice: remote, // receiver acts as TCP server
        joinerDevice: local,
        reason: 'Both devices are on the same WiFi network '
            '("${local.localSsid}"). No setup required.',
        requiresUserAction: false,
      );
      debugPrint('[EtherSynapse] Transport selected: ${plan.type.label}');
      return plan;
    }

    // ── Priority 2: WiFi Direct ─────────────────────────────────────
    if (local.supportsWifiDirect && remote.supportsWifiDirect) {
      final (host, joiner) = _selectHost(local, remote);
      final plan = TransportPlan(
        type: TransportType.wifiDirect,
        hostDevice: host,
        joinerDevice: joiner,
        reason: 'WiFi Direct (P2P) will be used. '
            '${host.displayName} will act as group owner '
            '(${host.wifiStandardLabel}).',
        requiresUserAction: false,
      );
      debugPrint('[EtherSynapse] Transport selected: ${plan.type.label} '
          '— host: ${host.displayName}');
      return plan;
    }

    // ── Priority 3: Mobile Hotspot ──────────────────────────────────
    final (host, joiner) = _selectHost(local, remote);
    final hostStandard = host.wifiStandard;
    final reason = host.wifiScore > 0 && joiner.wifiScore > 0
        ? '${host.displayName} supports ${host.wifiStandardLabel}, '
            'which provides better hotspot performance than '
            '${joiner.displayName} (${joiner.wifiStandardLabel}).'
        : '${host.displayName} will create the hotspot for this transfer.';

    final plan = TransportPlan(
      type: TransportType.hotspot,
      hostDevice: host,
      joinerDevice: joiner,
      reason: reason,
      requiresUserAction: true,
      userActionLabel: 'Open Hotspot Settings',
      userActionDescription:
          'Enable the mobile hotspot on ${host.displayName}, '
          'then wait for ${joiner.displayName} to connect automatically.',
      settingsAction: SystemSettingsService.actionHotspot,
    );

    debugPrint(
      '[EtherSynapse] Transport selected: ${plan.type.label} '
      '— host: ${host.displayName} ($hostStandard)',
    );
    return plan;
  }

  /// Returns (host, joiner) — the device with the higher WiFi score hosts.
  /// On a tie, [local] hosts by default.
  (DeviceCapabilities host, DeviceCapabilities joiner) _selectHost(
    DeviceCapabilities local,
    DeviceCapabilities remote,
  ) {
    return remote.wifiScore > local.wifiScore
        ? (remote, local)
        : (local, remote);
  }
}
