import Foundation
import Combine

/// ViewModel managing all chat state for the UIKit SDK.
/// Mirrors the architecture of the SwiftUI SDK's ChatViewModel.
@MainActor
internal final class ChatViewModel: ObservableObject {

    private static let tag = "FC.UIKit.ChatVM"

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
        let role: String   // "user" or "assistant"
        var text: String
        let timestamp: Date
        var inputMethod: String?
        var imageData: String?
        var followUps: [FollowUpQuestionOption]
        var feedbackRating: String?
        var hideTtsSpeaker: Bool
        var serverMessageId: String?

        init(
            id: String, role: String, text: String,
            timestamp: Date = Date(), inputMethod: String? = nil,
            imageData: String? = nil, followUps: [FollowUpQuestionOption] = [],
            feedbackRating: String? = nil,
            hideTtsSpeaker: Bool = false,
            serverMessageId: String? = nil
        ) {
            self.id = id; self.role = role; self.text = text
            self.timestamp = timestamp; self.inputMethod = inputMethod
            self.imageData = imageData; self.followUps = followUps
            self.feedbackRating = feedbackRating
            self.hideTtsSpeaker = hideTtsSpeaker
            self.serverMessageId = serverMessageId
        }
    }

    // MARK: - Published State

    @Published private(set) var chatState: ChatUiState = .idle
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var currentScreen: Screen = .chat
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var selectedLanguage: String = "en"
    @Published private(set) var availableLanguages: [SupportedLanguage] = []
    @Published private(set) var conversationList: [ConversationListItem] = []
    @Published private(set) var starterQuestions: [String] = []

    private var cancellables = Set<AnyCancellable>()
    private var conversationId: String?
    private var lastQuery: (text: String, inputMethod: String)?

    private var config: FarmerChatConfig { FarmerChat.getConfig() }
    private var apiClient: ApiClient? { FarmerChat.shared.apiClient }

    // MARK: - Init

    init() {
        selectedLanguage = SdkPreferences.selectedLanguage ?? config.defaultLanguage ?? "en"
        if let monitor = FarmerChat.shared.connectivityMonitor {
            monitor.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.isConnected = $0 }
                .store(in: &cancellables)
        }
    }

    // MARK: - Ensure tokens

    private func ensureGuestTokens() async {
        let ok = await TokenStore.shared.isInitialized
        if !ok {
            let deviceId = SdkPreferences.stableDeviceId
            await FarmerChat.shared.ensureGuestUser(baseUrl: config.baseUrl, deviceId: deviceId)
        }
    }

    // MARK: - Send query

    func sendQuery(text: String, inputMethod: String = "text", weatherCtaTriggered: Bool = false) {
        guard let client = apiClient else {
            chatState = .error(code: "sdk_not_initialized", message: "SDK not initialized", retryable: false)
            return
        }
        lastQuery = (text, inputMethod)
        let userMsg = ChatMessage(id: UUID().uuidString, role: "user", text: text, inputMethod: inputMethod)
        appendMessage(userMsg)
        chatState = .sending

        Task { [weak self] in
            guard let self else { return }
            do {
                await self.ensureGuestTokens()

                // Create a new conversation if needed
                if self.conversationId == nil {
                    let userId = await TokenStore.shared.userId
                    let conv = try await client.createNewConversation(userId: userId)
                    self.conversationId = conv.conversationId
                }
                guard let convId = self.conversationId else { return }

                let resp = try await client.sendTextPrompt(
                    query: text,
                    conversationId: convId,
                    messageId: UUID().uuidString,
                    triggeredInputType: inputMethod,
                    weatherCtaTriggered: weatherCtaTriggered
                )

                let responseText = resp.response ?? resp.message ?? ""
                let followUps    = resp.followUpQuestions ?? []
                let msgId        = resp.messageId ?? UUID().uuidString
                let aiMsg = ChatMessage(id: msgId, role: "assistant", text: responseText, followUps: followUps)
                self.appendMessage(aiMsg)
                self.chatState = .complete

                // Fetch follow-ups if none returned inline
                if followUps.isEmpty, let msgId = resp.messageId {
                    if let fuResp = try? await client.fetchFollowUpQuestions(messageId: msgId) {
                        let mapped = fuResp.questions?.map {
                            FollowUpQuestionOption(followUpQuestionId: $0.followUpQuestionId,
                                                   question: $0.question, sequence: $0.sequence)
                        } ?? []
                        if !mapped.isEmpty {
                            self.updateMessage(id: aiMsg.id) { $0.followUps = mapped }
                        }
                    }
                }
            } catch {
                print("[\(Self.tag)] sendQuery failed: \(error)")
                self.chatState = .error(code: "send_error", message: error.localizedDescription, retryable: true)
            }
        }
    }

    func sendFollowUp(text: String, followUpId: String? = nil) {
        if let fid = followUpId {
            Task { try? await apiClient?.trackFollowUpClick(question: fid) }
        }
        sendQuery(text: text, inputMethod: "follow_up")
    }

    // Legacy overload kept for existing call sites
    func sendFollowUp(text: String) {
        sendFollowUp(text: text, followUpId: nil)
    }

    func sendWeatherQuery(_ question: String) {
        sendQuery(text: question, inputMethod: "text", weatherCtaTriggered: true)
    }

    func retryLastQuery() {
        guard let q = lastQuery else { return }
        chatState = .idle
        sendQuery(text: q.text, inputMethod: q.inputMethod)
    }

    func stopStream() {
        // The UIKit ViewModel doesn't stream tokens, but provide the method
        // so ChatViewController can call it on stop-button tap.
        if case .sending = chatState { chatState = .complete }
    }

    func submitFeedback(messageId: String, rating: String, comment: String? = nil) {
        Task { [weak self] in
            guard let self, let client = self.apiClient else { return }
            // Best-effort; ignore errors silently to avoid disrupting UX
            _ = try? await client.trackFollowUpClick(question: messageId)
            self.updateMessage(id: messageId) { $0.feedbackRating = rating }
        }
    }

    // MARK: - Image analysis

    func sendQueryWithImage(base64Image: String, imageName: String,
                            query: String? = nil,
                            latitude: String? = nil, longitude: String? = nil) {
        guard let client = apiClient else { return }
        let userMsg = ChatMessage(id: UUID().uuidString, role: "user",
                                  text: query ?? "", inputMethod: "image", imageData: base64Image)
        appendMessage(userMsg)
        chatState = .sending

        Task { [weak self] in
            guard let self else { return }
            do {
                await self.ensureGuestTokens()
                if self.conversationId == nil {
                    let userId = await TokenStore.shared.userId
                    let conv = try await client.createNewConversation(userId: userId)
                    self.conversationId = conv.conversationId
                }
                guard let convId = self.conversationId else { return }

                let resp = try await client.sendImageAnalysis(
                    conversationId: convId, base64Image: base64Image,
                    imageName: imageName, latitude: latitude, longitude: longitude, query: query
                )
                let followUps = resp.followUpQuestions ?? []
                let aiMsg = ChatMessage(id: resp.messageId, role: "assistant",
                                        text: resp.response, followUps: followUps)
                self.appendMessage(aiMsg)
                self.chatState = .complete
            } catch {
                print("[\(Self.tag)] sendQueryWithImage failed: \(error)")
                self.chatState = .error(code: "image_error", message: error.localizedDescription, retryable: true)
            }
        }
    }

    // MARK: - Voice / STT

    func transcribeAndSendAudio(_ audioData: Data, conversationId: String? = nil) {
        guard let client = apiClient else { return }
        chatState = .sending

        Task { [weak self] in
            guard let self else { return }
            do {
                await self.ensureGuestTokens()
                let userId = await TokenStore.shared.userId
                let request = TranscribeAudioRequest(
                    audioData: audioData, userId: userId,
                    conversationId: conversationId ?? self.conversationId,
                    language: self.selectedLanguage
                )
                let resp = try await client.transcribeAudio(request)
                if resp.error { throw NetworkError.unknown("Transcription failed") }
                let text = resp.heardInputQuery ?? ""
                self.sendQuery(text: text, inputMethod: "voice")
            } catch {
                print("[\(Self.tag)] transcribeAudio failed: \(error)")
                self.chatState = .error(code: "audio_error", message: error.localizedDescription, retryable: true)
            }
        }
    }

    // MARK: - History / Conversation list

    func loadConversationList() {
        guard let client = apiClient else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                await self.ensureGuestTokens()
                let userId = await TokenStore.shared.userId
                let list = try await client.fetchConversationList(userId: userId)
                self.conversationList = list
            } catch {
                print("[\(Self.tag)] loadConversationList failed: \(error)")
            }
        }
    }

    func loadConversation(_ item: ConversationListItem) {
        guard let convId = item.conversationId, let client = apiClient else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                await self.ensureGuestTokens()
                let history = try await client.fetchChatHistory(conversationId: convId)
                self.conversationId = convId
                self.messages = self.processHistoryItems(history.data)
                self.currentScreen = .chat
            } catch {
                print("[\(Self.tag)] loadConversation failed: \(error)")
            }
        }
    }

    /// Converts raw history items into ChatMessage objects.
    /// Groups into sections (user message = section start), reverses so oldest is first,
    /// and attaches type-7 follow-up rows to the preceding AI bubble.
    private func processHistoryItems(_ items: [ChatHistoryItem]) -> [ChatMessage] {
        var sections: [[ChatHistoryItem]] = []
        var current: [ChatHistoryItem]   = []
        for item in items {
            if [1, 2, 11].contains(item.messageTypeId), !current.isEmpty {
                sections.append(current); current = []
            }
            current.append(item)
        }
        if !current.isEmpty { sections.append(current) }
        let ordered = sections.reversed().flatMap { $0 }

        var result: [ChatMessage] = []
        for item in ordered {
            if item.messageTypeId == 7 {
                guard let qs = item.questions, !qs.isEmpty else { continue }
                if let lastIdx = result.indices.last(where: { result[$0].role == "assistant" }) {
                    result[lastIdx].followUps = qs.map {
                        FollowUpQuestionOption(followUpQuestionId: $0.followUpQuestionId,
                                               question: $0.question, sequence: $0.sequence)
                    }
                }
            } else if let msg = historyItemToMessage(item) {
                result.append(msg)
            }
        }
        return result
    }

    private func historyItemToMessage(_ item: ChatHistoryItem) -> ChatMessage? {
        switch item.messageTypeId {
        case 1, 2, 11:   // user text / voice / image
            let text = item.queryText ?? item.heardQueryText ?? ""
            guard !text.isEmpty else { return nil }
            return ChatMessage(id: item.messageId, role: "user", text: text,
                               imageData: item.queryMediaFileUrl)
        case 3, 4, 5, 6: // assistant text / image response
            let text = item.responseText ?? ""
            guard !text.isEmpty else { return nil }
            return ChatMessage(id: item.messageId, role: "assistant", text: text)
        default: return nil
        }
    }

    // MARK: - Language

    func loadLanguages() {
        guard let client = apiClient else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                await self.ensureGuestTokens()

                // Priority: FarmerChatConfig.countryCode → TokenStore (IP geo) → Locale (SIM/region) → "IN"
                let configCC = self.config.countryCode
                let tokenCC  = await TokenStore.shared.countryCode
                let localeCC: String = {
                    if #available(iOS 16, *) {
                        return Locale.current.region?.identifier.uppercased() ?? ""
                    } else {
                        return Locale.current.regionCode?.uppercased() ?? ""
                    }
                }()
                let effectiveCC: String
                if !configCC.isEmpty    { effectiveCC = configCC }
                else if !tokenCC.isEmpty  { effectiveCC = tokenCC }
                else if !localeCC.isEmpty { effectiveCC = localeCC }
                else { effectiveCC = "IN" }

                print("[\(Self.tag)] loadLanguages: countryCode='\(effectiveCC)'")
                let groups = try await client.getSupportedLanguages(countryCode: effectiveCC)
                self.availableLanguages = groups.flatMap { $0.languages }
            } catch {
                print("[\(Self.tag)] loadLanguages failed: \(error)")
            }
        }
    }

    func setLanguage(code: String) {
        selectedLanguage = code
        SdkPreferences.selectedLanguage = code
    }

    // MARK: - Onboarding

    func completeOnboarding(language: String) {
        setLanguage(code: language)
        SdkPreferences.isOnboardingDone = true
        currentScreen = .chat
    }

    // MARK: - Navigation

    func navigateTo(screen: Screen) { currentScreen = screen }

    func loadStarters() {
        // Starter questions are not used in the UIKit SDK's MVP; no-op.
    }

    // MARK: - TTS (synthesise_audio)

    /// Calls the synthesise_audio endpoint and returns the audio URL, or nil on failure.
    func synthesiseAudio(serverMessageId: String, text: String) async -> String? {
        guard let client = FarmerChat.shared.apiClient else { return nil }
        do {
            let userId = await TokenStore.shared.userId
            let resp = try await client.synthesiseAudio(
                messageId: serverMessageId, text: text, userId: userId)
            return resp.audioUrl
        } catch {
            print("[\(Self.tag)] synthesiseAudio failed: \(error)")
            return nil
        }
    }

    // MARK: - New conversation

    func startNewConversation() {
        conversationId = nil
        messages = []
        chatState = .idle
    }

    // MARK: - Private helpers

    private func appendMessage(_ msg: ChatMessage) {
        let cap = config.maxMessagesInMemory
        messages.append(msg)
        if messages.count > cap { messages = Array(messages.suffix(cap)) }
    }

    private func updateMessage(id: String, transform: (inout ChatMessage) -> Void) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            transform(&messages[idx])
        }
    }

    private func emitEvent(_ event: FarmerChatEvent) {
        FarmerChat.shared.eventCallback?(event)
    }
}
