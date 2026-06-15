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
      final now = DateTime.now().toIso8601String().split('T')[1];
      debugPrint(
        '[$now][EtherSynapse] GATT connection state update: ${update.connectionState} '
        '(device: ${update.deviceId}, status: ${update.connectionState})',
      );

      switch (update.connectionState) {
        case DeviceConnectionState.connecting:
          debugPrint('[$now][EtherSynapse] GATT status: CONNECTING to $deviceId...');
          break;
        case DeviceConnectionState.connected:
          debugPrint('[$now][EtherSynapse] GATT status: CONNECTED to $deviceId');
          try {
            // Request high priority for the capability exchange.
            debugPrint('[$now][EtherSynapse] Requesting high priority connection...');
            await ble.requestConnectionPriority(deviceId: deviceId, priority: ConnectionPriority.highPerformance);
            
            // Request MTU increase for large capability JSONs.
            debugPrint('[$now][EtherSynapse] Requesting MTU 512 for $deviceId...');
            final mtu = await ble.requestMtu(deviceId: deviceId, mtu: 512);
            debugPrint('[$now][EtherSynapse] MTU negotiation result: $mtu');

            // Some Android devices require explicit service discovery.
            debugPrint('[$now][EtherSynapse] Starting service discovery for $deviceId...');
            await ble.discoverAllServices(deviceId);
            final services = await ble.getDiscoveredServices(deviceId);
            debugPrint('[$now][EtherSynapse] Service discovery completed. Found ${services.length} services.');
            
            bool serviceFound = false;
            bool charFound = false;
            for (final service in services) {
              if (service.id == _serviceUuid) {
                serviceFound = true;
                debugPrint('[$now][EtherSynapse] Target service found: ${service.id}');
                for (final char in service.characteristics) {
                   if (char.id == _charUuid) {
                      charFound = true;
                      debugPrint('[$now][EtherSynapse] Target characteristic found: $_charUuid');
                   }
                }
              }
            }
            
            if (!serviceFound) {
               debugPrint('[$now][EtherSynapse] WARNING: Target service $_serviceUuid NOT found in discovered services!');
            }
            if (!charFound) {
               debugPrint('[$now][EtherSynapse] WARNING: Target characteristic $_charUuid NOT found in discovered services!');
            }

            final characteristic = QualifiedCharacteristic(
              characteristicId: _charUuid,
              serviceId: _serviceUuid,
              deviceId: deviceId,
            );

            // 1. Read receiver capabilities.
            debugPrint('[$now][EtherSynapse] Reading receiver capabilities from $_charUuid...');
            final responseBytes = await ble.readCharacteristic(characteristic);
            debugPrint('[$now][EtherSynapse] Read successful. Bytes: ${responseBytes.length}');
            
            final responseJson = utf8.decode(responseBytes);
            debugPrint('[$now][EtherSynapse] Decoded response: $responseJson');

            final map = jsonDecode(responseJson) as Map<String, dynamic>;
            final remoteCaps = DeviceCapabilities.fromJson(map);

            // 2. Write sender capabilities back to receiver.
            debugPrint('[$now][EtherSynapse] Writing local capabilities to $_charUuid...');
            final sendJson = jsonEncode(localCapabilities.toJson());
            final sendBytes = utf8.encode(sendJson);

            await ble.writeCharacteristicWithResponse(
              characteristic,
              value: sendBytes,
            );
            debugPrint('[$now][EtherSynapse] Write successful. Exchange complete.');

            if (!completer.isCompleted) {
              completer.complete(remoteCaps);
            }
          } catch (e, st) {
            debugPrint('[$now][EtherSynapse] GATT exchange FAILURE: $e\n$st');
            if (!completer.isCompleted) {
              completer.completeError(e, st);
            }
          } finally {
            debugPrint('[$now][EtherSynapse] GATT exchange finally block - cleaning up');
            await sub?.cancel();
            debugPrint('[$now][EtherSynapse] GATT subscription canceled');
          }
          break;

        case DeviceConnectionState.disconnecting:
          debugPrint('[$now][EtherSynapse] GATT disconnecting from $deviceId...');
          break;

        case DeviceConnectionState.disconnected:
          debugPrint('[$now][EtherSynapse] GATT DISCONNECTED from $deviceId');
          if (!completer.isCompleted) {
            final failure = update.failure;
            final msg = failure != null
                ? 'GATT disconnected: ${failure.message} (code ${failure.code})'
                : 'GATT disconnected before exchange completed';
            debugPrint('[$now][EtherSynapse] GATT error: $msg');
            completer.completeError(Exception(msg));
          }
          await sub?.cancel();
          break;
      }
    }, onError: (Object e, StackTrace st) {
      final now = DateTime.now().toIso8601String().split('T')[1];
      debugPrint('[$now][EtherSynapse] GATT connection stream error: $e\n$st');
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
