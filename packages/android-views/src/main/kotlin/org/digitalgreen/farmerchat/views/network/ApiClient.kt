package org.digitalgreen.farmerchat.views.network

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext
import org.digitalgreen.farmerchat.views.FarmerChat
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
 * HTTP client using [HttpURLConnection] (no OkHttp).
 *
 * All network calls run on [Dispatchers.IO]. JSON is parsed with the built-in [org.json]
 * package — no Gson, Moshi, or kotlinx.serialization dependency.
 *
 * Every public method is wrapped in try-catch so that a network failure never propagates
 * an unchecked exception to the host app.
 *
 * @param baseUrl API base URL
 * @param apiKey Partner API key for authentication
 * @param requestTimeoutMs Timeout for standard HTTP requests in milliseconds
 * @param sseTimeoutMs Timeout for SSE streaming connections in milliseconds
 */
internal class ApiClient(
    private val baseUrl: String,
    private val apiKey: String,
    private val requestTimeoutMs: Int = 15_000,
    private val sseTimeoutMs: Int = 30_000,
) {

    init {
        require(baseUrl.startsWith("http://", ignoreCase = true) || baseUrl.startsWith("https://", ignoreCase = true)) {
            "baseUrl must use http:// or https://"
        }
    }

    private companion object {
        const val TAG = "FC.ApiClient"

        // API endpoint paths (mirrors core/src/api/endpoints.ts)
        const val EP_CHAT_SEND = "/v1/chat/send"
        const val EP_FEEDBACK = "/v1/chat/feedback"
        const val EP_HISTORY = "/v1/chat/history"
        const val EP_LANGUAGES = "/v1/config/languages"
        const val EP_STARTERS = "/v1/config/starters"
        const val EP_TTS = "/v1/chat/tts"
        const val EP_ONBOARDING = "/v1/user/onboarding"
    }

    // ── Default headers ──────────────────────────────────────────────

    private fun defaultHeaders(): Map<String, String> = mapOf(
        "Content-Type" to "application/json",
        "Authorization" to "Bearer $apiKey",
        "X-SDK-Version" to FarmerChat.SDK_VERSION,
    )

    // ── Generic HTTP helpers ─────────────────────────────────────────

    /**
     * Execute a POST request and return the parsed [JSONObject] response body.
     *
     * @throws ApiException on non-2xx status codes.
     * @throws IOException on network errors.
     */
    @Suppress("TooGenericExceptionCaught")
    private suspend fun postJson(endpoint: String, body: JSONObject): JSONObject =
        withContext(Dispatchers.IO) {
            var connection: HttpURLConnection? = null
            try {
                connection = openConnection(endpoint).apply {
                    requestMethod = "POST"
                    connectTimeout = requestTimeoutMs
                    readTimeout = requestTimeoutMs
                    doOutput = true
                    applyHeaders(defaultHeaders())
                }

                OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                    writer.write(body.toString())
                    writer.flush()
                }

                val code = connection.responseCode
                if (code !in 200..299) {
                    val errorBody = readErrorBody(connection)
                    throw ApiException(code, errorBody)
                }

                val responseText = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                if (responseText.isBlank()) JSONObject() else JSONObject(responseText)
            } finally {
                connection?.disconnect()
            }
        }

    /**
     * Execute a GET request and return the raw response body as a [String].
     *
     * @throws ApiException on non-2xx status codes.
     * @throws IOException on network errors.
     */
    @Suppress("TooGenericExceptionCaught")
    private suspend fun getString(
        endpoint: String,
        params: Map<String, String> = emptyMap(),
    ): String = withContext(Dispatchers.IO) {
        var connection: HttpURLConnection? = null
        try {
            val fullEndpoint = if (params.isEmpty()) {
                endpoint
            } else {
                val query = params.entries.joinToString("&") { (k, v) ->
                    "${URLEncoder.encode(k, "UTF-8")}=${URLEncoder.encode(v, "UTF-8")}"
                }
                "$endpoint?$query"
            }

            connection = openConnection(fullEndpoint).apply {
                requestMethod = "GET"
                connectTimeout = requestTimeoutMs
                readTimeout = requestTimeoutMs
                applyHeaders(defaultHeaders())
            }

            val code = connection.responseCode
            if (code !in 200..299) {
                val errorBody = readErrorBody(connection)
                throw ApiException(code, errorBody)
            }

            connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } finally {
            connection?.disconnect()
        }
    }

    /**
     * Execute a POST request and return the raw response bytes (for binary payloads like audio).
     */
    @Suppress("TooGenericExceptionCaught")
    private suspend fun postBytes(endpoint: String, body: JSONObject): ByteArray =
        withContext(Dispatchers.IO) {
            var connection: HttpURLConnection? = null
            try {
                connection = openConnection(endpoint).apply {
                    requestMethod = "POST"
                    connectTimeout = requestTimeoutMs
                    readTimeout = requestTimeoutMs
                    doOutput = true
                    applyHeaders(defaultHeaders())
                }

                OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                    writer.write(body.toString())
                    writer.flush()
                }

                val code = connection.responseCode
                if (code !in 200..299) {
                    val errorBody = readErrorBody(connection)
                    throw ApiException(code, errorBody)
                }

                connection.inputStream.use { it.readBytes() }
            } finally {
                connection?.disconnect()
            }
        }

    // ── Public API methods ───────────────────────────────────────────

    /**
     * Send a query and return a [Flow] of [SseEvent].
     *
     * Inspects the response `Content-Type`:
     * - `text/event-stream` — parses as SSE line-by-line.
     * - `application/json` — emits a single "message" event followed by "done".
     *
     * The flow completes when the stream ends or a "done" event is received.
     */
    fun sendQuery(query: QueryRequest): Flow<SseEvent> = flow {
        var connection: HttpURLConnection? = null
        try {
            connection = openConnection(EP_CHAT_SEND).apply {
                requestMethod = "POST"
                connectTimeout = requestTimeoutMs
                readTimeout = sseTimeoutMs
                doOutput = true
                setRequestProperty("Accept", "text/event-stream")
                applyHeaders(defaultHeaders())
            }

            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(query.toJson().toString())
                writer.flush()
            }

            val code = connection.responseCode
            if (code !in 200..299) {
                val errorBody = readErrorBody(connection)
                emit(SseEvent(event = "error", data = JSONObject().apply {
                    put("code", code)
                    put("message", errorBody)
                }.toString()))
                return@flow
            }

            val contentType = connection.contentType.orEmpty()

            if (contentType.contains("text/event-stream")) {
                // ── SSE streaming path ───────────────────────────────
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
                                // SSE spec: strip only the first space after the colon
                                val value = line.removePrefix("event:")
                                currentEvent = if (value.startsWith(" ")) value.substring(1) else value
                            }
                            line.startsWith("data:") -> {
                                // SSE spec: strip only the first space, accumulate multi-line data
                                val value = line.removePrefix("data:")
                                currentDataLines.add(if (value.startsWith(" ")) value.substring(1) else value)
                            }
                            line.isBlank() -> {
                                // Empty line = end of event
                                if (currentEvent.isNotEmpty() && currentDataLines.isNotEmpty()) {
                                    val data = currentDataLines.joinToString("\n")
                                    val event = SseEvent(event = currentEvent, data = data)
                                    emit(event)
                                    if (currentEvent == "done") {
                                        receivedDone = true
                                    }
                                }
                                currentEvent = ""
                                currentDataLines.clear()
                            }
                        }
                        line = reader.readLine()
                    }
                }

                // Flush any trailing event without a final blank line
                if (currentEvent.isNotEmpty() && currentDataLines.isNotEmpty()) {
                    emit(SseEvent(event = currentEvent, data = currentDataLines.joinToString("\n")))
                    if (currentEvent == "done") receivedDone = true
                }

                // Emit a synthetic done if the stream ended without one
                if (!receivedDone) {
                    emit(SseEvent(event = "done", data = "{}"))
                }
            } else if (contentType.contains("application/json")) {
                // ── Non-streaming JSON path ──────────────────────────
                val responseText = connection.inputStream.bufferedReader(Charsets.UTF_8)
                    .use { it.readText() }
                emit(SseEvent(event = "message", data = responseText))
                emit(SseEvent(event = "done", data = "{}"))
            } else {
                emit(SseEvent(event = "error", data = JSONObject().apply {
                    put("code", 0)
                    put("message", "Unexpected Content-Type: $contentType")
                }.toString()))
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error in sendQuery stream", e)
            emit(SseEvent(event = "error", data = JSONObject().apply {
                put("code", 0)
                put("message", e.message.orEmpty())
            }.toString()))
        } finally {
            connection?.disconnect()
        }
    }.flowOn(Dispatchers.IO)

    /**
     * Submit feedback (thumbs up/down) for a response.
     *
     * @throws ApiException on server errors.
     */
    suspend fun submitFeedback(feedback: FeedbackRequest) {
        try {
            postJson(EP_FEEDBACK, feedback.toJson())
        } catch (e: Exception) {
            Log.w(TAG, "Failed to submit feedback", e)
            throw e
        }
    }

    /**
     * Fetch conversation history from the server.
     */
    suspend fun getHistory(): List<ConversationResponse> {
        return try {
            val text = getString(EP_HISTORY)
            val array = JSONArray(text)
            array.mapObjects { ConversationResponse.fromJson(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get history", e)
            throw e
        }
    }

    /**
     * Fetch available languages from the server.
     */
    suspend fun getLanguages(): List<LanguageResponse> {
        return try {
            val text = getString(EP_LANGUAGES)
            val array = JSONArray(text)
            array.mapObjects { LanguageResponse.fromJson(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get languages", e)
            throw e
        }
    }

    /**
     * Fetch starter questions for the empty chat state.
     *
     * @param language Language code (e.g., "hi", "en").
     */
    suspend fun getStarters(language: String): List<StarterQuestionResponse> {
        return try {
            val text = getString(EP_STARTERS, mapOf("lang" to language))
            val array = JSONArray(text)
            array.mapObjects { StarterQuestionResponse.fromJson(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get starters", e)
            throw e
        }
    }

    /**
     * Submit onboarding data — user-selected location and language.
     */
    suspend fun submitOnboarding(location: Location, language: String) {
        try {
            val body = JSONObject().apply {
                put("location", location.toJson())
                put("language", language)
            }
            postJson(EP_ONBOARDING, body)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to submit onboarding", e)
            throw e
        }
    }

    /**
     * Convert text to speech. Returns raw audio bytes.
     *
     * @param text The text to synthesize.
     * @param language Language code for synthesis.
     */
    suspend fun textToSpeech(text: String, language: String): ByteArray {
        return try {
            val body = JSONObject().apply {
                put("text", text)
                put("language", language)
            }
            postBytes(EP_TTS, body)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get TTS audio", e)
            throw e
        }
    }

    // ── Private connection helpers ───────────────────────────────────

    private fun openConnection(endpoint: String): HttpURLConnection {
        val url = URL("$baseUrl$endpoint")
        return (url.openConnection() as HttpURLConnection)
    }

    private fun HttpURLConnection.applyHeaders(headers: Map<String, String>) {
        for ((key, value) in headers) {
            setRequestProperty(key, value)
        }
    }

    private fun readErrorBody(connection: HttpURLConnection): String {
        return try {
            connection.errorStream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        } catch (_: Exception) {
            ""
        }
    }
}

/**
 * Exception representing an HTTP error from the FarmerChat API.
 *
 * @property statusCode HTTP status code.
 * @property errorBody Raw error response body from the server.
 */
internal class ApiException(
    val statusCode: Int,
    val errorBody: String,
) : IOException("HTTP $statusCode")
