import 'package:flutter/foundation.dart';

import 'device_capabilities.dart';

/// Which transport mechanism will be used for the actual file transfer.
enum TransportType {
  /// Both devices are on the same local WiFi network.
  ///
  /// Best performance. No user action required.
  localWifi,

  /// WiFi Direct (P2P) connection between the two devices.
  ///
  /// Good performance. Android may prompt for location permission.
  wifiDirect,

  /// One device creates a mobile hotspot; the other joins it.
  ///
  /// Universal fallback. Requires user action (enable hotspot manually).
  hotspot;

  String get label => switch (this) {
        TransportType.localWifi => 'Local WiFi',
        TransportType.wifiDirect => 'WiFi Direct',
        TransportType.hotspot => 'Mobile Hotspot',
      };

  String get description => switch (this) {
        TransportType.localWifi =>
          'Both devices are on the same WiFi network.',
        TransportType.wifiDirect =>
          'Devices connect directly via WiFi Direct (P2P).',
        TransportType.hotspot =>
          'One device creates a hotspot for the other to join.',
      };
}

/// The result of transport negotiation — describes exactly how the transfer
/// will be established and what (if any) user action is required first.
@immutable
class TransportPlan {
  const TransportPlan({
    required this.type,
    required this.hostDevice,
    required this.joinerDevice,
    required this.reason,
    required this.requiresUserAction,
    this.userActionLabel,
    this.userActionDescription,
    this.settingsAction,
  });

  /// The selected transport mechanism.
  final TransportType type;

  /// The device that hosts the connection (creates hotspot / AP / server).
  final DeviceCapabilities hostDevice;

  /// The device that joins the connection (connects to hotspot / client).
  final DeviceCapabilities joinerDevice;

  /// Human-readable explanation of why this transport and host were chosen.
  final String reason;

  /// Whether the user must perform a manual action before transfer can begin.
  final bool requiresUserAction;

  /// Short label for the action button (e.g. "Open Hotspot Settings").
  final String? userActionLabel;

  /// Detailed instruction shown below the action button.
  final String? userActionDescription;

  /// Key passed to [SystemSettingsService] to open the correct settings screen.
  final String? settingsAction;

  @override
  String toString() =>
      'TransportPlan(type: ${type.label}, host: ${hostDevice.deviceName}, '
      'joiner: ${joinerDevice.deviceName}, requiresAction: $requiresUserAction)';
}
