package org.digitalgreen.farmerchat.views

import android.content.Context
import android.util.Log
import org.digitalgreen.farmerchat.views.crash.CrashBridge
import org.digitalgreen.farmerchat.views.network.ApiClient
import org.digitalgreen.farmerchat.views.network.ConnectivityMonitor

/**
 * Main entry point for the FarmerChat XML Views SDK.
 * Initialize once in your Application.onCreate().
 */
object FarmerChat {

    private const val TAG = "FarmerChat"
    internal const val SDK_VERSION = "0.0.0"

    private var config: FarmerChatConfig? = null
    private var apiKey: String? = null
    private var appContext: Context? = null
    @Volatile private var isInitialized = false
    private var sessionId: String? = null
    internal var apiClient: ApiClient? = null
        private set
    internal var connectivityMonitor: ConnectivityMonitor? = null
        private set
    internal var crashBridge: CrashBridge? = null
        private set
    internal var eventCallback: ((FarmerChatEvent) -> Unit)? = null
        private set

    /**
     * Initialize the SDK. Call once in Application.onCreate().
     *
     * This method is idempotent — calling it more than once is a no-op.
     * All work is wrapped in try-catch so SDK initialization can never crash the host app.
     *
     * @param context Application context
     * @param apiKey Partner API key issued by Digital Green
     * @param config Optional SDK configuration
     */
    fun initialize(
        context: Context,
        apiKey: String,
        config: FarmerChatConfig = FarmerChatConfig(),
    ) {
        if (isInitialized) return // Idempotent — fast path without lock
        synchronized(this) {
            if (isInitialized) return // Double-check under lock
            try {
                this.appContext = context.applicationContext
                this.apiKey = apiKey
                this.config = config
                this.sessionId = java.util.UUID.randomUUID().toString()
                this.apiClient = ApiClient(
                    baseUrl = config.baseUrl,
                    apiKey = apiKey,
                    requestTimeoutMs = config.requestTimeoutMs,
                    aiReadTimeoutMs = config.aiReadTimeoutMs,
                )
                this.connectivityMonitor = ConnectivityMonitor(context.applicationContext).also { it.start() }
                this.crashBridge = CrashBridge().also { it.detect() }
                this.isInitialized = true
            } catch (e: Exception) {
                // SDK init must never crash host app
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
