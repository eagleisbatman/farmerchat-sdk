package org.digitalgreen.farmerchat.compose

import android.content.Context
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.digitalgreen.farmerchat.compose.crash.CrashBridge
import org.digitalgreen.farmerchat.compose.network.ApiClient
import org.digitalgreen.farmerchat.compose.network.ConnectivityMonitor
import org.digitalgreen.farmerchat.compose.network.DeviceInfoProvider
import org.digitalgreen.farmerchat.compose.network.GuestApiClient
import org.digitalgreen.farmerchat.compose.network.SdkPreferences
import org.digitalgreen.farmerchat.compose.network.TokenStore

/**
 * Main entry point for the FarmerChat Compose SDK.
 *
 * Call [initialize] once in `Application.onCreate()`:
 * ```kotlin
 * FarmerChat.initialize(
 *     context = this,
 *     config = FarmerChatConfig(
 *         baseUrl   = "https://farmerchat.farmstack.co/mobile-app-dev",
 *         sdkApiKey = "fc_test_<your_key>"
 *     )
 * )
 * ```
 */
object FarmerChat {

    private const val TAG = "FarmerChat"
    internal const val SDK_VERSION = "1.0.0"

    private var config: FarmerChatConfig? = null
    private var appContext: Context? = null
    @Volatile private var isInitialized = false
    private var sessionId: String? = null

    internal var apiClient: ApiClient? = null
    internal var connectivityMonitor: ConnectivityMonitor? = null
    internal var crashBridge: CrashBridge? = null
    internal var eventCallback: ((FarmerChatEvent) -> Unit)? = null

    private var sdkJob = SupervisorJob()
    private var sdkScope = CoroutineScope(sdkJob + Dispatchers.IO)

    // ── Initialization ────────────────────────────────────────────────────────

    /**
     * Initialize the SDK. Idempotent — safe to call more than once.
     *
     * On first call this will:
     * 1. Build the device ID and `Device-Info` header.
     * 2. Create the [ApiClient].
     * 3. Launch a background coroutine to call `initialize_user` (guest auth).
     *
     * @param context Application context
     * @param config  SDK configuration (must include a valid [FarmerChatConfig.sdkApiKey])
     */
    fun initialize(context: Context, config: FarmerChatConfig = FarmerChatConfig()) {
        if (isInitialized) return
        synchronized(this) {
            if (isInitialized) return
            try {
                val appCtx = context.applicationContext
                this.appContext = appCtx
                this.config = config
                SdkPreferences.init(appCtx)
                this.sessionId = java.util.UUID.randomUUID().toString()

                // Stable device ID (used in Device-Info header and guest init)
                val deviceId = DeviceInfoProvider.getStableDeviceId(appCtx)
                TokenStore.setDeviceId(deviceId)

                val deviceInfo = DeviceInfoProvider.buildHeader(appCtx)

                this.apiClient = ApiClient(
                    baseUrl = config.baseUrl,
                    sdkApiKey = config.sdkApiKey,
                    deviceInfo = deviceInfo,
                    timeoutMs = config.requestTimeoutMs,
                    aiReadTimeoutMs = config.aiReadTimeoutMs,
                )

                this.connectivityMonitor = ConnectivityMonitor(appCtx).also { it.start() }
                this.crashBridge = CrashBridge().also { it.detect() }
                this.isInitialized = true

                // Background: ensure guest tokens are available before first chat
                sdkScope.launch {
                    try {
                        if (!TokenStore.isInitialized) {
                            GuestApiClient(config.baseUrl).initializeUser(deviceId)
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Background guest init failed (will retry on first chat): ${e.message}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Initialization failed", e)
            }
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    /** Returns `true` if the SDK has been initialized. */
    fun isInitialized(): Boolean = isInitialized

    /**
     * Launch the full-screen FarmerChat UI.
     * [initialize] must be called first.
     */
    fun presentChat(context: Context) {
        if (!isInitialized) {
            Log.w(TAG, "presentChat() called before initialize() — ignoring")
            return
        }
        try {
            val intent = FarmerChatActivity.createIntent(context)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "presentChat failed", e)
        }
    }

    /** Returns the current SDK configuration, or defaults if not initialized. */
    fun getConfig(): FarmerChatConfig = config ?: FarmerChatConfig()

    /** Returns the session ID generated at [initialize] time. */
    fun getSessionId(): String = sessionId ?: ""

    /** Returns the application context. For SDK internal use only. */
    internal fun getContext(): Context = requireNotNull(appContext) { "FarmerChat not initialized" }

    /**
     * Register a callback for SDK lifecycle events.
     * The callback is invoked on the thread where the event originates.
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
                sdkJob.cancel()
                sdkJob = SupervisorJob()
                sdkScope = CoroutineScope(sdkJob + Dispatchers.IO)
                connectivityMonitor?.stop()
                TokenStore.clear()
                apiClient = null
                connectivityMonitor = null
                crashBridge = null
                config = null
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
