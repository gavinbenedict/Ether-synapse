package dev.ethersynapse.ether_synapse

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_SETTINGS     = "dev.ethersynapse/settings"
        private const val CHANNEL_CAPABILITIES = "dev.ethersynapse/capabilities"
        private const val CHANNEL_GATT         = "dev.ethersynapse/gatt"
        private const val CHANNEL_MEDIA        = "dev.ethersynapse/media"
    }
    
    private var gattServerManager: GattServerManager? = null
    private var wifiDirectManager: WifiDirectManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerSettingsChannel(flutterEngine)
        registerCapabilitiesChannel(flutterEngine)
        registerGattChannel(flutterEngine)
        registerWifiDirectChannel(flutterEngine)
        registerMediaChannel(flutterEngine)
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

    // ── Media / file-save channel ─────────────────────────────────────────────
    //
    // Called by Dart after a file has been fully received over TCP.
    // Copies the file from app-private temp storage into the appropriate
    // public MediaStore collection (API 29+) or public directory (API <29)
    // and returns the final public path back to Dart.

    private fun registerMediaChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_MEDIA)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToPublic") {
                    val srcPath   = call.argument<String>("srcPath")   ?: return@setMethodCallHandler result.error("BAD_ARGS", "srcPath missing", null)
                    val fileName  = call.argument<String>("fileName")  ?: return@setMethodCallHandler result.error("BAD_ARGS", "fileName missing", null)
                    val mimeType  = call.argument<String>("mimeType")  ?: "application/octet-stream"
                    try {
                        val publicPath = saveFileToPublic(srcPath, fileName, mimeType)
                        Log.d("EtherSynapse", "[FILE SAVE] public path: $publicPath")
                        result.success(publicPath)
                    } catch (e: Exception) {
                        Log.e("EtherSynapse", "[FILE SAVE] failed: $e")
                        result.error("SAVE_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /** Saves [srcPath] to a public folder determined by [mimeType]. Returns the final path. */
    private fun saveFileToPublic(srcPath: String, fileName: String, mimeType: String): String {
        val srcFile = File(srcPath)
        require(srcFile.exists()) { "Source file not found: $srcPath" }

        val category = mimeType.substringBefore("/")

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // API 29+: Use MediaStore
            saveViaMediaStore(srcFile, fileName, mimeType, category)
        } else {
            // API <29: Write directly to public directory
            saveLegacy(srcFile, fileName, category)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveViaMediaStore(
        src: File, fileName: String, mimeType: String, category: String
    ): String {
        val (collection, relPath) = when (category) {
            "image" -> Pair(
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                Environment.DIRECTORY_PICTURES + "/EtherSynapse"
            )
            "video" -> Pair(
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                Environment.DIRECTORY_MOVIES + "/EtherSynapse"
            )
            "audio" -> Pair(
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                Environment.DIRECTORY_MUSIC + "/EtherSynapse"
            )
            else    -> Pair(
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                Environment.DIRECTORY_DOWNLOADS + "/EtherSynapse"
            )
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relPath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri: Uri = contentResolver.insert(collection, values)
            ?: throw RuntimeException("MediaStore insert returned null for $fileName")

        contentResolver.openOutputStream(uri)?.use { out ->
            src.inputStream().use { it.copyTo(out) }
        }

        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        contentResolver.update(uri, values, null, null)

        Log.d("EtherSynapse", "[MEDIASTORE] inserted: $uri")

        // Resolve to real path for Dart (best effort)
        return try {
            contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) cursor.getString(0) else uri.toString()
                } ?: uri.toString()
        } catch (_: Exception) {
            uri.toString()
        }
    }

    private fun saveLegacy(src: File, fileName: String, category: String): String {
        val dir = when (category) {
            "image" -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            "video" -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
            "audio" -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
            else    -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        }
        val dest = File(File(dir, "EtherSynapse").also { it.mkdirs() }, fileName)
        src.copyTo(dest, overwrite = true)

        // Notify MediaScanner so Gallery picks it up immediately
        val intent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
        intent.data = Uri.fromFile(dest)
        sendBroadcast(intent)

        Log.d("EtherSynapse", "[FILE SAVE] legacy path: ${dest.absolutePath}")
        return dest.absolutePath
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
