package org.digitalgreen.farmerchat.compose.network

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
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
 * @param baseUrl   API base URL (trailing slash removed internally)
 * @param sdkApiKey Sent as `X-SDK-Key` on every authenticated request
 * @param deviceInfo Pre-built URL-encoded Device-Info header string
 * @param timeoutMs Connect + read timeout (default 15 s)
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

        // Endpoint paths (relative to baseUrl)
        const val EP_INITIALIZE_USER       = "api/user/initialize_user/"
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

        /** Paths that must NOT trigger the 401 token-refresh logic. */
        val SKIP_REFRESH_PATHS = setOf(
            EP_GET_NEW_ACCESS_TOKEN,
            EP_SEND_TOKENS,
            EP_INITIALIZE_USER,
        )
    }

    private val base = baseUrl.trimEnd('/')

    /** Mutex ensures only one token-refresh happens at a time across concurrent coroutines. */
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
        Log.d(TAG, "→ ${url.toString().replace(base, "[base]")}")
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

    /**
     * POST JSON body; returns raw response string.
     * Handles 401 by triggering token refresh and retrying once.
     *
     * @param readTimeout Override read timeout for this call (defaults to [timeoutMs]).
     *                    Pass [aiReadTimeoutMs] for inference endpoints.
     */
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

    /**
     * GET with optional query params; returns raw response string.
     * Handles 401 by triggering token refresh and retrying once.
     *
     * @param readTimeout Override read timeout for this call (defaults to [timeoutMs]).
     */
    private suspend fun getJson(
        path: String,
        params: Map<String, String> = emptyMap(),
        skipRefresh: Boolean = false,
        readTimeout: Int = timeoutMs,
    ): String = withContext(Dispatchers.IO) {
        var connection: HttpURLConnection? = null
        try {
            val fullPath = if (params.isEmpty()) path else "$path?${buildQueryString(params)}"
            connection = openConnection(fullPath).apply {
                requestMethod = "GET"
                connectTimeout = timeoutMs
                this.readTimeout = readTimeout
                applyAuthHeaders(this)
            }
            val code = connection.responseCode
            if (code == HttpURLConnection.HTTP_UNAUTHORIZED && !skipRefresh && path !in SKIP_REFRESH_PATHS) {
                connection.disconnect()
                refreshTokens()
                return@withContext getJson(path, params, skipRefresh = true, readTimeout = readTimeout)
            }
            if (code !in 200..299) throw ApiException(code, readErrorBody(connection))
            readBody(connection)
        } finally {
            connection?.disconnect()
        }
    }

    // ── Token refresh (2-step) ────────────────────────────────────────────────

    /**
     * Step 1: POST /api/user/get_new_access_token/ with refresh_token.
     * Step 2 (fallback): POST /api/user/send_tokens/ with device_id + user_id.
     *
     * Only one refresh runs at a time (Mutex). All concurrent callers wait and
     * receive the same new token.
     */
    private suspend fun refreshTokens() = refreshMutex.withLock {
        withContext(Dispatchers.IO) {
            // Step 1
            var succeeded = false
            try {
                val body = JSONObject().apply { put("refresh_token", TokenStore.refreshToken) }
                var conn: HttpURLConnection? = null
                try {
                    conn = openConnection(EP_GET_NEW_ACCESS_TOKEN).apply {
                        requestMethod = "POST"
                        connectTimeout = timeoutMs
                        readTimeout = timeoutMs
                        doOutput = true
                        setRequestProperty("Content-Type", "application/json")
                        setRequestProperty("X-SDK-Key", sdkApiKey)
                        setRequestProperty("Build-Version", BUILD_VERSION)
                        setRequestProperty("Device-Info", deviceInfo)
                    }
                    OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { w ->
                        w.write(body.toString()); w.flush()
                    }
                    if (conn.responseCode in 200..299) {
                        val text = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                        val json = JSONObject(text)
                        val newAccess = json.optString("access_token", "")
                        val newRefresh = json.optString("refresh_token", "")
                        if (newAccess.isNotEmpty()) {
                            TokenStore.saveAccessToken(newAccess, newRefresh)
                            succeeded = true
                            Log.d(TAG, "Token refresh (step 1) succeeded")
                        }
                    }
                } finally {
                    conn?.disconnect()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Token refresh step 1 failed: ${e.message}")
            }

            // Step 2 (fallback)
            if (!succeeded) {
                try {
                    val body = JSONObject().apply {
                        put("device_id", TokenStore.deviceId)
                        put("user_id", TokenStore.userId)
                    }
                    var conn: HttpURLConnection? = null
                    try {
                        conn = openConnection(EP_SEND_TOKENS).apply {
                            requestMethod = "POST"
                            connectTimeout = timeoutMs
                            readTimeout = timeoutMs
                            doOutput = true
                            setRequestProperty("Content-Type", "application/json")
                            setRequestProperty("API-Key", GUEST_API_KEY)
                            setRequestProperty("Build-Version", BUILD_VERSION)
                        }
                        OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { w ->
                            w.write(body.toString()); w.flush()
                        }
                        if (conn.responseCode in 200..299) {
                            val text = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                            val json = JSONObject(text)
                            val newAccess = json.optString("access_token", "")
                            val newRefresh = json.optString("refresh_token", "")
                            if (newAccess.isNotEmpty()) {
                                TokenStore.saveAccessToken(newAccess, newRefresh)
                                Log.d(TAG, "Token refresh (step 2 fallback) succeeded")
                            }
                        }
                    } finally {
                        conn?.disconnect()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Token refresh step 2 failed: ${e.message}")
                }
            }
        }
    }

    // ── Language API (Android-only) ───────────────────────────────────────────

    /**
     * GET country-wise supported languages.
     *
     * @param countryCode ISO country code, e.g. "IN" (empty = all countries)
     * @param state State name for regional filtering (empty = all states)
     */
    suspend fun getSupportedLanguages(
        countryCode: String = "",
        state: String = "",
    ): List<SupportedLanguageGroup> {
        return try {
            val params = buildMap<String, String> {
                if (countryCode.isNotEmpty()) put("country_code", countryCode)
                if (state.isNotEmpty()) put("state", state)
            }
            val text = getJson(EP_SUPPORTED_LANGUAGES, params)
            JSONArray(text).mapObjects { SupportedLanguageGroup.fromJson(it) }
        } catch (e: Exception) {
            Log.w(TAG, "getSupportedLanguages failed: ${e.message}")
            throw e
        }
    }

    /**
     * POST set the user's preferred language.
     *
     * @param userId     User ID from [TokenStore]
     * @param languageId [SupportedLanguage.id] as a String
     */
    suspend fun setPreferredLanguage(userId: String, languageId: String): SetPreferredLanguageResponse {
        return try {
            val body = JSONObject().apply {
                put("user_id", userId)
                put("language_id", languageId)
            }
            val text = postJson(EP_SET_PREFERRED_LANG, body)
            SetPreferredLanguageResponse.fromJson(JSONObject(text))
        } catch (e: Exception) {
            Log.w(TAG, "setPreferredLanguage failed: ${e.message}")
            throw e
        }
    }

    // ── Chat API ──────────────────────────────────────────────────────────────

    /**
     * POST create a new conversation.
     *
     * @param userId            User ID from [TokenStore]
     * @param contentProviderId Optional multi-tenant ID from [FarmerChatConfig]
     */
    suspend fun newConversation(
        userId: String,
        contentProviderId: String?,
    ): NewConversationResponse {
        return try {
            val body = JSONObject().apply {
                put("user_id", userId)
                if (contentProviderId != null) put("content_provider_id", contentProviderId)
            }
            val text = postJson(EP_NEW_CONVERSATION, body)
            NewConversationResponse.fromJson(JSONObject(text))
        } catch (e: Exception) {
            Log.w(TAG, "newConversation failed: ${e.message}")
            throw e
        }
    }

    /**
     * POST send a text (or follow-up / audio) query and get a full AI response.
     *
     * @param query                 User's query text
     * @param conversationId        Active conversation ID
     * @param messageId             Client-generated UUID for this message
     * @param triggeredInputType    "text" | "audio" | "follow_up"
     * @param transcriptionId       Only for audio queries (from transcribeAudio response)
     * @param weatherCtaTriggered   Optional weather CTA flag
     * @param useEntityExtraction   Default true
     * @param retry                 True if this is a retry of a previous failed request
     */
    suspend fun sendTextPrompt(
        query: String,
        conversationId: String,
        messageId: String,
        triggeredInputType: String = "text",
        transcriptionId: String? = null,
        weatherCtaTriggered: Boolean = false,
        useEntityExtraction: Boolean = true,
        retry: Boolean = false,
    ): TextPromptResponse {
        return try {
            val body = JSONObject().apply {
                put("query", query)
                put("conversation_id", conversationId)
                put("message_id", messageId)
                put("triggered_input_type", triggeredInputType)
                put("weather_cta_triggered", weatherCtaTriggered)
                put("use_entity_extraction", useEntityExtraction)
                put("retry", retry)
                if (transcriptionId != null) put("transcription_id", transcriptionId)
            }
            val text = postJson(EP_TEXT_PROMPT, body, readTimeout = aiReadTimeoutMs)
            TextPromptResponse.fromJson(JSONObject(text))
        } catch (e: Exception) {
            Log.w(TAG, "sendTextPrompt failed: ${e.message}")
            throw e
        }
    }

    /**
     * POST analyze a plant image (Plantix integration).
     *
     * @param conversationId  Active conversation ID
     * @param base64Image     Base64-encoded JPEG image
     * @param imageName       e.g. "image_<uuid>.jpg"
     * @param latitude        GPS latitude from image EXIF (null if unavailable)
     * @param longitude       GPS longitude from image EXIF (null if unavailable)
     * @param query           Optional text alongside the image
     * @param retry           True if retry
     */
    suspend fun imageAnalysis(
        conversationId: String,
        base64Image: String,
        imageName: String,
        latitude: String? = null,
        longitude: String? = null,
        query: String? = null,
        retry: Boolean = false,
    ): PlantixResponse {
        return try {
            val body = JSONObject().apply {
                put("conversation_id", conversationId)
                put("image", base64Image)
                put("triggered_input_type", "image")
                put("image_name", imageName)
                put("retry", retry)
                if (latitude != null) put("latitude", latitude)
                if (longitude != null) put("longitude", longitude)
                if (query != null) put("query", query)
            }
            val text = postJson(EP_IMAGE_ANALYSIS, body, readTimeout = aiReadTimeoutMs)
            PlantixResponse.fromJson(JSONObject(text))
        } catch (e: Exception) {
            Log.w(TAG, "imageAnalysis failed: ${e.message}")
            throw e
        }
    }

    /**
     * GET follow-up questions for a message.
     */
    suspend fun getFollowUpQuestions(
        messageId: String,
        useLatestPrompt: Boolean = true,
    ): FollowUpQuestionsResponse {
        return try {
            val params = mapOf(
                "message_id" to messageId,
                "use_latest_prompt" to useLatestPrompt.toString(),
            )
            val text = getJson(EP_FOLLOW_UP_QUESTIONS, params)
            FollowUpQuestionsResponse.fromJson(JSONObject(text))
        } catch (e: Exception) {
            Log.w(TAG, "getFollowUpQuestions failed: ${e.message}")
            throw e
        }
    }

    /**
     * POST track a follow-up question click (fire-and-forget).
     */
    suspend fun trackFollowUpClick(followUpQuestion: String) {
        try {
            val body = JSONObject().apply { put("follow_up_question", followUpQuestion) }
            postJson(EP_FOLLOW_UP_CLICK, body)
        } catch (e: Exception) {
            Log.w(TAG, "trackFollowUpClick failed: ${e.message}")
        }
    }

    /**
     * POST synthesise audio (TTS).
     *
     * @param messageId Server message ID
     * @param text      Text to synthesise
     * @param userId    User ID from [TokenStore]
     */
    suspend fun synthesiseAudio(
        messageId: String,
        text: String,
        userId: String,
    ): SynthesiseAudioResponse {
        return try {
            val body = JSONObject().apply {
                put("message_id", messageId)
                put("text", text)
                put("user_id", userId)
            }
            val responseText = postJson(EP_SYNTHESISE_AUDIO, body, readTimeout = aiReadTimeoutMs)
            SynthesiseAudioResponse.fromJson(JSONObject(responseText))
        } catch (e: Exception) {
            Log.w(TAG, "synthesiseAudio failed: ${e.message}")
            throw e
        }
    }

    /**
     * POST transcribe audio (STT). Android sends JSON with base64 audio.
     *
     * @param conversationId          Active conversation ID
     * @param base64Audio             Base64-encoded audio data
     * @param messageReferenceId      Client-generated reference ID
     * @param inputAudioEncodingFormat "LINEAR16" | "AMR" | "MP3" | "AAC" etc.
     */
    suspend fun transcribeAudio(
        conversationId: String,
        base64Audio: String,
        messageReferenceId: String,
        inputAudioEncodingFormat: String = "AMR",
    ): GetVoiceResponse {
        return try {
            val body = JSONObject().apply {
                put("conversation_id", conversationId)
                put("query", base64Audio)
                put("message_reference_id", messageReferenceId)
                put("input_audio_encoding_format", inputAudioEncodingFormat)
                put("triggered_input_type", "audio")
                put("editable_transcription", "True")
            }
            val text = postJson(EP_TRANSCRIBE_AUDIO, body, readTimeout = aiReadTimeoutMs)
            GetVoiceResponse.fromJson(JSONObject(text))
        } catch (e: Exception) {
            Log.w(TAG, "transcribeAudio failed: ${e.message}")
            throw e
        }
    }

    // ── History API ───────────────────────────────────────────────────────────

    /**
     * GET paginated conversation list for the current user.
     *
     * @param userId User ID from [TokenStore]
     * @param page   1-indexed page number
     */
    suspend fun getConversationList(
        userId: String,
        page: Int = 1,
    ): List<ConversationListItem> {
        return try {
            val params = mapOf("user_id" to userId, "page" to page.toString())
            val text = getJson(EP_CONVERSATION_LIST, params)
            JSONArray(text).mapObjects { ConversationListItem.fromJson(it) }
        } catch (e: Exception) {
            Log.w(TAG, "getConversationList failed: ${e.message}")
            throw e
        }
    }

    /**
     * GET messages within a specific conversation.
     *
     * @param conversationId The conversation to load
     * @param page           1-indexed page number
     */
    suspend fun getChatHistory(
        conversationId: String,
        page: Int = 1,
    ): ConversationChatHistoryResponse {
        return try {
            val params = mapOf("conversation_id" to conversationId, "page" to page.toString())
            val text = getJson(EP_CHAT_HISTORY, params)
            ConversationChatHistoryResponse.fromJson(JSONObject(text))
        } catch (e: Exception) {
            Log.w(TAG, "getChatHistory failed: ${e.message}")
            throw e
        }
    }
}

/**
 * Exception representing an HTTP error from the FarmerChat API.
 */
internal class ApiException(
    val statusCode: Int,
    val errorBody: String,
) : IOException("HTTP $statusCode: $errorBody")
