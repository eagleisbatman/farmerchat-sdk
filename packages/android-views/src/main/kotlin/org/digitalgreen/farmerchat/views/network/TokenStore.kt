package org.digitalgreen.farmerchat.views.network

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

    @Volatile var countryCode: String = ""
        private set

    @Volatile var country: String = ""
        private set

    @Volatile var state: String = ""
        private set

    @Volatile var isInitialized: Boolean = false
        private set

    @Synchronized
    fun saveTokens(
        accessToken: String,
        refreshToken: String,
        userId: String,
        countryCode: String? = null,
        country: String? = null,
        state: String? = null,
    ) {
        this.accessToken = accessToken
        this.refreshToken = refreshToken
        this.userId = userId
        if (!countryCode.isNullOrEmpty()) this.countryCode = countryCode
        if (!country.isNullOrEmpty()) this.country = country
        if (!state.isNullOrEmpty()) this.state = state
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
        countryCode = ""
        country = ""
        state = ""
        isInitialized = false
        // deviceId is intentionally preserved across clear() — it must never change
    }
}
