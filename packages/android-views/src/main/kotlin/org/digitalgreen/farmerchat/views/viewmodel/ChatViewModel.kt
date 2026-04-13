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
import org.digitalgreen.farmerchat.views.network.ConversationHistoryItem
import org.digitalgreen.farmerchat.views.network.ConversationListItem
import org.digitalgreen.farmerchat.views.network.CountryDetector
import org.digitalgreen.farmerchat.views.network.FollowUpQuestionOption
import org.digitalgreen.farmerchat.views.network.SdkPreferences
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

    /** Send a weather-context query (tapping the weather widget). Sets weather_cta_triggered = true. */
    fun sendWeatherQuery(question: String) {
        sendQuery(text = question, inputMethod = "text", weatherCtaTriggered = true)
    }

    @Suppress("UNUSED_PARAMETER")
    fun sendQuery(text: String, inputMethod: String = "text", imageData: String? = null, weatherCtaTriggered: Boolean = false) {
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
                        weatherCtaTriggered = weatherCtaTriggered,
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
        viewModelScope.launch {
            try {
                val client = apiClient ?: run {
                    Log.e(TAG, "loadConversation: SDK not initialized")
                    return@launch
                }
                conversationId = conversation.conversationId
                _messages.value = emptyList()
                _chatState.value = ChatUiState.Idle
                ensureGuestTokensSuspend()
                val history = client.getChatHistory(conversation.conversationId)
                _messages.value = processHistoryItems(history.data)
                // Signal HistoryFragment to navigate back to chat after messages are ready
                _navigateToChat.value = true
            } catch (e: Exception) {
                Log.w(TAG, "loadConversation failed: ${e.message}")
            }
        }
    }

    private val _navigateToChat = MutableStateFlow(false)
    val navigateToChat: StateFlow<Boolean> = _navigateToChat.asStateFlow()

    fun onNavigateToChatHandled() { _navigateToChat.value = false }

    private fun processHistoryItems(items: List<ConversationHistoryItem>): List<ChatMessage> {
        val sections = mutableListOf<MutableList<ConversationHistoryItem>>()
        var current = mutableListOf<ConversationHistoryItem>()
        for (item in items) {
            if (item.messageTypeId in listOf(1, 2, 11) && current.isNotEmpty()) {
                sections.add(current)
                current = mutableListOf()
            }
            current.add(item)
        }
        if (current.isNotEmpty()) sections.add(current)

        val ordered = sections.reversed().flatten()

        val result = mutableListOf<ChatMessage>()
        for (item in ordered) {
            when (item.messageTypeId) {
                7 -> {
                    val qs = item.questions ?: continue
                    val lastAiIdx = result.indexOfLast { it.role == "assistant" }
                    if (lastAiIdx >= 0) {
                        val mapped = qs.map { q ->
                            FollowUpQuestionOption(
                                followUpQuestionId = q.followUpQuestionId,
                                sequence = q.sequence,
                                question = q.question,
                            )
                        }
                        result[lastAiIdx] = result[lastAiIdx].copy(followUps = mapped)
                    }
                }
                else -> historyItemToChatMessage(item)?.let { result.add(it) }
            }
        }
        return result
    }

    private fun historyItemToChatMessage(item: ConversationHistoryItem): ChatMessage? {
        return when (item.messageTypeId) {
            1 -> ChatMessage(
                id = item.messageId,
                role = "user",
                text = item.queryText ?: "",
                timestamp = System.currentTimeMillis(),
                inputMethod = "text",
                serverMessageId = item.messageId,
            )
            2 -> ChatMessage(
                id = item.messageId,
                role = "user",
                text = item.heardQueryText ?: item.queryText ?: "",
                timestamp = System.currentTimeMillis(),
                inputMethod = "audio",
                serverMessageId = item.messageId,
            )
            11 -> ChatMessage(
                id = item.messageId,
                role = "user",
                text = item.queryText ?: "",
                timestamp = System.currentTimeMillis(),
                inputMethod = "image",
                serverMessageId = item.messageId,
            )
            3 -> ChatMessage(
                id = item.messageId,
                role = "assistant",
                text = item.responseText ?: "",
                timestamp = System.currentTimeMillis(),
                followUps = item.questions?.map { q ->
                    FollowUpQuestionOption(
                        followUpQuestionId = q.followUpQuestionId,
                        sequence = q.sequence,
                        question = q.question,
                    )
                } ?: emptyList(),
                serverMessageId = item.messageId,
            )
            7 -> null
            else -> null
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
                // Priority: FarmerChatConfig.countryCode → IP geo (TokenStore) → SIM/locale (CountryDetector)
                val configCountry = FarmerChat.getConfig().countryCode
                val detectedCountry = try { CountryDetector.detect(FarmerChat.getContext()) } catch (_: Exception) { "IN" }
                val effectiveCountry = when {
                    configCountry.isNotEmpty() -> configCountry
                    TokenStore.countryCode.isNotEmpty() -> TokenStore.countryCode
                    else -> detectedCountry
                }
                val groups = client.getSupportedLanguages(
                    countryCode = effectiveCountry,
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
            SdkPreferences.onboardingDone = true
            SdkPreferences.selectedLanguage = language
            _currentScreen.value = Screen.Chat
        } catch (e: Exception) {
            Log.w(TAG, "completeOnboarding failed", e)
        }
    }

    fun skipOnboarding(language: String) {
        try {
            setLanguage(language)
            SdkPreferences.onboardingDone = true
            SdkPreferences.selectedLanguage = language
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

    /** Full audio → transcription → text-query flow. */
    fun transcribeAndSendAudio(base64Audio: String, audioFormat: String = "AMR") {
        val client = apiClient ?: run {
            Log.e(TAG, "transcribeAndSendAudio: SDK not initialized")
            return
        }
        val audioMsgId = java.util.UUID.randomUUID().toString()
        _messages.update { msgs ->
            msgs + ChatMessage(
                id = audioMsgId, role = "user", text = "🎤 …",
                timestamp = System.currentTimeMillis(), inputMethod = "audio",
            )
        }
        _chatState.value = ChatUiState.Sending
        viewModelScope.launch {
            try {
                ensureGuestTokensSuspend()
                if (conversationId == null) {
                    val conv = client.createNewConversation(config.contentProviderId)
                    conversationId = conv.conversationId
                }
                val convId = conversationId!!
                val transcribeResp = client.transcribeAudio(
                    conversationId = convId,
                    base64Audio = base64Audio,
                    messageReferenceId = java.util.UUID.randomUUID().toString(),
                    inputAudioEncodingFormat = audioFormat,
                )
                val transcript = if (!transcribeResp.error && !transcribeResp.heardInputQuery.isNullOrBlank())
                    transcribeResp.heardInputQuery!!
                else {
                    _messages.update { msgs -> msgs.map {
                        if (it.id == audioMsgId) it.copy(text = "⚠️ Could not understand audio") else it
                    }}
                    _chatState.value = ChatUiState.Idle
                    return@launch
                }
                _messages.update { msgs -> msgs.map {
                    if (it.id == audioMsgId) it.copy(text = transcript) else it
                }}
                // Send the transcribed text
                sendTextInternal(
                    client = client, text = transcript, convId = convId,
                    triggeredInputType = "audio",
                    transcriptionId = transcribeResp.transcriptionId,
                )
            } catch (e: Exception) {
                Log.w(TAG, "transcribeAndSendAudio failed: ${e.message}")
                _chatState.value = ChatUiState.Idle
            }
        }
    }

    /** Send text + base64 image using image_analysis/ endpoint. GPS from EXIF if available. */
    fun sendQueryWithImage(
        text: String,
        base64Image: String,
        latitude: String? = null,
        longitude: String? = null,
    ) {
        val client = apiClient ?: run {
            Log.e(TAG, "sendQueryWithImage: SDK not initialized")
            return
        }
        val userMsgId = java.util.UUID.randomUUID().toString()
        _messages.update { msgs ->
            msgs + ChatMessage(
                id = userMsgId, role = "user",
                text = text.ifBlank { "📷 Analyze this image" },
                timestamp = System.currentTimeMillis(), inputMethod = "image",
                imageData = base64Image,
            )
        }
        _chatState.value = ChatUiState.Sending
        viewModelScope.launch {
            try {
                ensureGuestTokensSuspend()
                if (conversationId == null) {
                    val conv = client.createNewConversation(config.contentProviderId)
                    conversationId = conv.conversationId
                }
                val convId = conversationId!!
                val resp = client.imageAnalysis(
                    conversationId = convId,
                    base64Image = base64Image,
                    imageName = "image_${java.util.UUID.randomUUID()}.jpg",
                    query = text.ifBlank { null },
                    latitude = latitude,
                    longitude = longitude,
                )
                val inlineFollowUps = resp.followUpQuestions?.map { fq ->
                    FollowUpQuestionOption(
                        followUpQuestionId = fq.followUpQuestionId,
                        sequence = fq.sequence,
                        question = fq.question ?: "",
                    )
                } ?: emptyList()
                val aiMsgId = java.util.UUID.randomUUID().toString()
                _messages.update { msgs ->
                    msgs + ChatMessage(
                        id = aiMsgId, role = "assistant", text = resp.response,
                        timestamp = System.currentTimeMillis(),
                        followUps = inlineFollowUps,
                        serverMessageId = resp.messageId,
                    )
                }
                if (inlineFollowUps.isEmpty() && resp.messageId.isNotEmpty()) {
                    fetchFollowUps(aiMsgId, resp.messageId)
                }
                _chatState.value = ChatUiState.Idle
            } catch (e: Exception) {
                Log.w(TAG, "sendQueryWithImage failed: ${e.message}")
                _chatState.value = ChatUiState.Idle
            }
        }
    }

    private suspend fun sendTextInternal(
        client: org.digitalgreen.farmerchat.views.network.ApiClient,
        text: String, convId: String,
        triggeredInputType: String = "text",
        transcriptionId: String? = null,
        weatherCtaTriggered: Boolean = false,
    ) {
        try {
            val msgId = java.util.UUID.randomUUID().toString()
            val resp = client.sendTextPrompt(
                query = text, conversationId = convId, messageId = msgId,
                triggeredInputType = triggeredInputType,
                transcriptionId = transcriptionId,
                weatherCtaTriggered = weatherCtaTriggered,
            )
            val inlineFollowUps = resp.followUpQuestions?.map { fq ->
                FollowUpQuestionOption(
                    followUpQuestionId = fq.followUpQuestionId,
                    sequence = fq.sequence,
                    question = fq.question ?: "",
                )
            } ?: emptyList()
            val aiMsgId = java.util.UUID.randomUUID().toString()
            _messages.update { msgs ->
                msgs + ChatMessage(
                    id = aiMsgId, role = "assistant",
                    text = resp.response ?: resp.message ?: "",
                    timestamp = System.currentTimeMillis(),
                    followUps = inlineFollowUps,
                    serverMessageId = resp.messageId,
                )
            }
            if (inlineFollowUps.isEmpty() &&
                resp.hideFollowUpQuestion != true &&
                !resp.messageId.isNullOrEmpty()
            ) {
                fetchFollowUps(aiMsgId, resp.messageId!!)
            }
            _chatState.value = ChatUiState.Idle
        } catch (e: Exception) {
            Log.w(TAG, "sendTextInternal failed: ${e.message}")
            _chatState.value = ChatUiState.Idle
        }
    }

    private suspend fun fetchFollowUps(messageId: String, serverMsgId: String) {
        try {
            val client = apiClient ?: return
            val followUps = client.getFollowUpQuestions(serverMsgId)
            if (followUps.isNotEmpty()) {
                _messages.update { msgs -> msgs.map { msg ->
                    if (msg.id == messageId) msg.copy(followUps = followUps) else msg
                }}
            }
        } catch (e: Exception) {
            Log.w(TAG, "fetchFollowUps failed: ${e.message}")
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

    fun startNewConversation() {
        try {
            _messages.value = emptyList()
            _chatState.value = ChatUiState.Idle
            conversationId = null
            _currentScreen.value = Screen.Chat
        } catch (e: Exception) {
            Log.w(TAG, "startNewConversation failed", e)
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
