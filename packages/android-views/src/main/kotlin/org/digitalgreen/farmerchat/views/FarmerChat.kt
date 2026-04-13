package org.digitalgreen.farmerchat.views

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.digitalgreen.farmerchat.views.crash.CrashBridge
import org.digitalgreen.farmerchat.views.network.ApiClient
import org.digitalgreen.farmerchat.views.network.ConnectivityMonitor
import org.digitalgreen.farmerchat.views.network.DeviceInfoProvider
import org.digitalgreen.farmerchat.views.network.GuestApiClient
import org.digitalgreen.farmerchat.views.network.TokenStore

/**
 * Main entry point for the FarmerChat XML Views SDK.
 * Initialize once in your Application.onCreate().
 */
object FarmerChat {

    private const val TAG = "FarmerChat"
    internal const val SDK_VERSION = "0.0.0"

    private var config: FarmerChatConfig? = null
    private var sdkApiKey: String? = null
    private var appContext: Context? = null
    @Volatile private var isInitialized = false
    private var sessionId: String? = null
    internal var apiClient: ApiClient? = null
        private set
    internal var guestApiClient: GuestApiClient? = null
        private set
    internal var connectivityMonitor: ConnectivityMonitor? = null
        private set
    internal var crashBridge: CrashBridge? = null
        private set
    internal var eventCallback: ((FarmerChatEvent) -> Unit)? = null
        private set

    private val sdkScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * Initialize the SDK. Call once in Application.onCreate().
     *
     * This method is idempotent — calling it more than once is a no-op.
     * All work is wrapped in try-catch so SDK initialization can never crash the host app.
     *
     * @param context   Application context
     * @param sdkApiKey Partner API key (`fc_live_*` or `fc_test_*`)
     * @param config    Optional SDK configuration
     */
    fun initialize(
        context: Context,
        sdkApiKey: String,
        config: FarmerChatConfig = FarmerChatConfig(),
    ) {
        if (isInitialized) return
        synchronized(this) {
            if (isInitialized) return
            try {
                val appCtx = context.applicationContext
                this.appContext = appCtx
                this.sdkApiKey = sdkApiKey
                this.config = config
                this.sessionId = java.util.UUID.randomUUID().toString()

                val deviceId = DeviceInfoProvider.getStableDeviceId(appCtx)
                TokenStore.setDeviceId(deviceId)
                val deviceInfo = DeviceInfoProvider.buildHeader(appCtx)

                this.guestApiClient = GuestApiClient(config.baseUrl)
                this.apiClient = ApiClient(
                    baseUrl     = config.baseUrl,
                    sdkApiKey   = sdkApiKey,
                    deviceInfo  = deviceInfo,
                    timeoutMs   = config.requestTimeoutMs,
                    aiReadTimeoutMs = config.aiReadTimeoutMs,
                )
                this.connectivityMonitor = ConnectivityMonitor(appCtx).also { it.start() }
                this.crashBridge = CrashBridge().also { it.detect() }
                this.isInitialized = true

                // Background guest token initialization
                sdkScope.launch {
                    try {
                        if (!TokenStore.isInitialized) {
                            guestApiClient?.initializeUser(deviceId)
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Background guest init failed: ${e.message}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Initialization failed", e)
            }
        }
    }

    /**
     * Check if the SDK has been initialized.
     */
    fun isInitialized(): Boolean = isInitialized

    /**
     * Returns the current SDK configuration, or defaults if not yet initialized.
     */
    fun getConfig(): FarmerChatConfig = config ?: FarmerChatConfig()

    /**
     * Returns the current session ID, or empty string if not yet initialized.
     */
    fun getSessionId(): String = sessionId ?: ""

    /**
     * Returns the application context. For SDK internal use only.
     *
     * @throws IllegalStateException if the SDK has not been initialized.
     */
    internal fun getContext(): Context = requireNotNull(appContext) { "FarmerChat not initialized" }

    /**
     * Set event callback for SDK lifecycle events.
     *
     * @param callback Invoked on the main thread for each [FarmerChatEvent].
     */
    fun setEventCallback(callback: (FarmerChatEvent) -> Unit) {
        this.eventCallback = callback
    }

    /**
     * Destroy the SDK and release all resources.
     * After calling this, [initialize] may be called again.
     */
    fun destroy() {
        synchronized(this) {
            try {
                connectivityMonitor?.stop()
                apiClient = null
                connectivityMonitor = null
                crashBridge = null
                config = null
                apiKey = null
                appContext = null
                sessionId = null
                eventCallback = null
                isInitialized = false
            } catch (e: Exception) {
                Log.e(TAG, "Destroy failed", e)
            }
        }
    }
}
