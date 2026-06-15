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
            Log.d(TAG, "onConnectionStateChange: ${device.address}, status: $status, state: $newState")
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
            Log.d(TAG, "onCharacteristicReadRequest: $requestId, offset: $offset")
            
            if (characteristic.uuid == CHAR_UUID) {
                val bytes = capabilitiesJson.toByteArray(StandardCharsets.UTF_8)
                val value = if (offset < bytes.size) {
                    bytes.sliceArray(offset until bytes.size)
                } else {
                    ByteArray(0)
                }
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            } else {
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
            if (characteristic.uuid == CHAR_UUID) {
                val receivedJson = String(value, StandardCharsets.UTF_8)
                Log.d(TAG, "Received capabilities from sender: $receivedJson")
                
                // Notify Flutter
                val map = mapOf("deviceId" to device.address, "capabilities" to receivedJson)
                // Need to switch to main thread for channel invoke
                val handler = android.os.Handler(android.os.Looper.getMainLooper())
                handler.post {
                    channel.invokeMethod("onSenderCapabilitiesReceived", map)
                }
                
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }
            } else {
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
                }
            }
        }
    }

    fun startServer(capabilitiesJson: String): Boolean {
        this.capabilitiesJson = capabilitiesJson
        
        if (gattServer != null) return true
        
        gattServer = bluetoothManager.openGattServer(context, gattServerCallback)
        if (gattServer == null) {
            Log.e(TAG, "Unable to open GATT server")
            return false
        }
        
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val characteristic = BluetoothGattCharacteristic(
            CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        
        service.addCharacteristic(characteristic)
        return gattServer?.addService(service) == true
    }
    
    fun stopServer() {
        gattServer?.close()
        gattServer = null
    }
}
