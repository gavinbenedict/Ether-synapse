import 'package:flutter/services.dart';

/// Provides access to native Android WifiP2pManager for creating
/// and managing WiFi Direct groups.
class WifiDirectService {
  static const _channel = MethodChannel('dev.ethersynapse/wifi_direct');

  /// Creates a WiFi Direct group (makes this device the Group Owner).
  /// Returns a tuple of (success, hostIpAddress).
  Future<(bool, String?)> createGroup() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('createGroup');
      if (result == null) return (false, null);
      
      final success = result['success'] as bool? ?? false;
      final hostIp = result['hostIp'] as String?;
      return (success, hostIp);
    } on PlatformException {
      return (false, null);
    }
  }

  /// Removes the current WiFi Direct group.
  Future<bool> removeGroup() async {
    try {
      final result = await _channel.invokeMethod<bool>('removeGroup');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Requests the current connection info to find the Group Owner IP.
  Future<String?> requestConnectionInfo() async {
    try {
      return await _channel.invokeMethod<String>('requestConnectionInfo');
    } on PlatformException {
      return null;
    }
  }
}
