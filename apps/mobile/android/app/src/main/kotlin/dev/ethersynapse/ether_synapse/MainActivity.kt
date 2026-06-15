package dev.ethersynapse.ether_synapse

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_SETTINGS     = "dev.ethersynapse/settings"
        private const val CHANNEL_CAPABILITIES = "dev.ethersynapse/capabilities"
        private const val CHANNEL_GATT         = "dev.ethersynapse/gatt"
    }
    
    private var gattServerManager: GattServerManager? = null
    private var wifiDirectManager: WifiDirectManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerSettingsChannel(flutterEngine)
        registerCapabilitiesChannel(flutterEngine)
        registerGattChannel(flutterEngine)
        registerWifiDirectChannel(flutterEngine)
    }

    // ── Settings channel ──────────────────────────────────────────────────────

    private fun registerSettingsChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_SETTINGS)
            .setMethodCallHandler { call, result ->
                if (call.method == "openSettings") {
                    openSystemSettings(call.argument<String>("action"))
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openSystemSettings(action: String?) {
        val intent: Intent = when (action) {
            "bluetooth"       -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            "wifi"            -> Intent(Settings.ACTION_WIFI_SETTINGS)
            "wireless"        -> Intent(Settings.ACTION_WIRELESS_SETTINGS)
            "app_permissions" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", packageName, null)
            }
            "nearby"          -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", packageName, null)
            }
            "hotspot" -> {
                // OEM tethering activity — not guaranteed; fall back to wireless settings.
                val tetherIntent = Intent().apply {
                    setClassName(
                        "com.android.settings",
                        "com.android.settings.TetherSettings"
                    )
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (packageManager.resolveActivity(tetherIntent, 0) != null) {
                    tetherIntent
                } else {
                    Intent(Settings.ACTION_WIRELESS_SETTINGS)
                }
            }
            else -> Intent(Settings.ACTION_WIRELESS_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    // ── Capabilities channel ──────────────────────────────────────────────────

    private fun registerCapabilitiesChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_CAPABILITIES)
            .setMethodCallHandler { call, result ->
                if (call.method == "getCapabilities") {
                    result.success(detectCapabilities())
                } else {
                    result.notImplemented()
                }
            }
    }

    // ── GATT channel ──────────────────────────────────────────────────────────
    
    private fun registerGattChannel(engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_GATT)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startGattServer" -> {
                    val capabilitiesJson = call.argument<String>("capabilitiesJson") ?: "{}"
                    if (gattServerManager == null) {
                        gattServerManager = GattServerManager(context, channel)
                    }
                    val success = gattServerManager?.startServer(capabilitiesJson) == true
                    result.success(success)
                }
                "stopGattServer" -> {
                    gattServerManager?.stopServer()
                    result.success(null)
                }
                "startAdvertising" -> {
                    val mfgId = call.argument<Int>("manufacturerId") ?: 0xFFFF
                    val mfgData = call.argument<ByteArray>("manufacturerData") ?: ByteArray(0)
                    val success = gattServerManager?.startAdvertising(mfgId, mfgData) == true
                    result.success(success)
                }
                "stopAdvertising" -> {
                    gattServerManager?.stopAdvertising()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── Wifi Direct channel ──────────────────────────────────────────────────
    
    private fun registerWifiDirectChannel(engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "dev.ethersynapse/wifi_direct")
        channel.setMethodCallHandler { call, result ->
            if (wifiDirectManager == null) {
                wifiDirectManager = WifiDirectManager(context, channel)
            }
            when (call.method) {
                "createGroup" -> {
                    wifiDirectManager?.createGroup { success, hostIp ->
                        result.success(mapOf("success" to success, "hostIp" to hostIp))
                    }
                }
                "removeGroup" -> {
                    wifiDirectManager?.removeGroup { success ->
                        result.success(success)
                    }
                }
                "requestConnectionInfo" -> {
                    wifiDirectManager?.requestConnectionInfo { hostIp ->
                        result.success(hostIp)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun detectCapabilities(): Map<String, Any?> {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

        // ── WiFi connection & SSID ────────────────────────────────────────────
        var connectedToWifi = false
        var ssid: String? = null

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val caps = cm.getNetworkCapabilities(cm.activeNetwork)
                connectedToWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            } else {
                @Suppress("DEPRECATION")
                connectedToWifi = wm.isWifiEnabled && (wm.connectionInfo?.networkId ?: -1) != -1
            }
        } catch (e: SecurityException) {
            Log.e("EtherSynapse", "ACCESS_NETWORK_STATE permission missing", e)
        }

        var ipString: String? = null
        if (connectedToWifi) {
            ssid = try {
                @Suppress("DEPRECATION")
                wm.connectionInfo?.ssid?.removeSurrounding("\"")
            } catch (_: Exception) { null }
            
            val ipAddress = wm.connectionInfo?.ipAddress ?: 0
            ipString = if (ipAddress != 0) {
                String.format("%d.%d.%d.%d", 
                    (ipAddress and 0xff), 
                    (ipAddress shr 8 and 0xff), 
                    (ipAddress shr 16 and 0xff), 
                    (ipAddress shr 24 and 0xff))
            } else null
        }

        // ── WiFi standard (generation) ────────────────────────────────────────
        // API 30+ exposes wifiStandard as an int. We use a separate annotated
        // function so the Kotlin compiler does not complain about RequiresApi.
        val wifiStandard: String = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            getWifiStandard(wm)
        } else {
            "unknown"
        }

        // ── Feature flags ─────────────────────────────────────────────────────
        // All modern Android devices support WiFi Direct (API 14+) and can
        // create a hotspot programmatically (API 26+) or via Settings.
        val supportsHotspot    = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        val supportsWifiDirect = true // API 14+ — well within our minSdk

        return mapOf(
            "sdkVersion"         to Build.VERSION.SDK_INT,
            "deviceModel"        to Build.MODEL,
            "manufacturer"       to Build.MANUFACTURER,
            "wifiStandard"       to wifiStandard,
            "connectedToWifi"    to connectedToWifi,
            "ssid"               to ssid,
            "supportsHotspot"    to supportsHotspot,
            "supportsWifiDirect" to supportsWifiDirect,
            "localIpAddress"     to if (connectedToWifi) {
                val ipAddress = wm.connectionInfo?.ipAddress ?: 0
                if (ipAddress != 0) {
                    String.format("%d.%d.%d.%d", 
                        (ipAddress and 0xff), 
                        (ipAddress shr 8 and 0xff), 
                        (ipAddress shr 16 and 0xff), 
                        (ipAddress shr 24 and 0xff))
                } else null
            } else null
        )
    }

    /**
     * Returns the WiFi generation label for the currently connected network.
     *
     * Must be called only when [Build.VERSION.SDK_INT] >= [Build.VERSION_CODES.R].
     * Integer literals are used instead of [android.net.wifi.WifiInfo].WIFI_STANDARD_*
     * constants to avoid Kotlin's RequiresApi check at the call site.
     *
     * Integer values (from AOSP WifiInfo.java, API 30):
     *   0 = LEGACY (802.11a/b/g)
     *   4 = 11N    (802.11n  / WiFi 4)
     *   5 = 11AC   (802.11ac / WiFi 5)
     *   6 = 11AX   (802.11ax / WiFi 6)
     *   7 = 11AX   (802.11ax 6 GHz / WiFi 6E)  — API 31
     *   8 = 11BE   (802.11be / WiFi 7)          — API 33
     */
    @RequiresApi(Build.VERSION_CODES.R)
    private fun getWifiStandard(wm: WifiManager): String {
        return try {
            @Suppress("DEPRECATION")
            val standard = wm.connectionInfo?.wifiStandard ?: -1
            when (standard) {
                0    -> "wifi4"   // LEGACY
                4    -> "wifi4"   // 802.11n
                5    -> "wifi5"   // 802.11ac
                6    -> "wifi6"   // 802.11ax
                7    -> "wifi6e"  // 802.11ax 6 GHz
                8    -> "wifi7"   // 802.11be
                else -> "unknown"
            }
        } catch (_: Exception) {
            "unknown"
        }
    }
}
