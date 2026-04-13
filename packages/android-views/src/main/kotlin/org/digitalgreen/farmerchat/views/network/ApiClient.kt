package org.digitalgreen.farmerchat.views.network

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * HTTP client using [HttpURLConnection] (no OkHttp / Retrofit).
 *
 * Handles:
 * - Auth headers on every request (Authorization: Bearer, X-SDK-Key, Build-Version, Device-Info)
 * - Automatic token refresh on HTTP 401 (2-step: get_new_access_token → send_tokens fallback)
 * - All FarmerChat REST API endpoints
 *
 * @param baseUrl    API base URL (trailing slash removed internally)
 * @param sdkApiKey  Sent as `X-SDK-Key` on every authenticated request
 * @param deviceInfo Pre-built URL-encoded Device-Info header string
 * @param timeoutMs  Connect + read timeout for fast endpoints (default 15 s)
 */
internal class ApiClient(
    private val baseUrl: String,
    private val sdkApiKey: String,
    private val deviceInfo: String,
    private val timeoutMs: Int = 15_000,
    private val aiReadTimeoutMs: Int = 60_000,
) {

    private companion object {
        const val TAG = "FC.ApiClient"
        const val BUILD_VERSION = "v2"
        const val GUEST_API_KEY = "Y2K3kW5R9uQ0fL2X8zI7hT3aJ7"

        // Endpoint paths
        const val EP_GET_NEW_ACCESS_TOKEN  = "api/user/get_new_access_token/"
        const val EP_SEND_TOKENS           = "api/user/send_tokens/"
        const val EP_SUPPORTED_LANGUAGES   = "api/language/v2/country_wise_supported_languages/"
        const val EP_SET_PREFERRED_LANG    = "api/user/set_preferred_language/"
        const val EP_NEW_CONVERSATION      = "api/chat/new_conversation/"
        const val EP_TEXT_PROMPT           = "api/chat/get_answer_for_text_query/"
        const val EP_IMAGE_ANALYSIS        = "api/chat/image_analysis/"
        const val EP_FOLLOW_UP_QUESTIONS   = "api/chat/follow_up_questions/"
        const val EP_FOLLOW_UP_CLICK       = "api/chat/follow_up_question_click/"
        const val EP_SYNTHESISE_AUDIO      = "api/chat/synthesise_audio/"
        const val EP_TRANSCRIBE_AUDIO      = "api/chat/transcribe_audio/"
        const val EP_CHAT_HISTORY          = "api/chat/conversation_chat_history/"
        const val EP_CONVERSATION_LIST     = "api/chat/conversation_list/"

        val SKIP_REFRESH_PATHS = setOf(EP_GET_NEW_ACCESS_TOKEN, EP_SEND_TOKENS)
    }

    private val base = baseUrl.trimEnd('/')
    private val refreshMutex = Mutex()

    // ── Auth headers ──────────────────────────────────────────────────────────

    private fun applyAuthHeaders(connection: HttpURLConnection) {
        connection.setRequestProperty("Content-Type", "application/json")
        connection.setRequestProperty("Authorization", "Bearer ${TokenStore.accessToken}")
        connection.setRequestProperty("X-SDK-Key", sdkApiKey)
        connection.setRequestProperty("Build-Version", BUILD_VERSION)
        connection.setRequestProperty("Device-Info", deviceInfo)
    }

    // ── Generic HTTP helpers ──────────────────────────────────────────────────

    private fun openConnection(path: String): HttpURLConnection {
        val url = URL("$base/$path")
        Log.d(TAG, "→ $url")
        return (url.openConnection() as HttpURLConnection)
    }

    private fun buildQueryString(params: Map<String, String>): String =
        params.entries.joinToString("&") { (k, v) ->
            "${URLEncoder.encode(k, "UTF-8")}=${URLEncoder.encode(v, "UTF-8")}"
        }

    private fun readBody(connection: HttpURLConnection): String =
        try {
            connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } catch (_: Exception) {
            connection.errorStream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        }

    private fun readErrorBody(connection: HttpURLConnection): String =
        try {
            connection.errorStream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        } catch (_: Exception) {
            ""
        }

    /** POST JSON body; handles 401 by refreshing once and retrying. */
    private suspend fun postJson(
        path: String,
        body: JSONObject,
        skipRefresh: Boolean = false,
        readTimeout: Int = timeoutMs,
    ): String = withContext(Dispatchers.IO) {
        var connection: HttpURLConnection? = null
        try {
            connection = openConnection(path).apply {
                requestMethod = "POST"
                connectTimeout = timeoutMs
                this.readTimeout = readTimeout
                doOutput = true
                applyAuthHeaders(this)
            }
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { w ->
                w.write(body.toString()); w.flush()
            }
            val code = connection.responseCode
            if (code == HttpURLConnection.HTTP_UNAUTHORIZED && !skipRefresh && path !in SKIP_REFRESH_PATHS) {
                connection.disconnect()
                refreshTokens()
                return@withContext postJson(path, body, skipRefresh = true, readTimeout = readTimeout)
            }
            if (code !in 200..299) throw ApiException(code, readErrorBody(connection))
            readBody(connection)
        } finally {
            connection?.disconnect()
        }
    }

    /** GET with optional query params; handles 401 by refreshing once and retrying. */
    private suspend fun getJson(
        path: String,
        params: Map<String, String> = emptyMap(),
        skipRefresh: Boolean = false,
    ): String = withContext(Dispatchers.IO) {
        val fullPath = if (params.isEmpty()) path else "$path?${buildQueryString(params)}"
        var connection: HttpURLConnection? = null
        try {
            connection = openConnection(fullPath).apply {
                requestMethod = "GET"
                connectTimeout = timeoutMs
                readTimeout = timeoutMs
                applyAuthHeaders(this)
            }
            val code = connection.responseCode
            if (code == HttpURLConnection.HTTP_UNAUTHORIZED && !skipRefresh && path !in SKIP_REFRESH_PATHS) {
                connection.disconnect()
                refreshTokens()
                return@withContext getJson(path, params, skipRefresh = true)
            }
            if (code !in 200..299) throw ApiException(code, readErrorBody(connection))
            readBody(connection)
        } finally {
            connection?.disconnect()
        }
    }

    // ── Token refresh (2-step) ────────────────────────────────────────────────

    private suspend fun refreshTokens() = refreshMutex.withLock {
        withContext(Dispatchers.IO) {
            if (TokenStore.accessToken.isNotEmpty() && tryRefreshStep1()) return@withContext
            tryRefreshStep2()
        }
    }

    private suspend fun tryRefreshStep1(): Boolean = withContext(Dispatchers.IO) {
        var connection: HttpURLConnection? = null
        return@withContext try {
            val body = JSONObject().apply { put("refresh_token", TokenStore.refreshToken) }
            connection = openConnection(EP_GET_NEW_ACCESS_TOKEN).apply {
                requestMethod = "POST"
                connectTimeout = timeoutMs
                readTimeout = timeoutMs
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("X-SDK-Key", sdkApiKey)
            }
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { w ->
                w.write(body.toString()); w.flush()
            }
            val code = connection.responseCode
            if (code !in 200..299) return@withContext false
            val json = JSONObject(readBody(connection))
            val at = json.optString("access_token", "")
            val rt = json.optString("refresh_token", "")
            if (at.isEmpty()) return@withContext false
            TokenStore.saveAccessToken(at, rt)
            Log.d(TAG, "Token refreshed via step 1")
            true
        } catch (e: Exception) {
            Log.w(TAG, "Step 1 token refresh failed: ${e.message}")
            false
        } finally {
            connection?.disconnect()
        }
    }

    private suspend fun tryRefreshStep2() = withContext(Dispatchers.IO) {
        var connection: HttpURLConnection? = null
        try {
            val body = JSONObject().apply {
                put("device_id", TokenStore.deviceId)
                put("user_id", TokenStore.userId)
            }
            connection = openConnection(EP_SEND_TOKENS).apply {
                requestMethod = "POST"
                connectTimeout = timeoutMs
                readTimeout = timeoutMs
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("X-SDK-Key", sdkApiKey)
                setRequestProperty("API-Key", GUEST_API_KEY)
            }
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { w ->
                w.write(body.toString()); w.flush()
            }
            val code = connection.responseCode
            if (code !in 200..299) throw ApiException(code, readErrorBody(connection))
            val json = JSONObject(readBody(connection))
            val at = json.optString("access_token", "")
            val rt = json.optString("refresh_token", "")
            if (at.isNotEmpty()) {
                TokenStore.saveAccessToken(at, rt)
                Log.d(TAG, "Token refreshed via step 2")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Step 2 token refresh failed: ${e.message}", e)
        } finally {
            connection?.disconnect()
        }
    }

    // ── Public API — Conversation list (History) ───────────────────────────────

    suspend fun getConversationList(): List<ConversationListItem> {
        return try {
            val params = mapOf("user_id" to TokenStore.userId, "page" to "1")
            val text = getJson(EP_CONVERSATION_LIST, params)
            val array = JSONArray(text)
            (0 until array.length()).map { ConversationListItem.fromJson(array.getJSONObject(it)) }
        } catch (e: Exception) {
            Log.e(TAG, "getConversationList failed: ${e.message}", e)
            throw e
        }
    }

    // ── Public API — Languages ────────────────────────────────────────────────

    suspend fun getSupportedLanguages(
        countryCode: String = "",
        state: String = "",
    ): List<SupportedLanguageGroup> {
        return try {
            val params = mutableMapOf<String, String>()
            if (countryCode.isNotEmpty()) params["country_code"] = countryCode
            if (state.isNotEmpty()) params["state"] = state
            val text = getJson(EP_SUPPORTED_LANGUAGES, params)
            val array = JSONArray(text)
            (0 until array.length()).map { SupportedLanguageGroup.fromJson(array.getJSONObject(it)) }
        } catch (e: Exception) {
            Log.e(TAG, "getSupportedLanguages failed: ${e.message}", e)
            throw e
        }
    }

    suspend fun setPreferredLanguage(userId: String, languageId: String) {
        try {
            val body = JSONObject().apply {
                put("user_id", userId)
                put("language_id", languageId)
            }
            postJson(EP_SET_PREFERRED_LANG, body)
        } catch (e: Exception) {
            Log.w(TAG, "setPreferredLanguage failed: ${e.message}")
        }
    }

    // ── Public API — New conversation ─────────────────────────────────────────

    suspend fun createNewConversation(contentProviderId: String?): NewConversationResponse {
        val body = JSONObject().apply {
            put("user_id", TokenStore.userId)
            if (contentProviderId != null) put("content_provider_id", contentProviderId)
        }
        val text = postJson(EP_NEW_CONVERSATION, body)
        return NewConversationResponse.fromJson(JSONObject(text))
    }

    // ── Public API — Text prompt ──────────────────────────────────────────────

    suspend fun sendTextPrompt(
        query: String,
        conversationId: String,
        messageId: String,
        triggeredInputType: String = "text",
        transcriptionId: String? = null,
    ): TextPromptResponse {
        val body = JSONObject().apply {
            put("query", query)
            put("conversation_id", conversationId)
            put("message_id", messageId)
            put("triggered_input_type", triggeredInputType)
            put("use_entity_extraction", true)
            put("weather_cta_triggered", false)
            put("retry", false)
            if (transcriptionId != null) put("transcription_id", transcriptionId)
        }
        val text = postJson(EP_TEXT_PROMPT, body, readTimeout = aiReadTimeoutMs)
        return TextPromptResponse.fromJson(JSONObject(text))
    }

    // ── Public API — Follow-up questions ──────────────────────────────────────

    suspend fun getFollowUpQuestions(messageId: String): List<FollowUpQuestionOption> {
        return try {
            val text = getJson(
                EP_FOLLOW_UP_QUESTIONS,
                mapOf("message_id" to messageId, "use_latest_prompt" to "true"),
            )
            val json = JSONObject(text)
            val arr = json.optJSONArray("questions") ?: JSONArray()
            (0 until arr.length()).map { FollowUpQuestionOption.fromJson(arr.getJSONObject(it)) }
        } catch (e: Exception) {
            Log.w(TAG, "getFollowUpQuestions failed: ${e.message}")
            emptyList()
        }
    }

    suspend fun trackFollowUpClick(followUpQuestion: String) {
        try {
            val body = JSONObject().apply { put("follow_up_question", followUpQuestion) }
            postJson(EP_FOLLOW_UP_CLICK, body)
        } catch (e: Exception) {
            Log.w(TAG, "trackFollowUpClick failed: ${e.message}")
        }
    }

    // ── Public API — TTS ──────────────────────────────────────────────────────

    suspend fun synthesiseAudio(messageId: String, text: String): SynthesiseAudioResponse {
        val body = JSONObject().apply {
            put("message_id", messageId)
            put("text", text)
            put("user_id", TokenStore.userId)
        }
        val responseText = postJson(EP_SYNTHESISE_AUDIO, body, readTimeout = aiReadTimeoutMs)
        return SynthesiseAudioResponse.fromJson(JSONObject(responseText))
    }

    // ── Public API — SSE streaming (text prompt stream) ──────────────────────

    fun sendQueryStream(
        query: String,
        conversationId: String,
        messageId: String,
        triggeredInputType: String = "text",
    ): Flow<SseEvent> = flow {
        var connection: HttpURLConnection? = null
        try {
            val body = JSONObject().apply {
                put("query", query)
                put("conversation_id", conversationId)
                put("message_id", messageId)
                put("triggered_input_type", triggeredInputType)
                put("use_entity_extraction", true)
                put("weather_cta_triggered", false)
                put("retry", false)
            }

            connection = openConnection(EP_TEXT_PROMPT).apply {
                requestMethod = "POST"
                connectTimeout = timeoutMs
                readTimeout = aiReadTimeoutMs
                doOutput = true
                setRequestProperty("Accept", "text/event-stream")
                applyAuthHeaders(this)
            }

            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { w ->
                w.write(body.toString()); w.flush()
            }

            val code = connection.responseCode
            if (code !in 200..299) {
                emit(SseEvent("error", JSONObject().apply {
                    put("code", code)
                    put("message", readErrorBody(connection))
                }.toString()))
                return@flow
            }

            val contentType = connection.contentType.orEmpty()

            if (contentType.contains("text/event-stream")) {
                val reader = BufferedReader(
                    InputStreamReader(connection.inputStream, Charsets.UTF_8),
                )
                var currentEvent = ""
                val currentDataLines = mutableListOf<String>()
                var receivedDone = false

                reader.use {
                    var line = reader.readLine()
                    while (line != null) {
                        when {
                            line.startsWith("event:") -> {
                                val v = line.removePrefix("event:")
                                currentEvent = if (v.startsWith(" ")) v.substring(1) else v
                            }
                            line.startsWith("data:") -> {
                                val v = line.removePrefix("data:")
                                currentDataLines.add(if (v.startsWith(" ")) v.substring(1) else v)
                            }
                            line.isBlank() -> {
                                if (currentEvent.isNotEmpty() && currentDataLines.isNotEmpty()) {
                                    val data = currentDataLines.joinToString("\n")
                                    emit(SseEvent(currentEvent, data))
                                    if (currentEvent == "done") receivedDone = true
                                }
                                currentEvent = ""
                                currentDataLines.clear()
                            }
                        }
                        line = reader.readLine()
                    }
                }
                if (!receivedDone) emit(SseEvent("done", "{}"))
            } else {
                val responseText = connection.inputStream.bufferedReader(Charsets.UTF_8)
                    .use { it.readText() }
                emit(SseEvent("message", responseText))
                emit(SseEvent("done", "{}"))
            }
        } catch (e: Exception) {
            Log.w(TAG, "sendQueryStream error", e)
            emit(SseEvent("error", JSONObject().apply {
                put("code", 0)
                put("message", e.message.orEmpty())
            }.toString()))
        } finally {
            connection?.disconnect()
        }
    }.flowOn(Dispatchers.IO)
}

/**
 * Exception representing an HTTP error from the FarmerChat API.
 */
internal class ApiException(
    val statusCode: Int,
    val errorBody: String,
) : IOException("HTTP $statusCode: $errorBody")
