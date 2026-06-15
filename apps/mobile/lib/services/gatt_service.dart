import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../shared/models/device_capabilities.dart';

/// Dart wrapper for the native GATT Server.
class GattService {
  static const _channel = MethodChannel('dev.ethersynapse/gatt');
  
  /// Stream of capabilities received from a sender via GATT write.
  /// The payload is a [DeviceCapabilities] object.
  static Stream<DeviceCapabilities> get onSenderCapabilitiesReceived {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSenderCapabilitiesReceived') {
        try {
          final args = call.arguments as Map;
          final jsonStr = args['capabilities'] as String;
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final caps = DeviceCapabilities.fromJson(map);
          _controller.add(caps);
        } catch (e) {
          debugPrint('[EtherSynapse] Error decoding sender capabilities: $e');
        }
      }
    });
    return _controller.stream;
  }
  
  static final _controller = StreamController<DeviceCapabilities>.broadcast();

  /// Starts the GATT server with the local capabilities JSON payload.
  /// Remote senders connecting to the GATT server will read this payload.
  Future<bool> startServer(DeviceCapabilities localCapabilities) async {
    try {
      final jsonStr = jsonEncode(localCapabilities.toJson());
      final result = await _channel.invokeMethod<bool>('startGattServer', {
        'capabilitiesJson': jsonStr,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[EtherSynapse] Failed to start GATT server: $e');
      return false;
    }
  }

  /// Stops the GATT server.
  Future<void> stopServer() async {
    try {
      await _channel.invokeMethod('stopGattServer');
    } on PlatformException catch (e) {
      debugPrint('[EtherSynapse] Failed to stop GATT server: $e');
    }
  }
}
