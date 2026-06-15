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
    debugPrint('[EtherSynapse] GATT exchange — START');
    debugPrint('[EtherSynapse]   - Target deviceId (MAC): $deviceId');
    debugPrint('[EtherSynapse]   - Local capabilities size: ${jsonEncode(localCapabilities.toJson()).length} bytes');

    final completer = Completer<DeviceCapabilities>();
    StreamSubscription<ConnectionStateUpdate>? sub;

    // Connect to the peripheral by MAC address.
    debugPrint('[EtherSynapse] Initiating ble.connectToDevice(id: $deviceId)');
    final connectionStream = ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 15),
    );

    sub = connectionStream.listen((update) async {
      debugPrint(
        '[EtherSynapse] GATT connection state update: ${update.connectionState} '
        '(device: $update.deviceId, status: ${update.connectionState})',
      );

      switch (update.connectionState) {
        case DeviceConnectionState.connecting:
          debugPrint('[EtherSynapse] GATT status: CONNECTING to $deviceId...');
          break;
        case DeviceConnectionState.connected:
          debugPrint('[EtherSynapse] GATT status: CONNECTED to $deviceId');
          try {
            // Request MTU increase for large capability JSONs.
            debugPrint('[EtherSynapse] Requesting MTU 512 for $deviceId...');
            final mtu = await ble.requestMtu(deviceId: deviceId, mtu: 512);
            debugPrint('[EtherSynapse] MTU negotiation result: $mtu');

            // Some Android devices require explicit service discovery.
            debugPrint('[EtherSynapse] Starting service discovery for $deviceId...');
            await ble.discoverAllServices(deviceId);
            debugPrint('[EtherSynapse] Service discovery completed.');

            final characteristic = QualifiedCharacteristic(
              characteristicId: _charUuid,
              serviceId: _serviceUuid,
              deviceId: deviceId,
            );

            // 1. Read receiver capabilities.
            debugPrint('[EtherSynapse] Reading receiver capabilities from $_charUuid...');
            final responseBytes = await ble.readCharacteristic(characteristic);
            debugPrint('[EtherSynapse] Read successful. Bytes: ${responseBytes.length}');
            
            final responseJson = utf8.decode(responseBytes);
            debugPrint('[EtherSynapse] Decoded response: $responseJson');

            final map = jsonDecode(responseJson) as Map<String, dynamic>;
            final remoteCaps = DeviceCapabilities.fromJson(map);

            // 2. Write sender capabilities back to receiver.
            debugPrint('[EtherSynapse] Writing local capabilities to $_charUuid...');
            final sendJson = jsonEncode(localCapabilities.toJson());
            final sendBytes = utf8.encode(sendJson);

            await ble.writeCharacteristicWithResponse(
              characteristic,
              value: sendBytes,
            );
            debugPrint('[EtherSynapse] Write successful. Exchange complete.');

            if (!completer.isCompleted) {
              completer.complete(remoteCaps);
            }
          } catch (e, st) {
            debugPrint('[EtherSynapse] GATT exchange FAILURE: $e\n$st');
            if (!completer.isCompleted) {
              completer.completeError(e, st);
            }
          } finally {
            debugPrint('[EtherSynapse] GATT exchange finally block - cleaning up');
            // We don't cancel sub here because we might want to wait for disconnect 
            // OR if we are done we cancel it.
            // Actually the original code canceled it here.
            await sub?.cancel();
            debugPrint('[EtherSynapse] GATT subscription canceled');
          }
          break;

        case DeviceConnectionState.disconnecting:
          debugPrint('[EtherSynapse] GATT disconnecting from $deviceId...');
          break;

        case DeviceConnectionState.disconnected:
          debugPrint('[EtherSynapse] GATT DISCONNECTED from $deviceId');
          if (!completer.isCompleted) {
            final failure = update.failure;
            final msg = failure != null
                ? 'GATT disconnected: ${failure.message} (code ${failure.code})'
                : 'GATT disconnected before exchange completed';
            debugPrint('[EtherSynapse] GATT error: $msg');
            completer.completeError(Exception(msg));
          }
          await sub?.cancel();
          break;
      }
    }, onError: (Object e, StackTrace st) {
      debugPrint('[EtherSynapse] GATT connection stream error: $e\n$st');
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
