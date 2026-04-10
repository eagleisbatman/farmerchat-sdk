import Foundation
import os

/// HTTP client using `URLSession` (no Alamofire).
///
/// Handles:
/// - Auth headers on every request (Authorization: Bearer, X-SDK-Key, Build-Version, Device-Info)
/// - Automatic token refresh on HTTP 401 via `TokenRefreshHandler`
/// - All FarmerChat REST API endpoints
///
/// Every public method is wrapped in do-catch so network failures never propagate
/// unchecked exceptions to the host app.
internal final class ApiClient {

    // MARK: - Constants

    private static let logger = Logger(subsystem: "org.digitalgreen.farmerchat", category: "ApiClient")

    private enum Endpoint {
        static let newConversation     = "api/chat/new_conversation/"
        static let textPrompt          = "api/chat/get_answer_for_text_query/"
        static let imageAnalysis       = "api/chat/image_analysis/"
        static let followUpQuestions   = "api/chat/follow_up_questions/"
        static let followUpClick       = "api/chat/follow_up_question_click/"
        static let synthesiseAudio     = "api/chat/synthesise_audio/"
        static let transcribeAudio     = "api/chat/transcribe_audio/"
        static let chatHistory         = "api/chat/conversation_chat_history/"
        static let conversationList    = "api/chat/conversation_list/"
    }

    // MARK: - Properties

    private let baseURL: URL
    private let sdkApiKey: String
    private let deviceInfo: String
    private let timeoutInterval: TimeInterval
    private let session: URLSession
    private let refreshHandler: TokenRefreshHandler

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // MARK: - Init

    init(
        baseUrl: String,
        sdkApiKey: String,
        deviceInfo: String,
        timeoutMs: Int = 15_000
    ) {
        let trimmed = baseUrl.trimmingCharacters(in: .init(charactersIn: "/"))
        self.baseURL = URL(string: trimmed)!
        self.sdkApiKey = sdkApiKey
        self.deviceInfo = deviceInfo
        self.timeoutInterval = TimeInterval(timeoutMs) / 1_000.0
        self.session = URLSession.shared
        self.refreshHandler = TokenRefreshHandler(baseUrl: trimmed, sdkApiKey: sdkApiKey)
    }

    // MARK: - Auth headers

    private func applyAuthHeaders(_ request: inout URLRequest, accessToken: String) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(sdkApiKey, forHTTPHeaderField: "X-SDK-Key")
        request.setValue("v2", forHTTPHeaderField: "Build-Version")
        request.setValue(deviceInfo, forHTTPHeaderField: "Device-Info")
    }

    // MARK: - Generic helpers

    /// POST JSON body; handles 401 by refreshing once and retrying.
    private func postJSON<Req: Encodable, Res: Decodable>(
        path: String,
        body: Req,
        responseType: Res.Type,
        retry: Bool = false
    ) async throws -> Res {
        let url = baseURL.appendingPathComponent(path)
        let accessToken = await TokenStore.shared.accessToken

        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "POST"
        applyAuthHeaders(&request, accessToken: accessToken)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response type")
        }

        if http.statusCode == 401 && !retry {
            let newToken = try await refreshHandler.refreshToken()
            var retryReq = request
            retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            retryReq.httpBody = try encoder.encode(body)
            let (retryData, retryResp) = try await session.data(for: retryReq)
            guard let retryHttp = retryResp as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode) else {
                throw NetworkError.unauthorized
            }
            return try decoder.decode(Res.self, from: retryData)
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw NetworkError.serverError(http.statusCode, body)
        }
        return try decoder.decode(Res.self, from: data)
    }

    /// GET with query parameters; handles 401 refresh once.
    private func getJSON<Res: Decodable>(
        path: String,
        params: [String: String] = [:],
        responseType: Res.Type,
        retry: Bool = false
    ) async throws -> Res {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !params.isEmpty {
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw NetworkError.invalidURL }

        let accessToken = await TokenStore.shared.accessToken
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "GET"
        applyAuthHeaders(&request, accessToken: accessToken)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response type")
        }

        if http.statusCode == 401 && !retry {
            let newToken = try await refreshHandler.refreshToken()
            var retryReq = request
            retryReq.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResp) = try await session.data(for: retryReq)
            guard let retryHttp = retryResp as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode) else {
                throw NetworkError.unauthorized
            }
            return try decoder.decode(Res.self, from: retryData)
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw NetworkError.serverError(http.statusCode, body)
        }
        return try decoder.decode(Res.self, from: data)
    }

    // MARK: - Conversation

    struct NewConversationBody: Encodable {
        let userId: String
        let contentProviderId: String?
    }

    func createNewConversation(userId: String, contentProviderId: String?) async throws -> NewConversationResponse {
        try await postJSON(
            path: Endpoint.newConversation,
            body: NewConversationBody(userId: userId, contentProviderId: contentProviderId),
            responseType: NewConversationResponse.self
        )
    }

    // MARK: - Text prompt

    struct TextPromptBody: Encodable {
        let query: String
        let conversationId: String
        let messageId: String
        let triggeredInputType: String
        let transcriptionId: String?
        let useEntityExtraction: Bool
        let weatherCtaTriggered: Bool
        let retry: Bool
    }

    func sendTextPrompt(
        query: String,
        conversationId: String,
        messageId: String,
        triggeredInputType: String = "text",
        transcriptionId: String? = nil,
        useEntityExtraction: Bool = true,
        weatherCtaTriggered: Bool = false,
        retry: Bool = false
    ) async throws -> TextPromptResponse {
        try await postJSON(
            path: Endpoint.textPrompt,
            body: TextPromptBody(
                query: query,
                conversationId: conversationId,
                messageId: messageId,
                triggeredInputType: triggeredInputType,
                transcriptionId: transcriptionId,
                useEntityExtraction: useEntityExtraction,
                weatherCtaTriggered: weatherCtaTriggered,
                retry: retry
            ),
            responseType: TextPromptResponse.self
        )
    }

    // MARK: - Image analysis

    struct ImageAnalysisBody: Encodable {
        let conversationId: String
        let image: String
        let triggeredInputType: String
        let query: String?
        let latitude: String?
        let longitude: String?
        let imageName: String
        let retry: Bool
    }

    func sendImageAnalysis(
        conversationId: String,
        base64Image: String,
        imageName: String,
        latitude: String? = nil,
        longitude: String? = nil,
        query: String? = nil,
        retry: Bool = false
    ) async throws -> ImageAnalysisResponse {
        try await postJSON(
            path: Endpoint.imageAnalysis,
            body: ImageAnalysisBody(
                conversationId: conversationId,
                image: base64Image,
                triggeredInputType: "image",
                query: query,
                latitude: latitude,
                longitude: longitude,
                imageName: imageName,
                retry: retry
            ),
            responseType: ImageAnalysisResponse.self
        )
    }

    // MARK: - Follow-up questions

    func fetchFollowUpQuestions(messageId: String, useLatestPrompt: Bool = true) async throws -> FollowUpQuestionsResponse {
        try await getJSON(
            path: Endpoint.followUpQuestions,
            params: ["message_id": messageId, "use_latest_prompt": useLatestPrompt ? "true" : "false"],
            responseType: FollowUpQuestionsResponse.self
        )
    }

    // MARK: - Track follow-up click

    struct FollowUpClickBody: Encodable { let followUpQuestion: String }

    func trackFollowUpClick(followUpQuestion: String) async throws {
        struct Empty: Decodable {}
        _ = try? await postJSON(path: Endpoint.followUpClick, body: FollowUpClickBody(followUpQuestion: followUpQuestion), responseType: Empty.self)
    }

    // MARK: - TTS

    struct SynthesiseBody: Encodable {
        let messageId: String
        let text: String
        let userId: String
    }

    func synthesiseAudio(messageId: String, text: String, userId: String) async throws -> SynthesiseAudioResponse {
        try await postJSON(
            path: Endpoint.synthesiseAudio,
            body: SynthesiseBody(messageId: messageId, text: text, userId: userId),
            responseType: SynthesiseAudioResponse.self
        )
    }

    // MARK: - STT (multipart/form-data)

    func transcribeAudio(_ request: TranscribeAudioRequest) async throws -> TranscribeAudioResponse {
        guard let url = URL(string: "\(baseURL)/\(Endpoint.transcribeAudio)") else {
            throw NetworkError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url, timeoutInterval: timeoutInterval)
        req.httpMethod = "POST"

        let accessToken = await TokenStore.shared.accessToken
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(sdkApiKey, forHTTPHeaderField: "X-SDK-Key")
        req.setValue("v2", forHTTPHeaderField: "Build-Version")
        req.setValue(deviceInfo, forHTTPHeaderField: "Device-Info")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ string: String) { if let d = string.data(using: .utf8) { body.append(d) } }

        // audio_file
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"recording.m4a\"\r\n")
        append("Content-Type: audio/m4a\r\n\r\n")
        body.append(request.audioData)
        append("\r\n")

        // user_id
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n")
        append(request.userId)
        append("\r\n")

        if let conversationId = request.conversationId {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"conversation_id\"\r\n\r\n")
            append(conversationId)
            append("\r\n")
        }

        if let language = request.language {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            append(language)
            append("\r\n")
        }

        append("--\(boundary)--\r\n")
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.unknown("Invalid response") }

        if http.statusCode == 401 {
            _ = try await refreshHandler.refreshToken()
            throw NetworkError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.serverError(http.statusCode, String(data: data, encoding: .utf8))
        }
        return try decoder.decode(TranscribeAudioResponse.self, from: data)
    }

    // MARK: - History

    func fetchConversationList(userId: String, page: Int = 1) async throws -> [ConversationListItem] {
        let params = ["user_id": userId, "page": String(page)]
        let url = URL(string: "\(baseURL)/\(Endpoint.conversationList)?\(params.map { "\($0.key)=\($0.value)" }.joined(separator: "&"))")!
        let accessToken = await TokenStore.shared.accessToken
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "GET"
        applyAuthHeaders(&request, accessToken: accessToken)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NetworkError.serverError(0, nil)
        }
        return try decoder.decode([ConversationListItem].self, from: data)
    }

    func fetchChatHistory(conversationId: String, page: Int = 1) async throws -> ConversationChatHistoryResponse {
        try await getJSON(
            path: Endpoint.chatHistory,
            params: ["conversation_id": conversationId, "page": String(page)],
            responseType: ConversationChatHistoryResponse.self
        )
    }
}
