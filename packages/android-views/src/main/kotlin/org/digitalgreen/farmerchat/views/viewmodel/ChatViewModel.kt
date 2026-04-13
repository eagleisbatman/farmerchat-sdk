package org.digitalgreen.farmerchat.views.viewmodel

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
import org.digitalgreen.farmerchat.views.FarmerChat
import org.digitalgreen.farmerchat.views.FarmerChatEvent
import org.digitalgreen.farmerchat.views.network.ConversationListItem
import org.digitalgreen.farmerchat.views.network.FollowUpQuestionOption
import org.digitalgreen.farmerchat.views.network.StarterQuestionResponse
import org.digitalgreen.farmerchat.views.network.SupportedLanguageGroup
import org.digitalgreen.farmerchat.views.network.TokenStore
import java.util.UUID

/**
 * ViewModel managing all chat state for the XML Views SDK.
 * All state is in-memory via StateFlow. No local persistence.
 *
 * Every public method is wrapped in try-catch — the SDK must never crash the host app.
 */
internal class ChatViewModel : ViewModel() {

    private companion object {
        const val TAG = "FC.ChatVM"
    }

    // ── Sealed types ─────────────────────────────────────────────────

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

    sealed interface Screen {
        data object Onboarding : Screen
        data object Chat : Screen
        data object History : Screen
        data object Profile : Screen
    }

    data class ChatMessage(
        val id: String,
        val role: String,
        val text: String,
        val timestamp: Long,
        val inputMethod: String? = null,
        val imageData: String? = null,
        val followUps: List<FollowUpQuestionOption> = emptyList(),
        val serverMessageId: String? = null,
        val feedbackRating: String? = null,
    )

    // ── Mutable backing fields ───────────────────────────────────────

    private val _chatState = MutableStateFlow<ChatUiState>(ChatUiState.Idle)
    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    private val _currentScreen = MutableStateFlow<Screen>(Screen.Chat)
    private val _isConnected = MutableStateFlow(true)
    private val _starterQuestions = MutableStateFlow<List<StarterQuestionResponse>>(emptyList())
    private val _selectedLanguage = MutableStateFlow("")
    private val _availableLanguageGroups = MutableStateFlow<List<SupportedLanguageGroup>>(emptyList())
    private val _conversations = MutableStateFlow<List<ConversationListItem>>(emptyList())
    private val _historyLoading = MutableStateFlow(false)
    private val _historyError = MutableStateFlow<String?>(null)

    // ── Exposed state ────────────────────────────────────────────────

    val chatState: StateFlow<ChatUiState> = _chatState.asStateFlow()
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()
    val currentScreen: StateFlow<Screen> = _currentScreen.asStateFlow()
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()
    val starterQuestions: StateFlow<List<StarterQuestionResponse>> = _starterQuestions.asStateFlow()
    val selectedLanguage: StateFlow<String> = _selectedLanguage.asStateFlow()
    val availableLanguageGroups: StateFlow<List<SupportedLanguageGroup>> = _availableLanguageGroups.asStateFlow()
    val conversations: StateFlow<List<ConversationListItem>> = _conversations.asStateFlow()
    val historyLoading: StateFlow<Boolean> = _historyLoading.asStateFlow()
    val historyError: StateFlow<String?> = _historyError.asStateFlow()

    // ── Internal bookkeeping ─────────────────────────────────────────

    private var streamJob: Job? = null
    private var lastQuery: Triple<String, String, String?>? = null
    private var conversationId: String? = null

    private val config get() = FarmerChat.getConfig()
    private val apiClient get() = FarmerChat.apiClient
    private val sessionId get() = FarmerChat.getSessionId()

    // ── Initialization ───────────────────────────────────────────────

    init {
        try {
            _selectedLanguage.value = config.defaultLanguage ?: "en"
            FarmerChat.connectivityMonitor?.isConnected
                ?.onEach { connected -> _isConnected.value = connected }
                ?.launchIn(viewModelScope)
        } catch (e: Exception) {
            Log.w(TAG, "Error during init", e)
        }
    }

    // ── Guest token guard ────────────────────────────────────────────

    private suspend fun ensureGuestTokensSuspend() {
        if (TokenStore.isInitialized) return
        try {
            FarmerChat.guestApiClient?.initializeUser(TokenStore.deviceId)
        } catch (e: Exception) {
            Log.e(TAG, "ensureGuestTokensSuspend failed: ${e.message}", e)
        }
    }

    // ── Public actions ───────────────────────────────────────────────

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

            lastQuery = Triple(text, inputMethod, imageData)
            streamJob?.cancel()

            val userMessageId = UUID.randomUUID().toString()
            appendMessage(
                ChatMessage(
                    id = userMessageId,
                    role = "user",
                    text = text,
                    timestamp = System.currentTimeMillis(),
                    inputMethod = inputMethod,
                    imageData = imageData,
                )
            )
            _chatState.value = ChatUiState.Sending

            emitEvent(
                FarmerChatEvent.QuerySent(
                    sessionId = sessionId,
                    queryId = userMessageId,
                    inputMethod = inputMethod,
                )
            )

            viewModelScope.launch {
                try {
                    ensureGuestTokensSuspend()

                    if (conversationId == null) {
                        val conv = client.createNewConversation(config.contentProviderId)
                        conversationId = conv.conversationId
                    }

                    val convId = conversationId!!
                    val sendStartMs = System.currentTimeMillis()
                    val clientMessageId = UUID.randomUUID().toString()

                    val response = client.sendTextPrompt(
                        query = text,
                        conversationId = convId,
                        messageId = clientMessageId,
                        triggeredInputType = inputMethod,
                    )

                    val answerText = response.response ?: response.message ?: ""
                    val localId = UUID.randomUUID().toString()
                    appendMessage(
                        ChatMessage(
                            id = localId,
                            role = "assistant",
                            text = answerText,
                            timestamp = System.currentTimeMillis(),
                            followUps = response.followUpQuestions,
                            serverMessageId = response.messageId,
                        )
                    )

                    // Fetch follow-ups from dedicated endpoint if not supplied inline
                    if (response.followUpQuestions.isEmpty() &&
                        response.hideFollowUpQuestion != true &&
                        !response.messageId.isNullOrEmpty()
                    ) {
                        fetchAndAppendFollowUps(localId, response.messageId!!)
                    }

                    _chatState.value = ChatUiState.Complete
                    emitEvent(
                        FarmerChatEvent.ResponseReceived(
                            sessionId = sessionId,
                            responseId = clientMessageId,
                            latencyMs = System.currentTimeMillis() - sendStartMs,
                        )
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "sendQuery coroutine failed", e)
                    _chatState.value = ChatUiState.Error(
                        code = "send_error",
                        message = e.message ?: "Failed to send query",
                        retryable = true,
                    )
                    emitEvent(
                        FarmerChatEvent.Error(
                            code = "send_error",
                            message = e.message ?: "Failed to send query",
                        )
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

    fun sendFollowUp(text: String) {
        sendQuery(text = text, inputMethod = "follow_up")
    }

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

    fun retryLastQuery() {
        try {
            val (text, inputMethod, imageData) = lastQuery ?: return
            _chatState.value = ChatUiState.Idle
            sendQuery(text = text, inputMethod = inputMethod, imageData = imageData)
        } catch (e: Exception) {
            Log.w(TAG, "retryLastQuery failed", e)
        }
    }

    fun submitFeedback(messageId: String, rating: String, comment: String? = null) {
        viewModelScope.launch {
            try {
                _messages.update { list ->
                    list.map { msg ->
                        if (msg.id == messageId) msg.copy(feedbackRating = rating) else msg
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "submitFeedback failed", e)
            }
        }
    }

    fun loadHistory() {
        Log.d(TAG, "loadHistory called — apiClient=${if (apiClient != null) "ready" else "NULL"}")
        viewModelScope.launch {
            try {
                _historyLoading.value = true
                _historyError.value = null
                val client = apiClient ?: run {
                    Log.e(TAG, "loadHistory: apiClient is null")
                    return@launch
                }
                ensureGuestTokensSuspend()
                val result = client.getConversationList()
                Log.d(TAG, "loadHistory: received ${result.size} conversations")
                _conversations.value = result
            } catch (e: Exception) {
                Log.e(TAG, "loadHistory failed: ${e.message}", e)
                _historyError.value = e.message ?: "Failed to load history"
                emitEvent(
                    FarmerChatEvent.Error(
                        code = "history_error",
                        message = e.message ?: "Failed to load history",
                    )
                )
            } finally {
                _historyLoading.value = false
            }
        }
    }

    fun loadConversation(conversation: ConversationListItem) {
        try {
            _messages.value = emptyList()
            _chatState.value = ChatUiState.Idle
            conversationId = conversation.conversationId
            _currentScreen.value = Screen.Chat
        } catch (e: Exception) {
            Log.w(TAG, "loadConversation failed", e)
        }
    }

    fun loadLanguages() {
        viewModelScope.launch {
            try {
                val client = apiClient ?: run {
                    Log.e(TAG, "loadLanguages: apiClient is null")
                    return@launch
                }
                ensureGuestTokensSuspend()
                val groups = client.getSupportedLanguages(
                    countryCode = TokenStore.countryCode,
                    state = TokenStore.state,
                )
                _availableLanguageGroups.value = groups
                Log.d(TAG, "loadLanguages: ${groups.sumOf { it.languages.size }} languages loaded")
            } catch (e: Exception) {
                Log.e(TAG, "loadLanguages failed: ${e.message}", e)
            }
        }
    }

    fun setLanguage(code: String) {
        try {
            _selectedLanguage.value = code
            loadStarters()
            // Sync preferred language with server
            val language = _availableLanguageGroups.value
                .flatMap { it.languages }
                .firstOrNull { it.code == code }
            if (language != null) {
                val userId = TokenStore.userId
                if (userId.isNotEmpty()) {
                    viewModelScope.launch {
                        try {
                            ensureGuestTokensSuspend()
                            apiClient?.setPreferredLanguage(userId, language.id.toString())
                        } catch (e: Exception) {
                            Log.w(TAG, "setPreferredLanguage API call failed: ${e.message}")
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "setLanguage failed", e)
        }
    }

    fun loadStarters() {
        // Starters are not available in the real FarmerChat API; no-op.
    }

    fun completeOnboarding(language: String) {
        try {
            setLanguage(language)
            _currentScreen.value = Screen.Chat
        } catch (e: Exception) {
            Log.w(TAG, "completeOnboarding failed", e)
        }
    }

    fun skipOnboarding(language: String) {
        try {
            setLanguage(language)
            _currentScreen.value = Screen.Chat
        } catch (e: Exception) {
            Log.w(TAG, "skipOnboarding failed", e)
        }
    }

    fun navigateTo(screen: Screen) {
        try {
            _currentScreen.value = screen
        } catch (e: Exception) {
            Log.w(TAG, "navigateTo failed", e)
        }
    }

    fun clearMessages() {
        try {
            _messages.value = emptyList()
            _chatState.value = ChatUiState.Idle
            conversationId = null
        } catch (e: Exception) {
            Log.w(TAG, "clearMessages failed", e)
        }
    }

    fun setIsConnected(connected: Boolean) {
        _isConnected.value = connected
    }

    // ── Private helpers ──────────────────────────────────────────────

    private fun appendMessage(message: ChatMessage) {
        _messages.update { list ->
            val cap = config.maxMessagesInMemory
            val updated = list + message
            if (updated.size > cap) updated.takeLast(cap) else updated
        }
    }

    private fun fetchAndAppendFollowUps(localMessageId: String, serverMessageId: String) {
        viewModelScope.launch {
            try {
                val client = apiClient ?: return@launch
                val followUps = client.getFollowUpQuestions(serverMessageId)
                if (followUps.isNotEmpty()) {
                    _messages.update { list ->
                        list.map { msg ->
                            if (msg.id == localMessageId) msg.copy(followUps = followUps) else msg
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "fetchAndAppendFollowUps failed", e)
            }
        }
    }

    private fun emitEvent(event: FarmerChatEvent) {
        try {
            FarmerChat.eventCallback?.invoke(event)
        } catch (e: Exception) {
            Log.w(TAG, "Event callback threw", e)
        }
    }
}
