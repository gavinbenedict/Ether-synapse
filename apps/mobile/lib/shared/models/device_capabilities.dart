import 'package:flutter/foundation.dart';

/// Snapshot of a device's transport and system capabilities.
///
/// Exchanged during the BLE negotiation phase so both peers can agree
/// on the best transport for the file transfer.
///
/// Fields are deliberately nullable — a capability that could not be
/// determined is represented as null rather than a false positive.
@immutable
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.deviceName,
    required this.displayName,
    required this.deviceModel,
    required this.appVersion,
    required this.androidSdkVersion,
    required this.wifiStandard,
    this.supportsHotspot = false,
    this.supportsWifiDirect = false,
    this.supportsLocalWifi = false,
    this.localSsid,
    this.localIpAddress,
  });

  /// Hardware model name from the OS (e.g. "Samsung A35").
  final String deviceName;

  /// User-configured display name (e.g. "Gavin").
  final String displayName;

  /// Hardware model name from the OS (e.g. "Samsung A35", "Redmi Note 10S").
  /// Populated via Android Build.MODEL. Same as [deviceName] for compatibility.
  final String deviceModel;

  /// App version string (e.g. "0.1.0").
  final String appVersion;

  /// Android API level (e.g. 34 for Android 14).
  final int androidSdkVersion;

  /// WiFi generation: "wifi4", "wifi5", "wifi6", "wifi6e", "wifi7", "unknown".
  ///
  /// Used for hotspot host selection — higher generation = preferred host.
  final String wifiStandard;

  /// Whether this device can create a mobile hotspot.
  final bool supportsHotspot;

  /// Whether this device supports WiFi Direct (P2P).
  final bool supportsWifiDirect;

  /// Whether this device is currently connected to a local WiFi network.
  final bool supportsLocalWifi;

  /// SSID of the connected WiFi network, or null if not connected.
  ///
  /// Used to detect whether both devices are on the same network.
  final String? localSsid;

  /// Local IP address of the device on the WiFi network.
  /// Used for establishing the TCP connection.
  final String? localIpAddress;

  // ── Convenience ───────────────────────────────────────────────────

  /// Numeric WiFi generation score for host selection comparisons.
  int get wifiScore => switch (wifiStandard) {
        'wifi7' => 7,
        'wifi6e' => 6,
        'wifi6' => 6,
        'wifi5' => 5,
        'wifi4' => 4,
        _ => 0,
      };

  /// Human-readable WiFi generation label.
  String get wifiStandardLabel => switch (wifiStandard) {
        'wifi7' => 'WiFi 7',
        'wifi6e' => 'WiFi 6E',
        'wifi6' => 'WiFi 6',
        'wifi5' => 'WiFi 5',
        'wifi4' => 'WiFi 4',
        _ => 'Unknown WiFi',
      };

  DeviceCapabilities copyWith({
    String? deviceName,
    String? displayName,
    String? deviceModel,
    String? appVersion,
    int? androidSdkVersion,
    String? wifiStandard,
    bool? supportsHotspot,
    bool? supportsWifiDirect,
    bool? supportsLocalWifi,
    String? localSsid,
    String? localIpAddress,
  }) {
    return DeviceCapabilities(
      deviceName: deviceName ?? this.deviceName,
      displayName: displayName ?? this.displayName,
      deviceModel: deviceModel ?? this.deviceModel,
      appVersion: appVersion ?? this.appVersion,
      androidSdkVersion: androidSdkVersion ?? this.androidSdkVersion,
      wifiStandard: wifiStandard ?? this.wifiStandard,
      supportsHotspot: supportsHotspot ?? this.supportsHotspot,
      supportsWifiDirect: supportsWifiDirect ?? this.supportsWifiDirect,
      supportsLocalWifi: supportsLocalWifi ?? this.supportsLocalWifi,
      localSsid: localSsid ?? this.localSsid,
      localIpAddress: localIpAddress ?? this.localIpAddress,
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceName': deviceName,
        'displayName': displayName,
        'deviceModel': deviceModel,
        'appVersion': appVersion,
        'androidSdkVersion': androidSdkVersion,
        'wifiStandard': wifiStandard,
        'supportsHotspot': supportsHotspot,
        'supportsWifiDirect': supportsWifiDirect,
        'supportsLocalWifi': supportsLocalWifi,
        if (localSsid != null) 'localSsid': localSsid,
        if (localIpAddress != null) 'localIpAddress': localIpAddress,
      };

  factory DeviceCapabilities.fromJson(Map<String, dynamic> json) =>
      DeviceCapabilities(
        deviceName: json['deviceName'] as String? ?? 'Unknown',
        displayName: json['displayName'] as String? ?? 'Unknown',
        deviceModel: json['deviceModel'] as String? ?? 'Unknown Device',
        appVersion: json['appVersion'] as String? ?? '0.0.0',
        androidSdkVersion: json['androidSdkVersion'] as int? ?? 0,
        wifiStandard: json['wifiStandard'] as String? ?? 'unknown',
        supportsHotspot: json['supportsHotspot'] as bool? ?? false,
        supportsWifiDirect: json['supportsWifiDirect'] as bool? ?? false,
        supportsLocalWifi: json['supportsLocalWifi'] as bool? ?? false,
        localSsid: json['localSsid'] as String?,
        localIpAddress: json['localIpAddress'] as String?,
      );

  @override
  String toString() =>
      'DeviceCapabilities(displayName: $displayName, model: $deviceName, '
      'wifi: $wifiStandard, sdk: $androidSdkVersion, '
      'hotspot: $supportsHotspot, wifiDirect: $supportsWifiDirect, '
      'localWifi: $supportsLocalWifi)';
}
