import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../shared/models/device_capabilities.dart';

/// Dart wrapper for the native GATT Server (hosted on the Receiver).
///
/// The MethodChannel handler is registered once at class initialization to
/// avoid the bug where calling [onSenderCapabilitiesReceived] multiple times
/// would overwrite the handler and lose events.
class GattService {
  static const _channel = MethodChannel('dev.ethersynapse/gatt');

  // ── Static stream controller (broadcast, alive for the app lifetime) ──────
  static final _capabilitiesController =
      StreamController<DeviceCapabilities>.broadcast();

  /// Stream of capabilities received from a sender via GATT write.
  ///
  /// Fires once per connected sender after the sender writes its
  /// [DeviceCapabilities] JSON to the GATT characteristic.
  ///
  /// Subscribe in [ReceiveNotifier] to know when to navigate to TransferScreen.
  static Stream<DeviceCapabilities> get onSenderCapabilitiesReceived =>
      _capabilitiesController.stream;

  // ── One-time MethodChannel handler registration ───────────────────────────
  /// Must be called once at app startup (before any subscriptions are added).
  ///
  /// Called automatically by [_GattServiceInit] via the static initializer.
  static void _registerHandler() {
    _channel.setMethodCallHandler((call) async {
      debugPrint('[EtherSynapse] GattService: MethodChannel call: ${call.method}');
      if (call.method == 'onSenderCapabilitiesReceived') {
        try {
          final args = call.arguments as Map;
          final jsonStr = args['capabilities'] as String;
          debugPrint(
            '[EtherSynapse] GattService: Received sender capabilities: $jsonStr',
          );
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final caps = DeviceCapabilities.fromJson(map);
          debugPrint(
            '[EtherSynapse] GattService: Decoded sender capabilities — '
            'name: ${caps.deviceName}, ip: ${caps.localIpAddress}',
          );
          _capabilitiesController.add(caps);
        } catch (e, st) {
          debugPrint('[EtherSynapse] GattService: Error decoding capabilities: $e\n$st');
        }
      }
    });
    debugPrint('[EtherSynapse] GattService: MethodChannel handler registered');
  }

  // Register the handler once when the class is first loaded.
  static final _handlerRegistration = _registerHandler();

  // Force the static initializer to run.
  static void init() => _handlerRegistration;

  // ── Instance methods ──────────────────────────────────────────────────────

  /// Starts the GATT server with the local capabilities JSON payload.
  ///
  /// Remote senders connecting to the GATT server will read this payload.
  Future<bool> startServer(DeviceCapabilities localCapabilities) async {
    try {
      final jsonStr = jsonEncode(localCapabilities.toJson());
      debugPrint('[EtherSynapse] GattService: Starting server: $jsonStr');
      final result = await _channel.invokeMethod<bool>('startGattServer', {
        'capabilitiesJson': jsonStr,
      });
      debugPrint('[EtherSynapse] GattService: startServer result: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[EtherSynapse] GattService: Failed to start GATT server: $e');
      return false;
    }
  }

  /// Stops the GATT server.
  Future<void> stopServer() async {
    try {
      await _channel.invokeMethod('stopGattServer');
    } on PlatformException catch (e) {
      debugPrint('[EtherSynapse] GattService: Failed to stop GATT server: $e');
    }
  }

  /// Starts native BLE advertising with manufacturer data.
  Future<bool> startAdvertising({
    required int manufacturerId,
    required Uint8List manufacturerData,
  }) async {
    try {
      debugPrint('[EtherSynapse] GattService: Starting native advertising...');
      final result = await _channel.invokeMethod<bool>('startAdvertising', {
        'manufacturerId': manufacturerId,
        'manufacturerData': manufacturerData,
      });
      debugPrint('[EtherSynapse] GattService: startAdvertising result: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[EtherSynapse] GattService: Failed to start advertising: $e');
      return false;
    }
  }

  /// Stops native BLE advertising.
  Future<void> stopAdvertising() async {
    try {
      await _channel.invokeMethod('stopAdvertising');
      debugPrint('[EtherSynapse] GattService: Native advertising stopped');
    } on PlatformException catch (e) {
      debugPrint('[EtherSynapse] GattService: Failed to stop advertising: $e');
    }
  }
}
