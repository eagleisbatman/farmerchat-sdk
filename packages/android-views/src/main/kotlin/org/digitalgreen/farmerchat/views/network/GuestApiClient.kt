package org.digitalgreen.farmerchat.views.network

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Standalone client used exclusively for guest user initialisation.
 *
 * Uses a plain `API-Key` header (not Bearer JWT).
 * Endpoint: `POST /api/user/initialize_user/`
 */
internal class GuestApiClient(private val baseUrl: String) {

    private companion object {
        const val TAG = "FC.GuestApiClient"
        const val GUEST_API_KEY = "Y2K3kW5R9uQ0fL2X8zI7hT3aJ7"
        const val PATH_INITIALIZE = "api/user/initialize_user/"
        const val TIMEOUT_MS = 30_000
    }

    suspend fun initializeUser(deviceId: String): InitializeGuestUserResponse =
        withContext(Dispatchers.IO) {
            var connection: HttpURLConnection? = null
            try {
                val url = URL("${baseUrl.trimEnd('/')}/$PATH_INITIALIZE")
                Log.d(TAG, "→ POST $url")
                connection = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = TIMEOUT_MS
                    readTimeout = TIMEOUT_MS
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("API-Key", GUEST_API_KEY)
                }

                val body = JSONObject().apply { put("device_id", deviceId) }.toString()
                OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { w ->
                    w.write(body); w.flush()
                }

                val code = connection.responseCode
                if (code !in 200..299) {
                    val error = connection.errorStream
                        ?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
                    throw ApiException(code, error)
                }

                val text = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val json = JSONObject(text)

                val response = InitializeGuestUserResponse(
                    accessToken = json.getString("access_token"),
                    refreshToken = json.getString("refresh_token"),
                    userId = json.optString("user_id", ""),
                    createdNow = json.optBoolean("created_now", false),
                    showCropsLivestocks = json.optBoolean("show_crops_livestocks", false),
                    countryCode = json.optString("country_code", null),
                    country = json.optString("country", null),
                    state = json.optString("state", null),
                )

                TokenStore.saveTokens(
                    accessToken  = response.accessToken,
                    refreshToken = response.refreshToken,
                    userId       = response.userId,
                    countryCode  = response.countryCode,
                    country      = response.country,
                    state        = response.state,
                )

                Log.d(TAG, "Guest user initialized. userId=${response.userId} countryCode=${response.countryCode}")
                response
            } finally {
                connection?.disconnect()
            }
        }
}
