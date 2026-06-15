package dev.ethersynapse.ether_synapse

import android.annotation.SuppressLint
import android.content.Context
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pManager
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class WifiDirectManager(private val context: Context, private val channel: MethodChannel) {
    private val manager: WifiP2pManager? by lazy(LazyThreadSafetyMode.NONE) {
        context.getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager?
    }
    private var channelP2p: WifiP2pManager.Channel? = null

    init {
        channelP2p = manager?.initialize(context, Looper.getMainLooper(), null)
    }

    @SuppressLint("MissingPermission")
    fun createGroup(callback: (Boolean, String?) -> Unit) {
        if (manager == null || channelP2p == null) {
            callback(false, "WifiP2pManager not available")
            return
        }

        manager?.createGroup(channelP2p, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                // Group created successfully, now get connection info
                manager?.requestConnectionInfo(channelP2p) { info ->
                    if (info != null && info.groupFormed) {
                        val hostIp = info.groupOwnerAddress?.hostAddress
                        callback(true, hostIp)
                    } else {
                        callback(true, null)
                    }
                }
            }

            override fun onFailure(reason: Int) {
                callback(false, "Failed with reason code: $reason")
            }
        })
    }

    @SuppressLint("MissingPermission")
    fun removeGroup(callback: (Boolean) -> Unit) {
        if (manager == null || channelP2p == null) {
            callback(false)
            return
        }

        manager?.removeGroup(channelP2p, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                callback(true)
            }

            override fun onFailure(reason: Int) {
                callback(false)
            }
        })
    }
    
    fun requestConnectionInfo(callback: (String?) -> Unit) {
        if (manager == null || channelP2p == null) {
            callback(null)
            return
        }
        manager?.requestConnectionInfo(channelP2p) { info ->
            if (info != null && info.groupFormed) {
                callback(info.groupOwnerAddress?.hostAddress)
            } else {
                callback(null)
            }
        }
    }
}
