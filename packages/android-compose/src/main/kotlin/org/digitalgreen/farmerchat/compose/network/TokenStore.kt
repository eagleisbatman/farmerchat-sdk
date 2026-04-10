package org.digitalgreen.farmerchat.compose.network

/**
 * In-memory store for JWT tokens and device identity.
 * All state is held only for the lifetime of the process — the SDK has no local persistence.
 *
 * Thread-safe via @Volatile + synchronized writes.
 */
internal object TokenStore {

    @Volatile var accessToken: String = ""
        private set

    @Volatile var refreshToken: String = ""
        private set

    @Volatile var userId: String = ""
        private set

    @Volatile var deviceId: String = ""
        private set

    @Volatile var isInitialized: Boolean = false
        private set

    @Synchronized
    fun saveTokens(
        accessToken: String,
        refreshToken: String,
        userId: String,
    ) {
        this.accessToken = accessToken
        this.refreshToken = refreshToken
        this.userId = userId
        this.isInitialized = true
    }

    @Synchronized
    fun saveAccessToken(accessToken: String, refreshToken: String) {
        this.accessToken = accessToken
        if (refreshToken.isNotEmpty()) {
            this.refreshToken = refreshToken
        }
    }

    @Synchronized
    fun setDeviceId(id: String) {
        this.deviceId = id
    }

    @Synchronized
    fun clear() {
        accessToken = ""
        refreshToken = ""
        userId = ""
        isInitialized = false
        // deviceId is intentionally preserved across clear() — it must never change
    }
}
