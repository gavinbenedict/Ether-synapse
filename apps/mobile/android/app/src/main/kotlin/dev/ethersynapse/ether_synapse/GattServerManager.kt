package dev.ethersynapse.ether_synapse

import android.annotation.SuppressLint
import android.bluetooth.*
import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.util.UUID

@SuppressLint("MissingPermission")
class GattServerManager(private val context: Context, private val channel: MethodChannel) {
    private val TAG = "GattServerManager"
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private var gattServer: BluetoothGattServer? = null
    
    // Fixed UUIDs for Ether Synapse capability exchange
    private val SERVICE_UUID = UUID.fromString("0000B81D-0000-1000-8000-00805F9B34FB")
    private val CHAR_UUID = UUID.fromString("0000C81D-0000-1000-8000-00805F9B34FB")
    
    private var capabilitiesJson: String = "{}"
    
    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            super.onConnectionStateChange(device, status, newState)
            val stateStr = when (newState) {
                BluetoothProfile.STATE_CONNECTED -> "CONNECTED"
                BluetoothProfile.STATE_CONNECTING -> "CONNECTING"
                BluetoothProfile.STATE_DISCONNECTED -> "DISCONNECTED"
                BluetoothProfile.STATE_DISCONNECTING -> "DISCONNECTING"
                else -> "UNKNOWN ($newState)"
            }
            Log.d(TAG, "[GATT Server] onConnectionStateChange: device=${device.address}, status=$status, newState=$stateStr")
        }

        override fun onServiceAdded(status: Int, service: BluetoothGattService) {
            super.onServiceAdded(status, service)
            Log.d(TAG, "[GATT Server] onServiceAdded: status=$status, serviceUuid=${service.uuid}")
            if (status != BluetoothGatt.GATT_SUCCESS) {
                Log.e(TAG, "[GATT Server] Failed to add service: status=$status")
            }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
            Log.d(TAG, "[GATT Server] onCharacteristicReadRequest: device=${device.address}, charUuid=${characteristic.uuid}, requestId=$requestId, offset=$offset")
            
            if (characteristic.uuid == CHAR_UUID) {
                val bytes = capabilitiesJson.toByteArray(StandardCharsets.UTF_8)
                Log.d(TAG, "[GATT Server] Sending capabilities response (${bytes.size} bytes)")
                val value = if (offset < bytes.size) {
                    bytes.sliceArray(offset until bytes.size)
                } else {
                    ByteArray(0)
                }
                val success = gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                Log.d(TAG, "[GATT Server] sendResponse success: $success")
            } else {
                Log.w(TAG, "[GATT Server] Unknown characteristic read request: ${characteristic.uuid}")
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
            }
        }
        
        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)
            Log.d(TAG, "[GATT Server] onCharacteristicWriteRequest: device=${device.address}, charUuid=${characteristic.uuid}, requestId=$requestId, responseNeeded=$responseNeeded, valueSize=${value.size}")

            if (characteristic.uuid == CHAR_UUID) {
                val receivedJson = String(value, StandardCharsets.UTF_8)
                Log.i(TAG, "[GATT Server] Received capabilities from sender: $receivedJson")
                
                // Notify Flutter
                val map = mapOf("deviceId" to device.address, "capabilities" to receivedJson)
                val handler = android.os.Handler(android.os.Looper.getMainLooper())
                handler.post {
                    Log.d(TAG, "[GATT Server] Invoking Flutter onSenderCapabilitiesReceived")
                    channel.invokeMethod("onSenderCapabilitiesReceived", map)
                }
                
                if (responseNeeded) {
                    val success = gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                    Log.d(TAG, "[GATT Server] sendResponse (write) success: $success")
                }
            } else {
                Log.w(TAG, "[GATT Server] Unknown characteristic write request: ${characteristic.uuid}")
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
                }
            }
        }

        override fun onDescriptorReadRequest(device: BluetoothDevice, requestId: Int, offset: Int, descriptor: BluetoothGattDescriptor) {
            super.onDescriptorReadRequest(device, requestId, offset, descriptor)
            Log.d(TAG, "[GATT Server] onDescriptorReadRequest: device=${device.address}, descUuid=${descriptor.uuid}, requestId=$requestId")
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null)
        }

        override fun onDescriptorWriteRequest(device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) {
            super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value)
            Log.d(TAG, "[GATT Server] onDescriptorWriteRequest: device=${device.address}, descUuid=${descriptor.uuid}, requestId=$requestId")
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }
        }

        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
            super.onMtuChanged(device, mtu)
            Log.d(TAG, "[GATT Server] onMtuChanged: device=${device.address}, mtu=$mtu")
        }

        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            super.onNotificationSent(device, status)
            Log.d(TAG, "[GATT Server] onNotificationSent: device=${device.address}, status=$status")
        }
    }

    fun startServer(capabilitiesJson: String): Boolean {
        Log.d(TAG, "[GATT Server] startServer called with json length: ${capabilitiesJson.length}")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val permission = context.checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT)
            val granted = permission == android.content.pm.PackageManager.PERMISSION_GRANTED
            Log.d(TAG, "[GATT Server] BLUETOOTH_CONNECT granted: $granted")
            if (!granted) {
                Log.e(TAG, "[GATT Server] BLUETOOTH_CONNECT permission NOT granted. GATT server may fail.")
            }
        }

        this.capabilitiesJson = capabilitiesJson
        
        if (gattServer != null) {
            Log.d(TAG, "[GATT Server] Server already running")
            return true
        }
        
        gattServer = bluetoothManager.openGattServer(context, gattServerCallback)
        if (gattServer == null) {
            Log.e(TAG, "[GATT Server] Unable to open GATT server - bluetoothManager.openGattServer returned null")
            return false
        }
        
        Log.d(TAG, "[GATT Server] GATT server opened, adding service: $SERVICE_UUID")
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val characteristic = BluetoothGattCharacteristic(
            CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        
        service.addCharacteristic(characteristic)
        val success = gattServer?.addService(service) == true
        Log.d(TAG, "[GATT Server] addService returned: $success")
        return success
    }
    
    fun stopServer() {
        gattServer?.close()
        gattServer = null
    }
}
