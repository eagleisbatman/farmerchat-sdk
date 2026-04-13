package org.digitalgreen.farmerchat.compose.viewmodel

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.digitalgreen.farmerchat.compose.FarmerChat
import org.digitalgreen.farmerchat.compose.FarmerChatEvent
import org.digitalgreen.farmerchat.compose.network.ConversationHistoryItem
import org.digitalgreen.farmerchat.compose.network.ConversationListItem
import org.digitalgreen.farmerchat.compose.network.GuestApiClient
import org.digitalgreen.farmerchat.compose.network.SdkPreferences
import org.digitalgreen.farmerchat.compose.network.SupportedLanguage
import org.digitalgreen.farmerchat.compose.network.SupportedLanguageGroup
import org.digitalgreen.farmerchat.compose.network.TokenStore
import java.util.UUID

/**
 * ViewModel managing chat state for the FarmerChat Compose SDK.
 *
 * All state is in-memory via [StateFlow]. No local persistence.
 * Every public method is wrapped in try-catch — the SDK must never crash the host app.
 */
internal class ChatViewModel : ViewModel() {

    private companion object {
        const val TAG = "FC.ChatVM"
    }

    // ── Sealed types ──────────────────────────────────────────────────────────

    sealed interface ChatUiState {
        data object Idle : ChatUiState
        data object Sending : ChatUiState
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

    // ── Chat message ──────────────────────────────────────────────────────────

    data class ChatMessage(
        val id: String,
        val role: String,   // "user" | "assistant"
        val text: String,
        val timestamp: Long,
        val inputMethod: String? = null,   // "text" | "audio" | "image" | "follow_up"
        val imageData: String? = null,
        val followUps: List<FollowUp> = emptyList(),
        val contentProviderLogo: String? = null,
        val hideTtsSpeaker: Boolean = false,
        val serverMessageId: String? = null,   // message_id returned by the server
    )

    data class FollowUp(
        val id: String?,
        val question: String,
        val sequence: Int,
    )

    // ── Mutable backing ───────────────────────────────────────────────────────

    private val _chatState   = MutableStateFlow<ChatUiState>(ChatUiState.Idle)
    private val _messages    = MutableStateFlow<List<ChatMessage>>(emptyList())
    // Determined lazily in init — see determineInitialScreen()
    private val _currentScreen = MutableStateFlow<Screen>(Screen.Chat)
    private val _isConnected = MutableStateFlow(true)
    private val _selectedLanguage = MutableStateFlow("")
    private val _availableLanguageGroups = MutableStateFlow<List<SupportedLanguageGroup>>(emptyList())
    private val _conversationList = MutableStateFlow<List<ConversationListItem>>(emptyList())
    private val _historyLoading = MutableStateFlow(false)

    // ── Exposed state ─────────────────────────────────────────────────────────

    val chatState: StateFlow<ChatUiState>   = _chatState.asStateFlow()
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()
    val currentScreen: StateFlow<Screen>   = _currentScreen.asStateFlow()
    val isConnected: StateFlow<Boolean>    = _isConnected.asStateFlow()
    val selectedLanguage: StateFlow<String> = _selectedLanguage.asStateFlow()
    val availableLanguageGroups: StateFlow<List<SupportedLanguageGroup>> = _availableLanguageGroups.asStateFlow()
    val conversationList: StateFlow<List<ConversationListItem>> = _conversationList.asStateFlow()
    val historyLoading: StateFlow<Boolean> = _historyLoading.asStateFlow()

    // ── Internal bookkeeping ──────────────────────────────────────────────────

    /** Active conversation ID. Created lazily on first message send. */
    private var conversationId: String? = null

    /** Stored so [retryLastQuery] can replay the last failed query. */
    private var lastQuery: Triple<String, String, String?>? = null

    private val config get() = FarmerChat.getConfig()
    private val apiClient get() = FarmerChat.apiClient
    private val sessionId get() = FarmerChat.getSessionId()

    // ── Initialization ────────────────────────────────────────────────────────

    init {
        try {
            // Resolve starting language: host config > persisted pref > default "en"
            _selectedLanguage.value = config.defaultLanguage
                ?: SdkPreferences.selectedLanguage.ifEmpty { "en" }

            // Determine which screen to show first:
            //  - Host supplied a defaultLanguage → skip onboarding (host configured)
            //  - User has already gone through onboarding → go straight to Chat
            //  - Otherwise → Onboarding (first launch)
            _currentScreen.value = when {
                config.defaultLanguage != null   -> Screen.Chat
                SdkPreferences.onboardingDone    -> Screen.Chat
                else                             -> Screen.Onboarding
            }

            FarmerChat.connectivityMonitor?.isConnected
                ?.onEach { connected -> _isConnected.value = connected }
                ?.launchIn(viewModelScope)

            ensureGuestTokens()
        } catch (e: Exception) {
            Log.w(TAG, "Error during init", e)
        }
    }

    // ── Guest token guard ─────────────────────────────────────────────────────

    /**
     * Ensure guest tokens exist before making any API call.
     * If [TokenStore.isInitialized] is false, calls `initialize_user`.
     */
    private fun ensureGuestTokens() {
        if (TokenStore.isInitialized) return
        viewModelScope.launch {
            try {
                GuestApiClient(config.baseUrl).initializeUser(TokenStore.deviceId)
            } catch (e: Exception) {
                Log.w(TAG, "Guest token init failed: ${e.message}")
            }
        }
    }

    private suspend fun ensureGuestTokensSuspend() {
        if (!TokenStore.isInitialized) {
            GuestApiClient(config.baseUrl).initializeUser(TokenStore.deviceId)
        }
    }

    // ── Public actions ────────────────────────────────────────────────────────

    /**
     * Send a text query (optionally with a base64 image).
     *
     * State: Idle → Sending → Complete | Error
     */
    fun sendQuery(
        text: String,
        inputMethod: String = "text",
        imageData: String? = null,
    ) {
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

                    // Create a new conversation if needed
                    if (conversationId == null) {
                        val conv = client.newConversation(
                            userId = TokenStore.userId,
                            contentProviderId = config.contentProviderId,
                        )
                        conversationId = conv.conversationId
                    }

                    val convId = conversationId!!
                    val sendStartMs = System.currentTimeMillis()
                    val clientMessageId = UUID.randomUUID().toString()

                    if (imageData != null) {
                        // Image analysis path
                        val plantix = client.imageAnalysis(
                            conversationId = convId,
                            base64Image = imageData,
                            imageName = "image_${UUID.randomUUID()}.jpg",
                        )
                        val localId = UUID.randomUUID().toString()
                        val inlineFollowUps = plantix.followUpQuestions?.map { fq ->
                            FollowUp(id = fq.followUpQuestionId, question = fq.question ?: "", sequence = fq.sequence)
                        } ?: emptyList()
                        appendMessage(
                            ChatMessage(
                                id = localId,
                                role = "assistant",
                                text = plantix.response,
                                timestamp = System.currentTimeMillis(),
                                followUps = inlineFollowUps,
                                contentProviderLogo = plantix.contentProviderLogo,
                                hideTtsSpeaker = plantix.hideTtsSpeaker ?: false,
                                serverMessageId = plantix.messageId,
                            )
                        )
                        // Fetch follow-ups from the dedicated endpoint if not supplied inline
                        if (inlineFollowUps.isEmpty() && plantix.messageId.isNotEmpty()) {
                            fetchAndAppendFollowUps(localId, plantix.messageId)
                        }
                    } else {
                        // Text / follow-up path
                        val response = client.sendTextPrompt(
                            query = text,
                            conversationId = convId,
                            messageId = clientMessageId,
                            triggeredInputType = inputMethod,
                        )
                        val answerText = response.response ?: response.message ?: ""
                        val localId = UUID.randomUUID().toString()
                        val inlineFollowUps = response.followUpQuestions?.map { fq ->
                            FollowUp(id = fq.followUpQuestionId, question = fq.question ?: "", sequence = fq.sequence)
                        } ?: emptyList()
                        appendMessage(
                            ChatMessage(
                                id = localId,
                                role = "assistant",
                                text = answerText,
                                timestamp = System.currentTimeMillis(),
                                followUps = inlineFollowUps,
                                contentProviderLogo = response.contentProviderLogo,
                                hideTtsSpeaker = response.hideTtsSpeaker ?: false,
                                serverMessageId = response.messageId,
                            )
                        )
                        // Fetch follow-ups from the dedicated endpoint if not supplied inline
                        // and the server hasn't explicitly hidden them
                        if (inlineFollowUps.isEmpty() &&
                            response.hideFollowUpQuestion != true &&
                            !response.messageId.isNullOrEmpty()
                        ) {
                            fetchAndAppendFollowUps(localId, response.messageId!!)
                        }
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

    /** Send a follow-up question (user tapped a suggestion chip). */
    fun sendFollowUp(text: String, followUpQuestionId: String? = null) {
        viewModelScope.launch {
            try {
                if (followUpQuestionId != null) {
                    apiClient?.trackFollowUpClick(text)
                }
            } catch (_: Exception) { }
        }
        sendQuery(text = text, inputMethod = "follow_up")
    }

    /** Replay the last failed query. */
    fun retryLastQuery() {
        try {
            val (text, inputMethod, imageData) = lastQuery ?: return
            _chatState.value = ChatUiState.Idle
            sendQuery(text = text, inputMethod = inputMethod, imageData = imageData)
        } catch (e: Exception) {
            Log.w(TAG, "retryLastQuery failed", e)
        }
    }

    /** Start a fresh conversation (clears messages and conversation ID). */
    fun startNewConversation() {
        conversationId = null
        _messages.value = emptyList()
        _chatState.value = ChatUiState.Idle
    }

    // ── Language (Android-only) ───────────────────────────────────────────────

    /**
     * Fetch supported languages grouped by country.
     *
     * country_code and state are read from [TokenStore] (populated by initialize_user).
     * Callers can override by passing explicit values; empty string means "use TokenStore value".
     */
    fun loadLanguages(countryCode: String = "", state: String = "") {
        // Resolve effective params: prefer explicit args, fall back to TokenStore geo-data
        val effectiveCountry = countryCode.ifEmpty { TokenStore.countryCode }
        val effectiveState   = state.ifEmpty { TokenStore.state }
        Log.d(TAG, "loadLanguages called — countryCode='$effectiveCountry' state='$effectiveState'" +
                " apiClient=${if (apiClient != null) "ready" else "NULL"}")
        viewModelScope.launch {
            try {
                val client = apiClient ?: run {
                    Log.e(TAG, "loadLanguages: SDK not initialized — call FarmerChat.initialize() first")
                    return@launch
                }
                Log.d(TAG, "loadLanguages: ensuring guest tokens…")
                ensureGuestTokensSuspend()
                Log.d(TAG, "loadLanguages: GET country_wise_supported_languages country=$effectiveCountry state=$effectiveState")
                val groups = client.getSupportedLanguages(effectiveCountry, effectiveState)
                Log.d(TAG, "loadLanguages: received ${groups.sumOf { it.languages.size }} languages in ${groups.size} groups")
                _availableLanguageGroups.value = groups
            } catch (e: Exception) {
                Log.e(TAG, "loadLanguages failed: ${e.message}", e)
            }
        }
    }

    /** Set preferred language on the server and locally. */
    fun setPreferredLanguage(language: SupportedLanguage) {
        Log.d(TAG, "setPreferredLanguage: ${language.code}")
        viewModelScope.launch {
            try {
                val client = apiClient ?: run {
                    Log.e(TAG, "setPreferredLanguage: SDK not initialized")
                    // Still apply locally so UI updates immediately
                    _selectedLanguage.value = language.code
                    SdkPreferences.selectedLanguage = language.code
                    return@launch
                }
                client.setPreferredLanguage(
                    userId = TokenStore.userId,
                    languageId = language.id.toString(),
                )
                val previousCode = _selectedLanguage.value
                _selectedLanguage.value = language.code
                SdkPreferences.selectedLanguage = language.code
                emitEvent(
                    FarmerChatEvent.LanguageChanged(
                        from = previousCode,
                        to = language.code,
                    )
                )
            } catch (e: Exception) {
                Log.w(TAG, "setPreferredLanguage failed: ${e.message}")
                // Still apply locally so UI updates even if server sync fails
                _selectedLanguage.value = language.code
                SdkPreferences.selectedLanguage = language.code
            }
        }
    }

    // ── History ───────────────────────────────────────────────────────────────

    /** Load the user's conversation list. */
    fun loadConversationList() {
        Log.d(TAG, "loadConversationList called — apiClient=${if (apiClient != null) "ready" else "NULL"}")
        _historyLoading.value = true
        viewModelScope.launch {
            try {
                val client = apiClient ?: run {
                    Log.e(TAG, "loadConversationList: SDK not initialized")
                    return@launch
                }
                ensureGuestTokensSuspend()
                val list = client.getConversationList(userId = TokenStore.userId)
                Log.d(TAG, "loadConversationList: received ${list.size} conversations")
                _conversationList.value = list
            } catch (e: Exception) {
                Log.e(TAG, "loadConversationList failed: ${e.message}", e)
            } finally {
                _historyLoading.value = false
            }
        }
    }

    /**
     * Load and display messages from a past conversation.
     * Replaces current messages and sets the active conversation ID.
     */
    fun loadConversation(conversationListItem: ConversationListItem) {
        Log.d(TAG, "loadConversation: ${conversationListItem.conversationId}")
        viewModelScope.launch {
            try {
                val client = apiClient ?: run {
                    Log.e(TAG, "loadConversation: SDK not initialized")
                    return@launch
                }
                ensureGuestTokensSuspend()
                val history = client.getChatHistory(conversationListItem.conversationId)
                conversationId = conversationListItem.conversationId
                val msgs = history.data.mapNotNull { item -> historyItemToChatMessage(item) }
                _messages.value = msgs
                _currentScreen.value = Screen.Chat
            } catch (e: Exception) {
                Log.w(TAG, "loadConversation failed: ${e.message}")
                emitEvent(FarmerChatEvent.Error("history_error", e.message ?: "Failed to load conversation"))
            }
        }
    }

    // ── TTS / STT ─────────────────────────────────────────────────────────────

    /**
     * Request TTS audio for an assistant message.
     * Returns base64-encoded audio string or null on failure.
     */
    suspend fun synthesiseAudio(serverMessageId: String, text: String): String? {
        return try {
            val client = apiClient ?: return null
            val resp = client.synthesiseAudio(
                messageId = serverMessageId,
                text = text,
                userId = TokenStore.userId,
            )
            resp.audio
        } catch (e: Exception) {
            Log.w(TAG, "synthesiseAudio failed: ${e.message}")
            null
        }
    }

    /**
     * Transcribe audio (STT).
     * Returns the transcribed text or null on failure.
     */
    suspend fun transcribeAudio(
        base64Audio: String,
        audioFormat: String = "AMR",
    ): String? {
        val convId = conversationId ?: return null
        return try {
            val client = apiClient ?: return null
            val resp = client.transcribeAudio(
                conversationId = convId,
                base64Audio = base64Audio,
                messageReferenceId = UUID.randomUUID().toString(),
                inputAudioEncodingFormat = audioFormat,
            )
            if (resp.error) null else resp.heardInputQuery
        } catch (e: Exception) {
            Log.w(TAG, "transcribeAudio failed: ${e.message}")
            null
        }
    }

    // ── Navigation ────────────────────────────────────────────────────────────

    fun navigateTo(screen: Screen) {
        try {
            // Mark onboarding complete the first time the user moves from Onboarding to Chat.
            if (_currentScreen.value == Screen.Onboarding && screen == Screen.Chat) {
                SdkPreferences.onboardingDone = true
            }
            _currentScreen.value = screen
        } catch (e: Exception) {
            Log.w(TAG, "navigateTo failed", e)
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private fun appendMessage(message: ChatMessage) {
        _messages.update { list ->
            val cap = config.maxMessagesInMemory
            val newList = list + message
            if (newList.size > cap) newList.takeLast(cap) else newList
        }
    }

    /**
     * Update the `followUps` field of an existing message in place.
     * Called after [fetchAndAppendFollowUps] completes.
     */
    private fun updateMessageFollowUps(localMessageId: String, followUps: List<FollowUp>) {
        _messages.update { list ->
            list.map { msg -> if (msg.id == localMessageId) msg.copy(followUps = followUps) else msg }
        }
    }

    /**
     * Fetch follow-up questions for a just-delivered AI message and attach them.
     * Runs in a separate coroutine so the UI is not blocked — follow-ups appear
     * shortly after the answer bubble.
     */
    private fun fetchAndAppendFollowUps(localMessageId: String, serverMessageId: String) {
        viewModelScope.launch {
            try {
                val client = apiClient ?: return@launch
                val resp = client.getFollowUpQuestions(messageId = serverMessageId)
                val followUps = resp.questions?.mapNotNull { fq ->
                    val q = fq.question ?: return@mapNotNull null
                    FollowUp(id = fq.followUpQuestionId, question = q, sequence = fq.sequence)
                } ?: return@launch
                if (followUps.isNotEmpty()) {
                    updateMessageFollowUps(localMessageId, followUps)
                }
            } catch (e: Exception) {
                Log.w(TAG, "fetchFollowUps failed (non-fatal): ${e.message}")
            }
        }
    }

    private fun emitEvent(event: FarmerChatEvent) {
        try { FarmerChat.eventCallback?.invoke(event) } catch (e: Exception) {
            Log.w(TAG, "Event callback threw", e)
        }
    }

    /**
     * Convert a [ConversationHistoryItem] (message_type_id 1,2,3,7,11) to a [ChatMessage].
     * Returns null for unsupported types.
     */
    private fun historyItemToChatMessage(item: ConversationHistoryItem): ChatMessage? {
        return when (item.messageTypeId) {
            1 -> ChatMessage(   // user text
                id = item.messageId,
                role = "user",
                text = item.queryText ?: "",
                timestamp = System.currentTimeMillis(),
                inputMethod = "text",
                serverMessageId = item.messageId,
            )
            2 -> ChatMessage(   // user audio
                id = item.messageId,
                role = "user",
                text = item.heardQueryText ?: item.queryText ?: "",
                timestamp = System.currentTimeMillis(),
                inputMethod = "audio",
                serverMessageId = item.messageId,
            )
            11 -> ChatMessage(  // user image
                id = item.messageId,
                role = "user",
                text = item.queryText ?: "",
                timestamp = System.currentTimeMillis(),
                inputMethod = "image",
                serverMessageId = item.messageId,
            )
            3 -> ChatMessage(   // AI text response
                id = item.messageId,
                role = "assistant",
                text = item.responseText ?: "",
                timestamp = System.currentTimeMillis(),
                followUps = item.questions?.map { q ->
                    FollowUp(id = q.followUpQuestionId, question = q.question, sequence = q.sequence)
                } ?: emptyList(),
                contentProviderLogo = item.contentProviderLogo,
                hideTtsSpeaker = item.hideTtsSpeaker ?: false,
                serverMessageId = item.messageId,
            )
            7 -> null   // follow-up block — already embedded in the preceding AI message
            else -> null
        }
    }
}
