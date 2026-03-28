package org.digitalgreen.farmerchat.compose.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Monitors network connectivity via [ConnectivityManager.registerDefaultNetworkCallback].
 *
 * Exposes a [StateFlow] that emits `true` when the device has an active internet-capable
 * connection, and `false` otherwise. UI layers observe this to show/hide the connectivity banner.
 *
 * Requires API 24+ (minSdk 26 satisfies this).
 *
 * All callback methods are wrapped in try-catch — this class must NEVER crash the host app.
 *
 * @param context Application context for accessing ConnectivityManager
 */
internal class ConnectivityMonitor(context: Context) {

    private companion object {
        const val TAG = "FC.Connectivity"
    }

    private val connectivityManager: ConnectivityManager? = try {
        context.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
    } catch (e: Exception) {
        Log.w(TAG, "Failed to obtain ConnectivityManager", e)
        null
    }

    private val _isConnected = MutableStateFlow(checkCurrentConnectivity())

    /** Observable connectivity state. `true` when the device has internet. */
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    /**
     * Start monitoring network connectivity changes.
     * Safe to call multiple times — subsequent calls are no-ops.
     */
    fun start() {
        try {
            if (networkCallback != null) return // already registered

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    try {
                        _isConnected.value = true
                        Log.d(TAG, "Network available")
                    } catch (e: Exception) {
                        Log.w(TAG, "Error in onAvailable", e)
                    }
                }

                override fun onLost(network: Network) {
                    try {
                        _isConnected.value = false
                        Log.d(TAG, "Network lost")
                    } catch (e: Exception) {
                        Log.w(TAG, "Error in onLost", e)
                    }
                }

                override fun onCapabilitiesChanged(
                    network: Network,
                    capabilities: NetworkCapabilities,
                ) {
                    try {
                        val hasInternet = capabilities.hasCapability(
                            NetworkCapabilities.NET_CAPABILITY_INTERNET,
                        ) && capabilities.hasCapability(
                            NetworkCapabilities.NET_CAPABILITY_VALIDATED,
                        )
                        _isConnected.value = hasInternet
                    } catch (e: Exception) {
                        Log.w(TAG, "Error in onCapabilitiesChanged", e)
                    }
                }
            }

            networkCallback = callback
            connectivityManager?.registerDefaultNetworkCallback(callback)
            Log.d(TAG, "Started monitoring connectivity")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to start connectivity monitoring", e)
        }
    }

    /**
     * Stop monitoring and unregister callbacks.
     * Safe to call multiple times — subsequent calls are no-ops.
     */
    fun stop() {
        try {
            networkCallback?.let { callback ->
                connectivityManager?.unregisterNetworkCallback(callback)
                networkCallback = null
                Log.d(TAG, "Stopped monitoring connectivity")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to stop connectivity monitoring", e)
        }
    }

    /**
     * Synchronously check the current connectivity state.
     * Used to seed the initial [StateFlow] value.
     */
    private fun checkCurrentConnectivity(): Boolean {
        return try {
            val network = connectivityManager?.activeNetwork ?: return false
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to check current connectivity", e)
            false
        }
    }
}
