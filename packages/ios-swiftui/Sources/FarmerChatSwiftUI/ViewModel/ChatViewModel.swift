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

    // MARK: - Internal Bookkeeping

    private var conversationId: String?
    private var lastQuery: (text: String, inputMethod: String, imageData: String?)?
    private var connectivityCancellable: AnyCancellable?

    private var config: FarmerChatConfig { FarmerChat.getConfig() }
    private var apiClient: ApiClient? { FarmerChat.shared.apiClient }
    private var sessionId: String { FarmerChat.shared.getSessionId() }

    // MARK: - Init

    init() {
        selectedLanguage = config.defaultLanguage ?? "en"

        if let monitor = FarmerChat.shared.connectivityMonitor {
            connectivityCancellable = monitor.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] connected in self?.isConnected = connected }
        }

        // Ensure guest tokens on init
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

    /// Send a text query (optionally with a base64 image).
    func sendQuery(text: String, inputMethod: String = "text", imageData: String? = nil) {
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
                    // Image analysis
                    let resp = try await client.sendImageAnalysis(
                        conversationId: convId,
                        base64Image: base64,
                        imageName: "image_\(UUID().uuidString).jpg"
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
                    let userId = await TokenStore.shared.userId
                    _ = userId  // userId embedded in token; not sent in text prompt body
                    let resp = try await client.sendTextPrompt(
                        query: text,
                        conversationId: convId,
                        messageId: clientMessageId,
                        triggeredInputType: inputMethod
                    )
                    let answerText = resp.response ?? resp.message ?? ""
                    self.appendMessage(ChatMessage(
                        id: UUID().uuidString,
                        role: "assistant",
                        text: answerText,
                        followUps: resp.followUpQuestions?.map {
                            FollowUp(id: $0.followUpQuestionId, question: $0.question ?? "", sequence: $0.sequence ?? 0)
                        } ?? [],
                        contentProviderLogo: resp.contentProviderLogo,
                        hideTtsSpeaker: resp.hideTtsSpeaker ?? false,
                        serverMessageId: resp.messageId
                    ))
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
        if let id = followUpId {
            Task { try? await apiClient?.trackFollowUpClick(followUpQuestion: id) }
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
        Task { [weak self] in
            guard let self, let client = self.apiClient else { return }
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
        guard let convId = item.conversationId else { return }
        Task { [weak self] in
            guard let self, let client = self.apiClient else { return }
            do {
                let history = try await client.fetchChatHistory(conversationId: convId)
                self.conversationId = convId
                self.messages = history.data.compactMap { self.historyItemToMessage($0) }
                self.currentScreen = .chat
            } catch {
                print("[\(Self.tag)] loadConversation failed: \(error)")
                self.emitEvent(.error(code: "history_error", message: error.localizedDescription, fatal: false, timestamp: Date()))
            }
        }
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

    // MARK: - Navigation

    func navigateTo(_ screen: Screen) { currentScreen = screen }

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
