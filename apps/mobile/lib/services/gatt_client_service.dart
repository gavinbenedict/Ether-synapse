import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../shared/models/device_capabilities.dart';

/// Client service used by the Sender to connect to the Receiver's GATT Server,
/// read the Receiver's capabilities, and write its own.
///
/// [deviceId] MUST be the BLE peripheral MAC address (e.g. "AA:BB:CC:DD:EE:FF"),
/// NOT the session-ID hex string. The MAC address is stored in [PeerDevice.bleAddress].
class GattClientService {
  GattClientService({required this.ble});

  final FlutterReactiveBle ble;

  // UUIDs must exactly match the Kotlin GattServerManager
  static final Uuid _serviceUuid =
      Uuid.parse('0000B81D-0000-1000-8000-00805F9B34FB');
  static final Uuid _charUuid =
      Uuid.parse('0000C81D-0000-1000-8000-00805F9B34FB');

  /// Connects to the receiver via BLE MAC [deviceId], performs the capability
  /// exchange over GATT, and disconnects.
  ///
  /// Throws if connection, service discovery, read, or write fails.
  /// Call with .timeout() from the caller for deadline enforcement.
  Future<DeviceCapabilities> exchangeCapabilities({
    required String deviceId,
    required DeviceCapabilities localCapabilities,
  }) async {
    debugPrint('[EtherSynapse] GATT connect start — deviceId: $deviceId');

    final completer = Completer<DeviceCapabilities>();
    StreamSubscription<ConnectionStateUpdate>? sub;

    // Connect to the peripheral by MAC address.
    final connectionStream = ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 15),
    );

    sub = connectionStream.listen((update) async {
      debugPrint(
        '[EtherSynapse] GATT connection state: ${update.connectionState} '
        '(device: $deviceId)',
      );

      switch (update.connectionState) {
        case DeviceConnectionState.connected:
          debugPrint('[EtherSynapse] GATT connected — $deviceId');
          try {
            // Some Android devices require explicit service discovery.
            debugPrint('[EtherSynapse] Services discovered — starting...');
            await ble.discoverAllServices(deviceId);
            debugPrint('[EtherSynapse] Services discovered — done');

            final characteristic = QualifiedCharacteristic(
              characteristicId: _charUuid,
              serviceId: _serviceUuid,
              deviceId: deviceId,
            );

            // 1. Read receiver capabilities.
            debugPrint('[EtherSynapse] Capability request — reading characteristic');
            final responseBytes = await ble.readCharacteristic(characteristic);
            final responseJson = utf8.decode(responseBytes);
            debugPrint('[EtherSynapse] Capability response: $responseJson');

            final map = jsonDecode(responseJson) as Map<String, dynamic>;
            final remoteCaps = DeviceCapabilities.fromJson(map);

            // 2. Write sender capabilities back to receiver.
            debugPrint('[EtherSynapse] Writing sender capabilities to characteristic');
            final sendJson = jsonEncode(localCapabilities.toJson());
            final sendBytes = utf8.encode(sendJson);

            await ble.writeCharacteristicWithResponse(
              characteristic,
              value: sendBytes,
            );
            debugPrint('[EtherSynapse] Sender capabilities written successfully');

            if (!completer.isCompleted) {
              completer.complete(remoteCaps);
            }
          } catch (e, st) {
            debugPrint('[EtherSynapse] GATT exchange error: $e\n$st');
            if (!completer.isCompleted) {
              completer.completeError(e, st);
            }
          } finally {
            debugPrint('[EtherSynapse] GATT cleanup — canceling subscription');
            await sub?.cancel();
            debugPrint('[EtherSynapse] GATT disconnected — $deviceId');
          }

        case DeviceConnectionState.disconnected:
          debugPrint('[EtherSynapse] GATT state: disconnected (device: $deviceId)');
          if (!completer.isCompleted) {
            final failure = update.failure;
            final msg = failure != null
                ? 'GATT disconnected: ${failure.message} (code ${failure.code})'
                : 'GATT disconnected before exchange completed';
            debugPrint('[EtherSynapse] GATT error — $msg');
            completer.completeError(Exception(msg));
          }

        default:
          // connecting / disconnecting — wait
          break;
      }
    }, onError: (Object e, StackTrace st) {
      debugPrint('[EtherSynapse] GATT stream error: $e');
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint('[EtherSynapse] GATT exchange TIMEOUT (15s)');
        sub?.cancel();
        throw TimeoutException('GATT negotiation timed out after 15 seconds');
      },
    );
  }
}
