import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../shared/models/device_capabilities.dart';

/// Detects the local device's transport capabilities.
///
/// All detection is performed via the [MethodChannel] registered in
/// [MainActivity]. On non-Android platforms, returns safe defaults.
///
/// Capabilities detected:
///   - Android SDK version (for hotspot/WiFi-Direct compatibility checks)
///   - WiFi generation (used to select hotspot host)
///   - Whether the device is connected to a local WiFi network
///   - SSID of the connected network (for same-network detection)
///   - Whether hotspot is supported (API >= 26 required)
///   - Whether WiFi Direct is supported
class CapabilityService {
  static const _channel = MethodChannel('dev.ethersynapse/capabilities');

  /// Detect and return this device's capabilities.
  ///
  /// Never throws — on any error returns a safe minimal [DeviceCapabilities].
  Future<DeviceCapabilities> detectLocalCapabilities({
    required String displayName,
  }) async {
    if (!Platform.isAndroid) {
      return DeviceCapabilities(
        deviceName: 'Unknown Device',
        displayName: displayName,
        deviceModel: 'Unknown Device',
        appVersion: AppConstants.appVersion,
        androidSdkVersion: 0,
        wifiStandard: 'unknown',
        supportsLocalWifi: false,
        supportsHotspot: false,
        supportsWifiDirect: false,
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getCapabilities',
      );

      final map = result ?? {};

      final rawModel = map['deviceModel'] as String? ?? '';
      final manufacturer = map['manufacturer'] as String? ?? '';
      // Build a clean model string: "Samsung A35" or "Redmi Note 10S"
      final deviceName = _buildModelName(manufacturer, rawModel);

      debugPrint('[EtherSynapse] CapabilityService raw: $map');
      debugPrint('[EtherSynapse] Device model: $deviceName');

      return DeviceCapabilities(
        deviceName: deviceName,
        displayName: displayName,
        deviceModel: deviceName,
        appVersion: AppConstants.appVersion,
        androidSdkVersion: map['sdkVersion'] as int? ?? 0,
        wifiStandard: map['wifiStandard'] as String? ?? 'unknown',
        supportsHotspot: map['supportsHotspot'] as bool? ?? false,
        supportsWifiDirect: map['supportsWifiDirect'] as bool? ?? false,
        supportsLocalWifi: map['connectedToWifi'] as bool? ?? false,
        localSsid: map['ssid'] as String?,
        localIpAddress: map['localIpAddress'] as String?,
      );
    } on PlatformException catch (e) {
      debugPrint('[EtherSynapse] CapabilityService detection failed: $e');
      // Return minimal safe capabilities so negotiation can still proceed
      // with hotspot as fallback.
      return DeviceCapabilities(
        deviceName: 'Unknown Device',
        displayName: displayName,
        deviceModel: 'Unknown Device',
        appVersion: AppConstants.appVersion,
        androidSdkVersion: 0,
        wifiStandard: 'unknown',
        supportsHotspot: true, // assume Android supports hotspot
        supportsWifiDirect: false,
        supportsLocalWifi: false,
      );
    }
  }

  /// Builds a clean human-readable model name.
  /// Capitalises the manufacturer if it's not already in the model string.
  static String _buildModelName(String manufacturer, String model) {
    if (model.isEmpty) return 'Unknown Device';
    final mfr = manufacturer.trim();
    final mdl = model.trim();
    // If model already starts with manufacturer name (case-insensitive), skip prefix.
    if (mfr.isNotEmpty &&
        !mdl.toLowerCase().startsWith(mfr.toLowerCase())) {
      final capitalised =
          mfr[0].toUpperCase() + mfr.substring(1).toLowerCase();
      return '$capitalised $mdl';
    }
    return mdl;
  }
}
