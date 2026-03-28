import Foundation
import Combine

/// ViewModel managing all chat state. In-memory only -- no persistence.
///
/// Every public method is wrapped in do/catch -- the SDK must NEVER crash the host app.
///
/// State transitions for ``sendQuery(text:inputMethod:imageData:)``:
/// `idle` -> `sending` -> `streaming` -> `complete` (or `error`)
///
/// Port of `ChatViewModel` from the SwiftUI SDK, adapted for UIKit via Combine subscribers.
@MainActor
internal final class ChatViewModel: ObservableObject {

    private static let tag = "FC.ChatVM"

    // MARK: - Nested Types

    /// Current state of a chat operation.
    enum ChatUiState: Equatable {
        case idle
        case sending
        case streaming(partialText: String, tokenCount: Int)
        case complete
        case error(code: String, message: String, retryable: Bool)
    }

    /// Top-level screen navigation within the SDK.
    enum Screen {
        case onboarding
        case chat
        case history
        case profile
    }

    /// A single message displayed in the chat list.
    struct ChatMessage: Identifiable, Equatable {
        let id: String
        let role: String  // "user" or "assistant"
        var text: String
        let timestamp: Date
        var inputMethod: String?
        var imageData: String?
        var followUps: [String]
        var sources: [Source]
        var imageUrl: String?
        var feedbackRating: String?

        init(
            id: String,
            role: String,
            text: String,
            timestamp: Date = Date(),
            inputMethod: String? = nil,
            imageData: String? = nil,
            followUps: [String] = [],
            sources: [Source] = [],
            imageUrl: String? = nil,
            feedbackRating: String? = nil
        ) {
            self.id = id
            self.role = role
            self.text = text
            self.timestamp = timestamp
            self.inputMethod = inputMethod
            self.imageData = imageData
            self.followUps = followUps
            self.sources = sources
            self.imageUrl = imageUrl
            self.feedbackRating = feedbackRating
        }
    }

    /// A citation source attached to an assistant message.
    struct Source: Equatable {
        let title: String
        let url: String?

        init(title: String, url: String? = nil) {
            self.title = title
            self.url = url
        }
    }

    // MARK: - Published State

    @Published private(set) var chatState: ChatUiState = .idle
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var currentScreen: Screen = .chat
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var starterQuestions: [StarterQuestionResponse] = []
    @Published private(set) var selectedLanguage: String = "en"
    @Published private(set) var availableLanguages: [LanguageResponse] = []

    // MARK: - Internal Bookkeeping

    /// Active SSE stream task -- cancelled by ``stopStream()``.
    private var streamTask: Task<Void, Never>?

    /// Stores the last query so ``retryLastQuery()`` can replay it.
    private var lastQuery: (text: String, inputMethod: String, imageData: String?)?

    /// Cancellable for connectivity monitor subscription.
    private var connectivityCancellable: AnyCancellable?

    private var config: FarmerChatConfig { FarmerChat.getConfig() }
    private var apiClient: ApiClient? { FarmerChat.shared.apiClient }
    private var sessionId: String { FarmerChat.shared.getSessionId() }

    // MARK: - Init

    init() {
        // Seed the default language from config, or fall back to "en"
        selectedLanguage = config.defaultLanguage ?? "en"

        // Wire up connectivity monitor
        if let monitor = FarmerChat.shared.connectivityMonitor {
            connectivityCancellable = monitor.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] connected in
                    self?.isConnected = connected
                }
        }

        // Pre-load languages
        loadLanguages()
    }

    // MARK: - Public Actions

    /// Send a text query (optionally with an image).
    ///
    /// State transitions: `idle` -> `sending` -> `streaming` -> `complete` (or `error`).
    func sendQuery(text: String, inputMethod: String = "text", imageData: String? = nil) {
        guard let client = apiClient else {
            chatState = .error(
                code: "sdk_not_initialized",
                message: "FarmerChat SDK is not initialized",
                retryable: false
            )
            return
        }

        // Save for retry
        lastQuery = (text: text, inputMethod: inputMethod, imageData: imageData)

        // Cancel any in-flight stream
        streamTask?.cancel()

        // Add the user message
        let userMessageId = UUID().uuidString
        let userMessage = ChatMessage(
            id: userMessageId,
            role: "user",
            text: text,
            inputMethod: inputMethod,
            imageData: imageData
        )
        appendMessage(userMessage)

        chatState = .sending

        // Emit QuerySent event
        emitEvent(.querySent(
            sessionId: sessionId,
            queryId: userMessageId,
            inputMethod: inputMethod,
            timestamp: Date()
        ))

        let request = QueryRequest(
            text: text,
            inputMethod: inputMethod,
            language: selectedLanguage,
            imageData: imageData
        )

        let assistantMessageId = UUID().uuidString
        let sendStartDate = Date()

        streamTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                var accumulatedText = ""
                var tokenCount = 0
                var followUps: [String] = []
                var sources: [Source] = []
                var imageUrl: String?
                var assistantMessageAdded = false

                for try await sseEvent in client.sendQuery(request) {
                    if Task.isCancelled { break }

                    switch sseEvent.event {
                    case "token":
                        let tokenText = self.parseTokenText(sseEvent.data)
                        accumulatedText += tokenText
                        tokenCount += 1

                        self.chatState = .streaming(
                            partialText: accumulatedText,
                            tokenCount: tokenCount
                        )

                        // Upsert the assistant message (growing as tokens arrive)
                        let assistantMessage = ChatMessage(
                            id: assistantMessageId,
                            role: "assistant",
                            text: accumulatedText,
                            followUps: followUps,
                            sources: sources,
                            imageUrl: imageUrl
                        )
                        self.upsertAssistantMessage(
                            id: assistantMessageId,
                            message: assistantMessage,
                            alreadyAdded: assistantMessageAdded
                        )
                        assistantMessageAdded = true

                    case "followup":
                        followUps = self.parseFollowUps(sseEvent.data)
                        // Update the existing assistant message with follow-ups
                        if assistantMessageAdded {
                            self.updateAssistantMessage(id: assistantMessageId) { msg in
                                var updated = msg
                                updated.followUps = followUps
                                return updated
                            }
                        }

                    case "message":
                        // Non-streaming JSON path: full response at once
                        let parsed = self.parseMessageEvent(sseEvent.data)
                        accumulatedText = parsed.text
                        followUps = parsed.followUps
                        sources = parsed.sources
                        imageUrl = parsed.imageUrl

                        let msgId = parsed.id.isEmpty ? assistantMessageId : parsed.id
                        let assistantMessage = ChatMessage(
                            id: msgId,
                            role: "assistant",
                            text: accumulatedText,
                            followUps: followUps,
                            sources: sources,
                            imageUrl: imageUrl
                        )
                        self.upsertAssistantMessage(
                            id: assistantMessageId,
                            message: assistantMessage,
                            alreadyAdded: assistantMessageAdded
                        )
                        assistantMessageAdded = true

                    case "done":
                        self.chatState = .complete

                        // Emit ResponseReceived event
                        let latencyMs = Int64(Date().timeIntervalSince(sendStartDate) * 1000)
                        self.emitEvent(.responseReceived(
                            sessionId: self.sessionId,
                            responseId: assistantMessageId,
                            latencyMs: latencyMs,
                            timestamp: Date()
                        ))

                    case "error":
                        let errorInfo = self.parseErrorEvent(sseEvent.data)
                        self.chatState = .error(
                            code: errorInfo.code,
                            message: errorInfo.message,
                            retryable: true
                        )
                        self.emitEvent(.error(
                            code: errorInfo.code,
                            message: errorInfo.message,
                            fatal: false,
                            timestamp: Date()
                        ))

                    default:
                        break
                    }
                }

                // If stream ended without an explicit "done", ensure we mark Complete
                if case .streaming = self.chatState {
                    self.chatState = .complete
                    let latencyMs = Int64(Date().timeIntervalSince(sendStartDate) * 1000)
                    self.emitEvent(.responseReceived(
                        sessionId: self.sessionId,
                        responseId: assistantMessageId,
                        latencyMs: latencyMs,
                        timestamp: Date()
                    ))
                }

            } catch {
                if Task.isCancelled { return }
                print("[\(ChatViewModel.tag)] Stream collection error: \(error)")
                // Keep any partial text visible -- move to Error state
                self.chatState = .error(
                    code: "stream_error",
                    message: error.localizedDescription,
                    retryable: true
                )
                self.emitEvent(.error(
                    code: "stream_error",
                    message: error.localizedDescription,
                    fatal: false,
                    timestamp: Date()
                ))
            }
        }
    }

    /// Send a follow-up question (user tapped a suggestion chip).
    func sendFollowUp(text: String) {
        sendQuery(text: text, inputMethod: "follow_up")
    }

    /// Cancel the active SSE stream and settle on the partial text.
    func stopStream() {
        streamTask?.cancel()
        streamTask = nil

        switch chatState {
        case .streaming, .sending:
            chatState = .complete
        default:
            break
        }
    }

    /// Replay the last failed query.
    func retryLastQuery() {
        guard let query = lastQuery else { return }
        // Reset error state before retry
        chatState = .idle
        sendQuery(text: query.text, inputMethod: query.inputMethod, imageData: query.imageData)
    }

    /// Submit feedback (thumbs up/down) for an assistant message.
    func submitFeedback(messageId: String, rating: String, comment: String? = nil) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                guard let client = self.apiClient else { return }
                try await client.submitFeedback(
                    FeedbackRequest(
                        responseId: messageId,
                        rating: rating,
                        comment: comment
                    )
                )

                // Optimistically update the local message
                self.messages = self.messages.map { msg in
                    if msg.id == messageId {
                        var updated = msg
                        updated.feedbackRating = rating
                        return updated
                    }
                    return msg
                }

                // Emit FeedbackSubmitted event
                self.emitEvent(.feedbackSubmitted(
                    sessionId: self.sessionId,
                    responseId: messageId,
                    rating: rating,
                    timestamp: Date()
                ))
            } catch {
                print("[\(ChatViewModel.tag)] submitFeedback failed: \(error)")
                self.emitEvent(.error(
                    code: "feedback_error",
                    message: error.localizedDescription,
                    fatal: false,
                    timestamp: Date()
                ))
            }
        }
    }

    /// Load conversation history from the server and replace the current message list.
    func loadHistory() {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                guard let client = self.apiClient else { return }
                let conversations = try await client.getHistory()

                // Flatten conversation messages into ChatMessages
                let historyMessages: [ChatMessage] = conversations.flatMap { conversation in
                    conversation.messages.map { msg in
                        ChatMessage(
                            id: msg.id,
                            role: msg.role,
                            text: msg.text,
                            timestamp: Date(timeIntervalSince1970: TimeInterval(msg.timestamp) / 1000),
                            imageData: msg.imageData,
                            followUps: msg.followUps
                        )
                    }
                }

                self.messages = self.trimToCapacity(historyMessages)
            } catch {
                print("[\(ChatViewModel.tag)] loadHistory failed: \(error)")
                self.emitEvent(.error(
                    code: "history_error",
                    message: error.localizedDescription,
                    fatal: false,
                    timestamp: Date()
                ))
            }
        }
    }

    /// Fetch available languages from the server.
    func loadLanguages() {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                guard let client = self.apiClient else { return }
                let languages = try await client.getLanguages()
                self.availableLanguages = languages
            } catch {
                print("[\(ChatViewModel.tag)] loadLanguages failed: \(error)")
            }
        }
    }

    /// Change the active language and reload starters for the new language.
    func setLanguage(code: String) {
        let previousLanguage = selectedLanguage
        selectedLanguage = code
        loadStarters()

        // Emit LanguageChanged event
        emitEvent(.languageChanged(
            from: previousLanguage,
            to: code,
            timestamp: Date()
        ))
    }

    /// Load starter questions for the current language.
    func loadStarters() {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                guard let client = self.apiClient else { return }
                let starters = try await client.getStarters(language: self.selectedLanguage)
                self.starterQuestions = starters
            } catch {
                print("[\(ChatViewModel.tag)] loadStarters failed: \(error)")
            }
        }
    }

    /// Submit onboarding data (location + language) and navigate to the chat screen.
    func completeOnboarding(lat: Double, lng: Double, language: String) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                guard let client = self.apiClient else { return }
                try await client.submitOnboarding(
                    location: Location(lat: lat, lng: lng),
                    language: language
                )
                self.setLanguage(code: language)
                self.currentScreen = .chat

                // Emit OnboardingCompleted event
                self.emitEvent(.onboardingCompleted(
                    sessionId: self.sessionId,
                    location: (lat: lat, lng: lng),
                    language: language,
                    timestamp: Date()
                ))
            } catch {
                print("[\(ChatViewModel.tag)] completeOnboarding failed: \(error)")
                self.emitEvent(.error(
                    code: "onboarding_error",
                    message: error.localizedDescription,
                    fatal: false,
                    timestamp: Date()
                ))
            }
        }
    }

    /// Navigate to a different screen within the SDK.
    func navigateTo(screen: Screen) {
        currentScreen = screen
    }

    // MARK: - Private Helpers

    /// Append a message and enforce the memory cap.
    private func appendMessage(_ message: ChatMessage) {
        messages = trimToCapacity(messages + [message])
    }

    /// Insert or update the assistant message in the list.
    private func upsertAssistantMessage(
        id: String,
        message: ChatMessage,
        alreadyAdded: Bool
    ) {
        if alreadyAdded {
            messages = messages.map { $0.id == id ? message : $0 }
        } else {
            messages = trimToCapacity(messages + [message])
        }
    }

    /// Apply a transformation to a specific assistant message.
    private func updateAssistantMessage(id: String, transform: (ChatMessage) -> ChatMessage) {
        messages = messages.map { $0.id == id ? transform($0) : $0 }
    }

    /// Trim a list to ``FarmerChatConfig/maxMessagesInMemory``, removing the oldest entries.
    private func trimToCapacity(_ list: [ChatMessage]) -> [ChatMessage] {
        let cap = config.maxMessagesInMemory
        if list.count > cap {
            return Array(list.suffix(cap))
        }
        return list
    }

    /// Emit a ``FarmerChatEvent`` to the host app's callback.
    private func emitEvent(_ event: FarmerChatEvent) {
        FarmerChat.shared.eventCallback?(event)
    }

    // MARK: - SSE Payload Parsing

    /// Extract the text content from a "token" SSE data payload.
    private func parseTokenText(_ data: String) -> String {
        do {
            guard let jsonData = data.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let text = json["text"] as? String else {
                return data
            }
            return text
        } catch {
            // Not valid JSON -- treat the raw string as the token text
            return data
        }
    }

    /// Parse follow-up suggestions from a "followup" SSE data payload.
    private func parseFollowUps(_ data: String) -> [String] {
        do {
            guard let jsonData = data.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let arr = json["follow_ups"] as? [String] else {
                return []
            }
            return arr.filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    /// Intermediate holder for parsed "message" event data.
    private struct ParsedMessage {
        let id: String
        let text: String
        let followUps: [String]
        let sources: [Source]
        let imageUrl: String?
    }

    /// Parse a full "message" (non-streaming JSON) event.
    private func parseMessageEvent(_ data: String) -> ParsedMessage {
        do {
            guard let jsonData = data.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return ParsedMessage(id: "", text: data, followUps: [], sources: [], imageUrl: nil)
            }

            let id = json["id"] as? String ?? ""
            let text = json["text"] as? String ?? ""

            let followUps: [String] = (json["follow_ups"] as? [String])?.filter { !$0.isEmpty } ?? []

            let sources: [Source] = (json["sources"] as? [[String: Any]])?.map { srcJson in
                Source(
                    title: srcJson["title"] as? String ?? "",
                    url: srcJson["url"] as? String
                )
            } ?? []

            let imageUrl = json["image_url"] as? String

            return ParsedMessage(
                id: id,
                text: text,
                followUps: followUps,
                sources: sources,
                imageUrl: imageUrl
            )
        } catch {
            return ParsedMessage(id: "", text: data, followUps: [], sources: [], imageUrl: nil)
        }
    }

    /// Parse an "error" SSE event and return (code, message).
    private func parseErrorEvent(_ data: String) -> (code: String, message: String) {
        do {
            guard let jsonData = data.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return (code: "unknown", message: data)
            }

            let code: String
            if let codeStr = json["code"] as? String {
                code = codeStr
            } else if let codeInt = json["code"] as? Int {
                code = String(codeInt)
            } else {
                code = "unknown"
            }

            let message = json["message"] as? String ?? "Unknown error"
            return (code: code, message: message)
        } catch {
            return (code: "unknown", message: data)
        }
    }
}
