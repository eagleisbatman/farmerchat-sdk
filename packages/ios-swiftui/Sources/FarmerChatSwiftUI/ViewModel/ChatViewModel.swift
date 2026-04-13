import SwiftUI
import Combine

/// ViewModel managing all chat state. In-memory only — no persistence.
///
/// Every public method is wrapped in do/catch — the SDK must NEVER crash the host app.
///
/// State transitions for `sendQuery`:
/// `idle` → `sending` → `complete` (or `error`)
@MainActor
internal final class ChatViewModel: ObservableObject {

    private static let tag = "FC.ChatVM"

    // MARK: - Nested Types

    enum ChatUiState: Equatable {
        case idle
        case sending
        case complete
        case error(code: String, message: String, retryable: Bool)
    }

    enum Screen {
        case onboarding
        case chat
        case history
        case profile
    }

    struct ChatMessage: Identifiable, Equatable {
        let id: String
        let role: String        // "user" | "assistant"
        var text: String
        let timestamp: Date
        var inputMethod: String?
        var imageData: String?
        var followUps: [FollowUp]
        var contentProviderLogo: String?
        var hideTtsSpeaker: Bool
        var serverMessageId: String?

        init(
            id: String,
            role: String,
            text: String,
            timestamp: Date = Date(),
            inputMethod: String? = nil,
            imageData: String? = nil,
            followUps: [FollowUp] = [],
            contentProviderLogo: String? = nil,
            hideTtsSpeaker: Bool = false,
            serverMessageId: String? = nil
        ) {
            self.id = id; self.role = role; self.text = text; self.timestamp = timestamp
            self.inputMethod = inputMethod; self.imageData = imageData
            self.followUps = followUps; self.contentProviderLogo = contentProviderLogo
            self.hideTtsSpeaker = hideTtsSpeaker; self.serverMessageId = serverMessageId
        }
    }

    struct FollowUp: Equatable {
        let id: String?
        let question: String
        let sequence: Int
    }

    // MARK: - Published State

    @Published private(set) var chatState: ChatUiState = .idle
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var currentScreen: Screen = .chat
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var selectedLanguage: String = "en"
    @Published private(set) var conversationList: [ConversationListItem] = []
    @Published private(set) var availableLanguageGroups: [SupportedLanguageGroup] = []
    @Published private(set) var historyLoading: Bool = false

    // MARK: - Internal Bookkeeping

    private var conversationId: String?
    private var lastQuery: (text: String, inputMethod: String, imageData: String?)?
    private var connectivityCancellable: AnyCancellable?

    private var config: FarmerChatConfig { FarmerChat.getConfig() }
    private var apiClient: ApiClient? { FarmerChat.shared.apiClient }
    private var sessionId: String { FarmerChat.shared.getSessionId() }

    // MARK: - Init

    init() {
        // Language: host config > persisted UserDefaults pref > "en"
        let savedLang = UserDefaults.standard.string(forKey: "fc_selected_language") ?? ""
        selectedLanguage = config.defaultLanguage ?? (savedLang.isEmpty ? "en" : savedLang)

        // Determine starting screen:
        //  host supplied defaultLanguage → skip onboarding
        //  user already completed onboarding → go straight to chat
        //  otherwise show onboarding (first launch)
        let onboardingDone = UserDefaults.standard.bool(forKey: "fc_onboarding_done")
        currentScreen = (config.defaultLanguage != nil || onboardingDone) ? .chat : .onboarding

        if let monitor = FarmerChat.shared.connectivityMonitor {
            connectivityCancellable = monitor.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] connected in self?.isConnected = connected }
        }

        Task {
            await ensureGuestTokens()
        }
    }

    // MARK: - Guest token guard

    private func ensureGuestTokens() async {
        let initialized = await TokenStore.shared.isInitialized
        guard !initialized else { return }
        do {
            let deviceId = await TokenStore.shared.deviceId
            try await GuestAPIClient(baseUrl: config.baseUrl).initializeUser(deviceId: deviceId)
        } catch {
            print("[\(Self.tag)] Guest token init failed: \(error)")
        }
    }

    // MARK: - Public Actions

    /// Send a weather-context query (tapping the weather widget). Sets weather_cta_triggered = true.
    func sendWeatherQuery(_ question: String) {
        sendQuery(text: question, inputMethod: "text", weatherCtaTriggered: true)
    }

    /// Send a text query (optionally with a base64 image and GPS coordinates from EXIF).
    func sendQuery(
        text: String,
        inputMethod: String = "text",
        imageData: String? = nil,
        weatherCtaTriggered: Bool = false,
        imageLatitude: String? = nil,
        imageLongitude: String? = nil
    ) {
        guard let client = apiClient else {
            chatState = .error(code: "sdk_not_initialized",
                               message: "FarmerChat SDK is not initialized",
                               retryable: false)
            return
        }

        lastQuery = (text: text, inputMethod: inputMethod, imageData: imageData)

        let userMessageId = UUID().uuidString
        appendMessage(ChatMessage(
            id: userMessageId,
            role: "user",
            text: text,
            inputMethod: inputMethod,
            imageData: imageData
        ))
        chatState = .sending

        emitEvent(.querySent(sessionId: sessionId, queryId: userMessageId,
                              inputMethod: inputMethod, timestamp: Date()))

        Task { [weak self] in
            guard let self else { return }
            do {
                await self.ensureGuestTokens()

                // Create conversation on first message
                if self.conversationId == nil {
                    let userId = await TokenStore.shared.userId
                    let conv = try await client.createNewConversation(
                        userId: userId,
                        contentProviderId: self.config.contentProviderId
                    )
                    self.conversationId = conv.conversationId
                }
                let convId = self.conversationId!
                let clientMessageId = UUID().uuidString
                let sendStart = Date()

                if let base64 = imageData {
                    // Image analysis — include GPS from EXIF if available
                    let resp = try await client.sendImageAnalysis(
                        conversationId: convId,
                        base64Image: base64,
                        imageName: "image_\(UUID().uuidString).jpg",
                        latitude: imageLatitude,
                        longitude: imageLongitude
                    )
                    self.appendMessage(ChatMessage(
                        id: UUID().uuidString,
                        role: "assistant",
                        text: resp.response,
                        followUps: resp.followUpQuestions?.map {
                            FollowUp(id: $0.followUpQuestionId, question: $0.question ?? "", sequence: $0.sequence ?? 0)
                        } ?? [],
                        contentProviderLogo: resp.contentProviderLogo,
                        hideTtsSpeaker: resp.hideTtsSpeaker ?? false,
                        serverMessageId: resp.messageId
                    ))
                } else {
                    // Text prompt
                    let resp = try await client.sendTextPrompt(
                        query: text,
                        conversationId: convId,
                        messageId: clientMessageId,
                        triggeredInputType: inputMethod,
                        weatherCtaTriggered: weatherCtaTriggered
                    )
                    print("[\(Self.tag)] sendTextPrompt response field='\(resp.response ?? "<nil>")' message='\(resp.message ?? "<nil>")' messageId='\(resp.messageId ?? "<nil>")'")
                    let answerText = resp.response ?? resp.message ?? ""
                    let inlineFollowUps = resp.followUpQuestions?.map {
                        FollowUp(id: $0.followUpQuestionId, question: $0.question ?? "", sequence: $0.sequence ?? 0)
                    } ?? []
                    let aiMsgId = UUID().uuidString
                    self.appendMessage(ChatMessage(
                        id: aiMsgId,
                        role: "assistant",
                        text: answerText,
                        followUps: inlineFollowUps,
                        contentProviderLogo: resp.contentProviderLogo,
                        hideTtsSpeaker: resp.hideTtsSpeaker ?? false,
                        serverMessageId: resp.messageId
                    ))

                    // Fetch follow-up questions via dedicated endpoint (preferred source).
                    // Falls back to inline follow_up_questions already appended above.
                    if resp.hideFollowUpQuestion != true, let msgId = resp.messageId, !msgId.isEmpty {
                        if let fuResp = try? await client.fetchFollowUpQuestions(messageId: msgId) {
                            let fetched = fuResp.questions?.map {
                                FollowUp(id: $0.followUpQuestionId, question: $0.question, sequence: $0.sequence)
                            } ?? []
                            if !fetched.isEmpty, let idx = self.messages.firstIndex(where: { $0.id == aiMsgId }) {
                                self.messages[idx].followUps = fetched
                            }
                        }
                    }
                }

                self.chatState = .complete
                let latencyMs = Int64(Date().timeIntervalSince(sendStart) * 1000)
                self.emitEvent(.responseReceived(sessionId: self.sessionId,
                                                  responseId: clientMessageId,
                                                  latencyMs: latencyMs,
                                                  timestamp: Date()))
            } catch {
                print("[\(Self.tag)] sendQuery failed: \(error)")
                self.chatState = .error(code: "send_error",
                                        message: error.localizedDescription,
                                        retryable: true)
                self.emitEvent(.error(code: "send_error",
                                       message: error.localizedDescription,
                                       fatal: false, timestamp: Date()))
            }
        }
    }

    /// Send a follow-up question.
    func sendFollowUp(text: String, followUpId: String? = nil) {
        if followUpId != nil {
            // pass the question text (not the id) as the API expects the question string
            Task { try? await apiClient?.trackFollowUpClick(followUpQuestion: text) }
        }
        sendQuery(text: text, inputMethod: "follow_up")
    }

    /// Replay the last failed query.
    func retryLastQuery() {
        guard let q = lastQuery else { return }
        chatState = .idle
        sendQuery(text: q.text, inputMethod: q.inputMethod, imageData: q.imageData)
    }

    /// Start a fresh conversation.
    func startNewConversation() {
        conversationId = nil
        messages = []
        chatState = .idle
    }

    // MARK: - History

    func loadConversationList() {
        print("[\(Self.tag)] loadConversationList called — apiClient=\(apiClient != nil ? "ready" : "NIL")")
        guard apiClient != nil else {
            print("[\(Self.tag)] loadConversationList: SDK not initialized")
            return
        }
        Task { [weak self] in
            guard let self, let client = self.apiClient else { return }
            self.historyLoading = true
            defer { self.historyLoading = false }
            do {
                await self.ensureGuestTokens()
                let userId = await TokenStore.shared.userId
                print("[\(Self.tag)] loadConversationList: fetching for userId=\(userId)")
                let list = try await client.fetchConversationList(userId: userId)
                print("[\(Self.tag)] loadConversationList: received \(list.count) conversations")
                self.conversationList = list
            } catch {
                print("[\(Self.tag)] loadConversationList FAILED: \(error)")
            }
        }
    }

    func loadConversation(_ item: ConversationListItem) {
        guard let convId = item.conversationId else { return }
        Task { [weak self] in
            guard let self, let client = self.apiClient else { return }
            do {
                await self.ensureGuestTokens()
                let history = try await client.fetchChatHistory(conversationId: convId)
                self.conversationId = convId
                self.messages = self.processHistoryItems(history.data)
                self.currentScreen = .chat
            } catch {
                print("[\(Self.tag)] loadConversation failed: \(error)")
                self.emitEvent(.error(code: "history_error", message: error.localizedDescription, fatal: false, timestamp: Date()))
            }
        }
    }

    /// Converts raw history items into ChatMessage objects.
    /// - Groups items into sections (each starting with a user message type 1/2/11)
    /// - Reverses section order so oldest conversation appears first (top of screen)
    /// - Merges type-7 follow_up_questions rows into the preceding AI message bubble
    private func processHistoryItems(_ items: [ChatHistoryItem]) -> [ChatMessage] {
        // Build sections
        var sections: [[ChatHistoryItem]] = []
        var current: [ChatHistoryItem] = []
        for item in items {
            let startsSection = [1, 2, 11].contains(item.messageTypeId)
            if startsSection && !current.isEmpty {
                sections.append(current)
                current = []
            }
            current.append(item)
        }
        if !current.isEmpty { sections.append(current) }

        // Reverse so oldest section is first
        let ordered = sections.reversed().flatMap { $0 }

        // Map to ChatMessage, attaching type-7 follow-ups to the preceding AI bubble
        var result: [ChatMessage] = []
        for item in ordered {
            if item.messageTypeId == 7 {
                guard let qs = item.questions, !qs.isEmpty else { continue }
                if let lastAiIdx = result.indices.last(where: { result[$0].role == "assistant" }) {
                    let mapped = qs.map { FollowUp(id: $0.followUpQuestionId, question: $0.question ?? "", sequence: $0.sequence) }
                    result[lastAiIdx].followUps = mapped
                }
            } else if let msg = historyItemToMessage(item) {
                result.append(msg)
            }
        }
        return result
    }

    // MARK: - TTS / STT

    func synthesiseAudio(serverMessageId: String, text: String) async -> String? {
        guard let client = apiClient else { return nil }
        do {
            let userId = await TokenStore.shared.userId
            let resp = try await client.synthesiseAudio(messageId: serverMessageId, text: text, userId: userId)
            return resp.audioUrl
        } catch {
            print("[\(Self.tag)] synthesiseAudio failed: \(error)")
            return nil
        }
    }

    func transcribeAudio(_ request: TranscribeAudioRequest) async -> String? {
        guard let client = apiClient else { return nil }
        do {
            let resp = try await client.transcribeAudio(request)
            return resp.error ? nil : resp.heardInputQuery
        } catch {
            print("[\(Self.tag)] transcribeAudio failed: \(error)")
            return nil
        }
    }

    /// Full voice flow: transcribe audio bytes → send as text query.
    func transcribeAndSendAudio(audioData: Data) {
        guard let client = apiClient else { return }
        let audioMsgId = UUID().uuidString
        appendMessage(ChatMessage(id: audioMsgId, role: "user", text: "🎤 …", inputMethod: "audio"))
        chatState = .sending
        Task { [weak self] in
            guard let self else { return }
            await self.ensureGuestTokens()
            if self.conversationId == nil {
                let userId = await TokenStore.shared.userId
                if let conv = try? await client.createNewConversation(
                    userId: userId, contentProviderId: self.config.contentProviderId) {
                    self.conversationId = conv.conversationId
                }
            }
            let userId = await TokenStore.shared.userId
            let request = TranscribeAudioRequest(
                audioData: audioData,
                userId: userId,
                conversationId: self.conversationId,
                language: self.selectedLanguage.isEmpty ? nil : self.selectedLanguage
            )
            let transcript = await self.transcribeAudio(request)
            guard let transcript, !transcript.trimmingCharacters(in: .whitespaces).isEmpty else {
                self.messages = self.messages.map {
                    $0.id == audioMsgId ? ChatMessage(id: $0.id, role: "user", text: "⚠️ Could not understand audio", inputMethod: "audio") : $0
                }
                self.chatState = .idle
                return
            }
            self.messages = self.messages.map {
                $0.id == audioMsgId ? ChatMessage(id: $0.id, role: "user", text: transcript, inputMethod: "audio") : $0
            }
            self.sendQuery(text: transcript, inputMethod: "audio")
        }
    }

    /// Send a base64 image with optional caption through image_analysis/ endpoint.
    /// Optionally pass the source URL so GPS EXIF can be extracted.
    func sendQueryWithImage(caption: String, base64Image: String, sourceURL: URL? = nil) {
        if let url = sourceURL, let gps = ImageProcessor.extractGPS(from: url) {
            sendQuery(
                text: caption.isEmpty ? "Analyze this image" : caption,
                inputMethod: "image",
                imageData: base64Image,
                imageLatitude: gps.latitude,
                imageLongitude: gps.longitude
            )
        } else {
            sendQuery(text: caption.isEmpty ? "Analyze this image" : caption,
                      inputMethod: "image", imageData: base64Image)
        }
    }

    // MARK: - Navigation

    func navigateTo(_ screen: Screen) {
        if currentScreen == .onboarding && screen == .chat {
            UserDefaults.standard.set(true, forKey: "fc_onboarding_done")
        }
        currentScreen = screen
    }

    /// Update the user's preferred language and persist for future launches.
    func setPreferredLanguage(_ language: SupportedLanguage) {
        let previous = selectedLanguage
        selectedLanguage = language.code
        UserDefaults.standard.set(language.code, forKey: "fc_selected_language")
        emitEvent(.languageChanged(from: previous, to: language.code, timestamp: Date()))
    }

    /// Fetch supported languages from the server and update [availableLanguageGroups].
    func loadLanguages() {
        guard let client = apiClient else {
            print("[\(Self.tag)] loadLanguages: SDK not initialized — call FarmerChat.configure() first")
            return
        }
        print("[\(Self.tag)] loadLanguages called")
        Task { [weak self] in
            guard let self else { return }
            do {
                await self.ensureGuestTokens()
                print("[\(Self.tag)] loadLanguages: guest tokens ready, fetching…")

                // Priority: FarmerChatConfig.countryCode → TokenStore (IP geo) → Locale (SIM/region) → "IN"
                let configCC  = FarmerChat.getConfig().countryCode
                let tokenCC   = await TokenStore.shared.countryCode
                let localeCC: String = {
                    if #available(iOS 16, *) {
                        return Locale.current.region?.identifier.uppercased() ?? ""
                    } else {
                        return Locale.current.regionCode?.uppercased() ?? ""
                    }
                }()
                let effectiveCC: String
                if !configCC.isEmpty   { effectiveCC = configCC }
                else if !tokenCC.isEmpty { effectiveCC = tokenCC }
                else if !localeCC.isEmpty { effectiveCC = localeCC }
                else { effectiveCC = "IN" }

                print("[\(Self.tag)] loadLanguages: countryCode='\(effectiveCC)' (config='\(configCC)' token='\(tokenCC)' locale='\(localeCC)')")
                let groups = try await client.getSupportedLanguages(countryCode: effectiveCC)
                print("[\(Self.tag)] loadLanguages: received \(groups.flatMap { $0.languages }.count) languages")
                await MainActor.run {
                    self.availableLanguageGroups = groups
                }
            } catch {
                print("[\(Self.tag)] loadLanguages FAILED: \(error)")
            }
        }
    }

    // Previously used by FarmerChat.destroy() — safe no-op now
    func stopStream() {}

    // MARK: - Private helpers

    private func appendMessage(_ message: ChatMessage) {
        let cap = config.maxMessagesInMemory
        messages.append(message)
        if messages.count > cap { messages = Array(messages.suffix(cap)) }
    }

    private func emitEvent(_ event: FarmerChatEvent) {
        FarmerChat.shared.eventCallback?(event)
    }

    private func historyItemToMessage(_ item: ChatHistoryItem) -> ChatMessage? {
        switch item.messageTypeId {
        case 1:
            return ChatMessage(id: item.messageId, role: "user",
                               text: item.queryText ?? "", inputMethod: "text",
                               serverMessageId: item.messageId)
        case 2:
            return ChatMessage(id: item.messageId, role: "user",
                               text: item.heardQueryText ?? item.queryText ?? "",
                               inputMethod: "audio", serverMessageId: item.messageId)
        case 11:
            return ChatMessage(id: item.messageId, role: "user",
                               text: item.queryText ?? "", inputMethod: "image",
                               serverMessageId: item.messageId)
        case 3:
            return ChatMessage(
                id: item.messageId,
                role: "assistant",
                text: item.responseText ?? "",
                followUps: item.questions?.map { q in
                    FollowUp(id: q.followUpQuestionId, question: q.question, sequence: q.sequence)
                } ?? [],
                contentProviderLogo: item.contentProviderLogo,
                hideTtsSpeaker: item.hideTtsSpeaker ?? false,
                serverMessageId: item.messageId
            )
        default:
            return nil
        }
    }
}
