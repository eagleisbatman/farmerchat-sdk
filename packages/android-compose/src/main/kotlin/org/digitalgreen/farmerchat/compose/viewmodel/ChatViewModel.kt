package org.digitalgreen.farmerchat.compose.viewmodel

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.digitalgreen.farmerchat.compose.FarmerChat
import org.digitalgreen.farmerchat.compose.FarmerChatEvent
import org.digitalgreen.farmerchat.compose.network.FeedbackRequest
import org.digitalgreen.farmerchat.compose.network.LanguageResponse
import org.digitalgreen.farmerchat.compose.network.Location
import org.digitalgreen.farmerchat.compose.network.QueryRequest
import org.digitalgreen.farmerchat.compose.network.ConversationResponse
import org.digitalgreen.farmerchat.compose.network.StarterQuestionResponse
import org.json.JSONObject
import java.util.UUID

/**
 * ViewModel managing chat state.
 * All state is in-memory via StateFlow. No persistence.
 *
 * Every public method is wrapped in try-catch — the SDK must never crash the host app.
 */
internal class ChatViewModel : ViewModel() {

    private companion object {
        const val TAG = "FC.ChatVM"
    }

    // ── Sealed types ─────────────────────────────────────────────────

    /** Represents the current state of a chat operation (send / stream / idle). */
    sealed interface ChatUiState {
        data object Idle : ChatUiState
        data object Sending : ChatUiState
        data class Streaming(val partialText: String, val tokenCount: Int) : ChatUiState
        data object Complete : ChatUiState
        data class Error(
            val code: String,
            val message: String,
            val retryable: Boolean,
        ) : ChatUiState
    }

    /** Top-level screen navigation within the SDK. */
    sealed interface Screen {
        data object Onboarding : Screen
        data object Chat : Screen
        data object History : Screen
        data object Profile : Screen
    }

    // ── Data classes ─────────────────────────────────────────────────

    /** A single message displayed in the chat list. */
    data class ChatMessage(
        val id: String,
        val role: String,
        val text: String,
        val timestamp: Long,
        val inputMethod: String? = null,
        val imageData: String? = null,
        val followUps: List<String> = emptyList(),
        val sources: List<Source> = emptyList(),
        val imageUrl: String? = null,
        val feedbackRating: String? = null,
    )

    /** A source citation attached to an assistant message. */
    data class Source(val title: String, val url: String? = null)

    // ── Mutable backing fields ───────────────────────────────────────

    private val _chatState = MutableStateFlow<ChatUiState>(ChatUiState.Idle)
    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    private val _currentScreen = MutableStateFlow<Screen>(Screen.Chat)
    private val _isConnected = MutableStateFlow(true)
    private val _starterQuestions = MutableStateFlow<List<StarterQuestionResponse>>(emptyList())
    private val _selectedLanguage = MutableStateFlow("")
    private val _availableLanguages = MutableStateFlow<List<LanguageResponse>>(emptyList())

    // ── Exposed state ────────────────────────────────────────────────

    val chatState: StateFlow<ChatUiState> = _chatState.asStateFlow()
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()
    val currentScreen: StateFlow<Screen> = _currentScreen.asStateFlow()
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()
    val starterQuestions: StateFlow<List<StarterQuestionResponse>> = _starterQuestions.asStateFlow()
    val selectedLanguage: StateFlow<String> = _selectedLanguage.asStateFlow()
    val availableLanguages: StateFlow<List<LanguageResponse>> = _availableLanguages.asStateFlow()

    // ── Internal bookkeeping ─────────────────────────────────────────

    /** Active SSE collection job — cancelled by [stopStream]. */
    private var streamJob: Job? = null

    /** Stores the last query so [retryLastQuery] can replay it. */
    private var lastQuery: Triple<String, String, String?>? = null // text, inputMethod, imageData

    private val config get() = FarmerChat.getConfig()
    private val apiClient get() = FarmerChat.apiClient
    private val sessionId get() = FarmerChat.getSessionId()

    // ── Initialization ───────────────────────────────────────────────

    init {
        try {
            // Seed the default language from config, or fall back to "en"
            _selectedLanguage.value = config.defaultLanguage ?: "en"

            // Wire up connectivity monitor
            FarmerChat.connectivityMonitor?.isConnected
                ?.onEach { connected -> _isConnected.value = connected }
                ?.launchIn(viewModelScope)

            // Pre-load languages
            loadLanguages()
        } catch (e: Exception) {
            Log.w(TAG, "Error during init", e)
        }
    }

    // ── Public actions ───────────────────────────────────────────────

    /**
     * Send a text query (optionally with an image).
     *
     * State transitions: Idle → Sending → Streaming → Complete (or Error).
     */
    fun sendQuery(text: String, inputMethod: String = "text", imageData: String? = null) {
        try {
            val client = apiClient ?: run {
                _chatState.value = ChatUiState.Error(
                    code = "sdk_not_initialized",
                    message = "FarmerChat SDK is not initialized",
                    retryable = false,
                )
                return
            }

            // Save for retry
            lastQuery = Triple(text, inputMethod, imageData)

            // Cancel any in-flight stream
            streamJob?.cancel()

            // Add the user message
            val userMessageId = UUID.randomUUID().toString()
            val userMessage = ChatMessage(
                id = userMessageId,
                role = "user",
                text = text,
                timestamp = System.currentTimeMillis(),
                inputMethod = inputMethod,
                imageData = imageData,
            )
            appendMessage(userMessage)

            _chatState.value = ChatUiState.Sending

            // Emit QuerySent event
            emitEvent(
                FarmerChatEvent.QuerySent(
                    sessionId = sessionId,
                    queryId = userMessageId,
                    inputMethod = inputMethod,
                ),
            )

            val request = QueryRequest(
                text = text,
                inputMethod = inputMethod,
                language = _selectedLanguage.value,
                imageData = imageData,
            )

            val assistantMessageId = UUID.randomUUID().toString()
            val sendStartMs = System.currentTimeMillis()

            streamJob = viewModelScope.launch {
                try {
                    var accumulatedText = ""
                    var tokenCount = 0
                    var followUps = emptyList<String>()
                    var sources = emptyList<Source>()
                    var imageUrl: String? = null
                    var assistantMessageAdded = false

                    client.sendQuery(request).collect { sseEvent ->
                        when (sseEvent.event) {
                            "token" -> {
                                val tokenText = parseTokenText(sseEvent.data)
                                accumulatedText += tokenText
                                tokenCount++

                                _chatState.value = ChatUiState.Streaming(
                                    partialText = accumulatedText,
                                    tokenCount = tokenCount,
                                )

                                // Upsert the assistant message (growing as tokens arrive)
                                val assistantMessage = ChatMessage(
                                    id = assistantMessageId,
                                    role = "assistant",
                                    text = accumulatedText,
                                    timestamp = System.currentTimeMillis(),
                                    followUps = followUps,
                                    sources = sources,
                                    imageUrl = imageUrl,
                                )
                                upsertAssistantMessage(assistantMessageId, assistantMessage, assistantMessageAdded)
                                assistantMessageAdded = true
                            }

                            "followup" -> {
                                followUps = parseFollowUps(sseEvent.data)
                                // Update the existing assistant message with follow-ups
                                if (assistantMessageAdded) {
                                    updateAssistantMessage(assistantMessageId) {
                                        it.copy(followUps = followUps)
                                    }
                                }
                            }

                            "message" -> {
                                // Non-streaming JSON path: full response at once
                                val parsed = parseMessageEvent(sseEvent.data)
                                accumulatedText = parsed.text
                                followUps = parsed.followUps
                                sources = parsed.sources
                                imageUrl = parsed.imageUrl

                                val assistantMessage = ChatMessage(
                                    id = parsed.id.ifEmpty { assistantMessageId },
                                    role = "assistant",
                                    text = accumulatedText,
                                    timestamp = System.currentTimeMillis(),
                                    followUps = followUps,
                                    sources = sources,
                                    imageUrl = imageUrl,
                                )
                                upsertAssistantMessage(assistantMessageId, assistantMessage, assistantMessageAdded)
                                assistantMessageAdded = true
                            }

                            "done" -> {
                                _chatState.value = ChatUiState.Complete

                                // Emit ResponseReceived event
                                val latencyMs = System.currentTimeMillis() - sendStartMs
                                emitEvent(
                                    FarmerChatEvent.ResponseReceived(
                                        sessionId = sessionId,
                                        responseId = assistantMessageId,
                                        latencyMs = latencyMs,
                                    ),
                                )
                            }

                            "error" -> {
                                val errorInfo = parseErrorEvent(sseEvent.data)
                                _chatState.value = ChatUiState.Error(
                                    code = errorInfo.first,
                                    message = errorInfo.second,
                                    retryable = true,
                                )
                                emitEvent(
                                    FarmerChatEvent.Error(
                                        code = errorInfo.first,
                                        message = errorInfo.second,
                                    ),
                                )
                            }
                        }
                    }

                    // If stream ended without an explicit "done", ensure we mark Complete
                    if (_chatState.value is ChatUiState.Streaming) {
                        _chatState.value = ChatUiState.Complete
                        val latencyMs = System.currentTimeMillis() - sendStartMs
                        emitEvent(
                            FarmerChatEvent.ResponseReceived(
                                sessionId = sessionId,
                                responseId = assistantMessageId,
                                latencyMs = latencyMs,
                            ),
                        )
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Stream collection error", e)
                    // Keep any partial text visible — move to Error state
                    _chatState.value = ChatUiState.Error(
                        code = "stream_error",
                        message = e.message ?: "Unknown streaming error",
                        retryable = true,
                    )
                    emitEvent(
                        FarmerChatEvent.Error(
                            code = "stream_error",
                            message = e.message ?: "Unknown streaming error",
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "sendQuery failed", e)
            _chatState.value = ChatUiState.Error(
                code = "send_error",
                message = e.message ?: "Failed to send query",
                retryable = true,
            )
        }
    }

    /**
     * Send a follow-up question (user tapped a suggestion chip).
     */
    fun sendFollowUp(text: String) {
        sendQuery(text = text, inputMethod = "follow_up")
    }

    /**
     * Cancel the active SSE stream and settle on the partial text.
     */
    fun stopStream() {
        try {
            streamJob?.cancel()
            streamJob = null

            val current = _chatState.value
            if (current is ChatUiState.Streaming || current is ChatUiState.Sending) {
                _chatState.value = ChatUiState.Complete
            }
        } catch (e: Exception) {
            Log.w(TAG, "stopStream failed", e)
        }
    }

    /**
     * Replay the last failed query.
     */
    fun retryLastQuery() {
        try {
            val (text, inputMethod, imageData) = lastQuery ?: return
            // Reset error state before retry
            _chatState.value = ChatUiState.Idle
            sendQuery(text = text, inputMethod = inputMethod, imageData = imageData)
        } catch (e: Exception) {
            Log.w(TAG, "retryLastQuery failed", e)
        }
    }

    /**
     * Submit feedback (thumbs up/down) for an assistant message.
     */
    fun submitFeedback(messageId: String, rating: String, comment: String? = null) {
        viewModelScope.launch {
            try {
                val client = apiClient ?: return@launch
                client.submitFeedback(
                    FeedbackRequest(
                        responseId = messageId,
                        rating = rating,
                        comment = comment,
                    ),
                )

                // Optimistically update the local message
                _messages.update { list ->
                    list.map { msg ->
                        if (msg.id == messageId) msg.copy(feedbackRating = rating) else msg
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "submitFeedback failed", e)
                emitEvent(
                    FarmerChatEvent.Error(
                        code = "feedback_error",
                        message = e.message ?: "Failed to submit feedback",
                    ),
                )
            }
        }
    }

    /**
     * Load conversation history from the server and replace the current message list.
     */
    fun loadHistory() {
        viewModelScope.launch {
            try {
                val client = apiClient ?: return@launch
                val conversations = client.getHistory()

                // Flatten the most recent conversation's messages into ChatMessages
                val historyMessages = conversations
                    .flatMap { conversation ->
                        conversation.messages.map { msg ->
                            ChatMessage(
                                id = msg.id,
                                role = msg.role,
                                text = msg.text,
                                timestamp = msg.timestamp,
                                imageData = msg.imageData,
                                followUps = msg.followUps,
                            )
                        }
                    }

                _messages.value = trimToCapacity(historyMessages)
            } catch (e: Exception) {
                Log.w(TAG, "loadHistory failed", e)
                emitEvent(
                    FarmerChatEvent.Error(
                        code = "history_error",
                        message = e.message ?: "Failed to load history",
                    ),
                )
            }
        }
    }

    /**
     * Fetch the list of past conversations from the server.
     * Used by HistoryScreen to display conversation cards.
     */
    suspend fun getConversations(): List<ConversationResponse> {
        val client = apiClient ?: return emptyList()
        return client.getHistory()
    }

    /**
     * Fetch available languages from the server.
     */
    fun loadLanguages() {
        viewModelScope.launch {
            try {
                val client = apiClient ?: return@launch
                val languages = client.getLanguages()
                _availableLanguages.value = languages
            } catch (e: Exception) {
                Log.w(TAG, "loadLanguages failed", e)
            }
        }
    }

    /**
     * Change the active language and reload starters for the new language.
     */
    fun setLanguage(code: String) {
        try {
            _selectedLanguage.value = code
            loadStarters()
        } catch (e: Exception) {
            Log.w(TAG, "setLanguage failed", e)
        }
    }

    /**
     * Load starter questions for the current language.
     */
    fun loadStarters() {
        viewModelScope.launch {
            try {
                val client = apiClient ?: return@launch
                val starters = client.getStarters(_selectedLanguage.value)
                _starterQuestions.value = starters
            } catch (e: Exception) {
                Log.w(TAG, "loadStarters failed", e)
            }
        }
    }

    /**
     * Submit onboarding data (location + language) and navigate to the chat screen.
     */
    fun completeOnboarding(lat: Double, lng: Double, language: String) {
        viewModelScope.launch {
            try {
                val client = apiClient ?: return@launch
                client.submitOnboarding(Location(lat, lng), language)
                setLanguage(language)
                _currentScreen.value = Screen.Chat
            } catch (e: Exception) {
                Log.w(TAG, "completeOnboarding failed", e)
                emitEvent(
                    FarmerChatEvent.Error(
                        code = "onboarding_error",
                        message = e.message ?: "Failed to complete onboarding",
                    ),
                )
            }
        }
    }

    /**
     * Navigate to a different screen within the SDK.
     */
    fun navigateTo(screen: Screen) {
        try {
            _currentScreen.value = screen
        } catch (e: Exception) {
            Log.w(TAG, "navigateTo failed", e)
        }
    }

    // ── Private helpers ──────────────────────────────────────────────

    /** Append a message and enforce the memory cap. */
    private fun appendMessage(message: ChatMessage) {
        _messages.update { list ->
            trimToCapacity(list + message)
        }
    }

    /**
     * Insert or update the assistant message in the list.
     *
     * On the first token [alreadyAdded] is false, so the message is appended.
     * On subsequent tokens the existing entry is replaced in-place.
     */
    private fun upsertAssistantMessage(
        id: String,
        message: ChatMessage,
        alreadyAdded: Boolean,
    ) {
        _messages.update { list ->
            if (alreadyAdded) {
                list.map { if (it.id == id) message else it }
            } else {
                trimToCapacity(list + message)
            }
        }
    }

    /** Apply a transformation to a specific assistant message. */
    private fun updateAssistantMessage(id: String, transform: (ChatMessage) -> ChatMessage) {
        _messages.update { list ->
            list.map { if (it.id == id) transform(it) else it }
        }
    }

    /** Trim a list to [FarmerChatConfig.maxMessagesInMemory], removing the oldest entries. */
    private fun trimToCapacity(list: List<ChatMessage>): List<ChatMessage> {
        val cap = config.maxMessagesInMemory
        return if (list.size > cap) list.takeLast(cap) else list
    }

    /** Emit a [FarmerChatEvent] to the host app's callback. */
    private fun emitEvent(event: FarmerChatEvent) {
        try {
            FarmerChat.eventCallback?.invoke(event)
        } catch (e: Exception) {
            Log.w(TAG, "Event callback threw", e)
        }
    }

    // ── SSE payload parsing ──────────────────────────────────────────

    /** Extract the text content from a "token" SSE data payload. */
    private fun parseTokenText(data: String): String {
        return try {
            val json = JSONObject(data)
            json.optString("text", data)
        } catch (_: Exception) {
            // If it's not valid JSON, treat the raw string as the token text
            data
        }
    }

    /** Parse follow-up suggestions from a "followup" SSE data payload. */
    private fun parseFollowUps(data: String): List<String> {
        return try {
            val json = JSONObject(data)
            val arr = json.optJSONArray("follow_ups") ?: return emptyList()
            (0 until arr.length()).map { arr.optString(it, "") }.filter { it.isNotEmpty() }
        } catch (_: Exception) {
            emptyList()
        }
    }

    /** Intermediate holder for parsed "message" event data. */
    private data class ParsedMessage(
        val id: String,
        val text: String,
        val followUps: List<String>,
        val sources: List<Source>,
        val imageUrl: String?,
    )

    /** Parse a full "message" (non-streaming JSON) event. */
    private fun parseMessageEvent(data: String): ParsedMessage {
        return try {
            val json = JSONObject(data)
            val id = json.optString("id", "")
            val text = json.optString("text", "")
            val followUps = json.optJSONArray("follow_ups")?.let { arr ->
                (0 until arr.length()).map { arr.optString(it, "") }.filter { it.isNotEmpty() }
            } ?: emptyList()
            val sources = json.optJSONArray("sources")?.let { arr ->
                (0 until arr.length()).map { i ->
                    val srcJson = arr.optJSONObject(i) ?: JSONObject()
                    Source(
                        title = srcJson.optString("title", ""),
                        url = srcJson.optString("url", null),
                    )
                }
            } ?: emptyList()
            val imageUrl = json.optString("image_url", null)

            ParsedMessage(id, text, followUps, sources, imageUrl)
        } catch (_: Exception) {
            ParsedMessage(id = "", text = data, followUps = emptyList(), sources = emptyList(), imageUrl = null)
        }
    }

    /** Parse an "error" SSE event and return (code, message). */
    private fun parseErrorEvent(data: String): Pair<String, String> {
        return try {
            val json = JSONObject(data)
            val code = json.optString("code", json.optInt("code", 0).toString())
            val message = json.optString("message", "Unknown error")
            code to message
        } catch (_: Exception) {
            "unknown" to data
        }
    }
}
