import Foundation
import os

/// HTTP client for the FarmerChat mobile API.
/// Matches the SwiftUI SDK's ApiClient — same endpoints, auth headers, and token-refresh logic.
internal final class ApiClient {

    private static let logger = Logger(
        subsystem: "org.digitalgreen.farmerchat",
        category: "UIKit.ApiClient"
    )

    private enum Endpoint {
        static let newConversation    = "api/chat/new_conversation/"
        static let textPrompt         = "api/chat/get_answer_for_text_query/"
        static let imageAnalysis      = "api/chat/image_analysis/"
        static let followUpQuestions  = "api/chat/follow_up_questions/"
        static let followUpClick      = "api/chat/follow_up_question_click/"
        static let synthesiseAudio    = "api/chat/synthesise_audio/"
        static let transcribeAudio    = "api/chat/transcribe_audio/"
        static let chatHistory        = "api/chat/conversation_chat_history/"
        static let conversationList   = "api/chat/conversation_list/"
        static let supportedLanguages = "api/language/v2/country_wise_supported_languages/"
    }

    private let baseURL: URL
    private let sdkApiKey: String
    private let deviceInfo: String
    private let timeoutInterval: TimeInterval
    private let refreshHandler: TokenRefreshHandler

    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; return e
    }()

    init(baseUrl: String, sdkApiKey: String, deviceInfo: String, timeoutMs: Int = 15_000) {
        let trimmed = baseUrl.trimmingCharacters(in: .init(charactersIn: "/"))
        self.baseURL         = URL(string: trimmed)!
        self.sdkApiKey       = sdkApiKey
        self.deviceInfo      = deviceInfo
        self.timeoutInterval = TimeInterval(timeoutMs) / 1_000.0
        self.refreshHandler  = TokenRefreshHandler(baseUrl: trimmed, sdkApiKey: sdkApiKey)
    }

    // MARK: - Auth headers

    private func applyAuthHeaders(_ req: inout URLRequest, accessToken: String) {
        req.setValue("application/json",       forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(accessToken)",  forHTTPHeaderField: "Authorization")
        req.setValue(sdkApiKey,                forHTTPHeaderField: "X-SDK-Key")
        req.setValue("v2",                     forHTTPHeaderField: "Build-Version")
        req.setValue(deviceInfo,               forHTTPHeaderField: "Device-Info")
    }

    // MARK: - Generic helpers

    private func postJSON<Req: Encodable, Res: Decodable>(
        path: String, body: Req, responseType: Res.Type, retried: Bool = false
    ) async throws -> Res {
        let url = baseURL.appendingPathComponent(path)
        Self.logger.debug("→ POST \(url.absoluteString)")
        let token = await TokenStore.shared.accessToken

        var req = URLRequest(url: url, timeoutInterval: timeoutInterval)
        req.httpMethod = "POST"
        applyAuthHeaders(&req, accessToken: token)
        req.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response")
        }
        if http.statusCode == 401 && !retried {
            let newToken = try await refreshHandler.refreshToken()
            var retry = req; retry.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            retry.httpBody = try encoder.encode(body)
            let (rd, rr) = try await URLSession.shared.data(for: retry)
            guard let rhttp = rr as? HTTPURLResponse, (200...299).contains(rhttp.statusCode) else {
                throw NetworkError.unauthorized
            }
            return try decoder.decode(Res.self, from: rd)
        }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.serverError(http.statusCode, String(data: data, encoding: .utf8))
        }
        if let raw = String(data: data, encoding: .utf8) {
            Self.logger.debug("← POST \(url.lastPathComponent) raw: \(raw)")
        }
        return try decoder.decode(Res.self, from: data)
    }

    private func getJSON<Res: Decodable>(
        path: String, params: [String: String] = [:], responseType: Res.Type, retried: Bool = false
    ) async throws -> Res {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !params.isEmpty { comps?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = comps?.url else { throw NetworkError.invalidURL }
        Self.logger.debug("→ GET \(url.absoluteString)")

        let token = await TokenStore.shared.accessToken
        var req = URLRequest(url: url, timeoutInterval: timeoutInterval)
        req.httpMethod = "GET"
        applyAuthHeaders(&req, accessToken: token)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.unknown("Invalid response") }
        if http.statusCode == 401 && !retried {
            let newToken = try await refreshHandler.refreshToken()
            var retry = req; retry.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            let (rd, rr) = try await URLSession.shared.data(for: retry)
            guard let rhttp = rr as? HTTPURLResponse, (200...299).contains(rhttp.statusCode) else {
                throw NetworkError.unauthorized
            }
            return try decoder.decode(Res.self, from: rd)
        }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.serverError(http.statusCode, String(data: data, encoding: .utf8))
        }
        return try decoder.decode(Res.self, from: data)
    }

    // MARK: - Conversation

    struct NewConversationBody: Encodable {
        let userId: String
        let contentProviderId: String?
    }

    func createNewConversation(userId: String, contentProviderId: String? = nil) async throws -> NewConversationResponse {
        try await postJSON(path: Endpoint.newConversation,
                           body: NewConversationBody(userId: userId, contentProviderId: contentProviderId),
                           responseType: NewConversationResponse.self)
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
        query: String, conversationId: String, messageId: String,
        triggeredInputType: String = "text", transcriptionId: String? = nil,
        weatherCtaTriggered: Bool = false, retry: Bool = false
    ) async throws -> TextPromptResponse {
        try await postJSON(
            path: Endpoint.textPrompt,
            body: TextPromptBody(
                query: query, conversationId: conversationId, messageId: messageId,
                triggeredInputType: triggeredInputType, transcriptionId: transcriptionId,
                useEntityExtraction: true, weatherCtaTriggered: weatherCtaTriggered, retry: retry
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
        conversationId: String, base64Image: String, imageName: String,
        latitude: String? = nil, longitude: String? = nil, query: String? = nil
    ) async throws -> ImageAnalysisResponse {
        try await postJSON(
            path: Endpoint.imageAnalysis,
            body: ImageAnalysisBody(
                conversationId: conversationId, image: base64Image,
                triggeredInputType: "image", query: query,
                latitude: latitude, longitude: longitude, imageName: imageName, retry: false
            ),
            responseType: ImageAnalysisResponse.self
        )
    }

    // MARK: - Follow-up

    func fetchFollowUpQuestions(messageId: String) async throws -> FollowUpQuestionsResponse {
        try await getJSON(
            path: Endpoint.followUpQuestions,
            params: ["message_id": messageId, "use_latest_prompt": "true"],
            responseType: FollowUpQuestionsResponse.self
        )
    }

    struct FollowUpClickBody: Encodable { let followUpQuestion: String }
    func trackFollowUpClick(question: String) async throws {
        struct Empty: Decodable {}
        _ = try? await postJSON(path: Endpoint.followUpClick,
                                body: FollowUpClickBody(followUpQuestion: question),
                                responseType: Empty.self)
    }

    // MARK: - TTS

    struct SynthesiseBody: Encodable { let messageId: String; let text: String; let userId: String }
    func synthesiseAudio(messageId: String, text: String, userId: String) async throws -> SynthesiseAudioResponse {
        try await postJSON(path: Endpoint.synthesiseAudio,
                           body: SynthesiseBody(messageId: messageId, text: text, userId: userId),
                           responseType: SynthesiseAudioResponse.self)
    }

    // MARK: - STT (multipart/form-data)

    func transcribeAudio(_ request: TranscribeAudioRequest) async throws -> TranscribeAudioResponse {
        guard let url = URL(string: "\(baseURL)/\(Endpoint.transcribeAudio)") else {
            throw NetworkError.invalidURL
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url, timeoutInterval: timeoutInterval)
        req.httpMethod = "POST"
        let token = await TokenStore.shared.accessToken
        req.setValue("Bearer \(token)",                              forHTTPHeaderField: "Authorization")
        req.setValue(sdkApiKey,                                      forHTTPHeaderField: "X-SDK-Key")
        req.setValue("v2",                                           forHTTPHeaderField: "Build-Version")
        req.setValue(deviceInfo,                                     forHTTPHeaderField: "Device-Info")
        req.setValue("multipart/form-data; boundary=\(boundary)",    forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { if let d = s.data(using: .utf8) { body.append(d) } }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"recording.m4a\"\r\n")
        append("Content-Type: audio/m4a\r\n\r\n")
        body.append(request.audioData)
        append("\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n")
        append(request.userId)
        append("\r\n")
        if let convId = request.conversationId {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"conversation_id\"\r\n\r\n")
            append(convId); append("\r\n")
        }
        if let lang = request.language {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            append(lang); append("\r\n")
        }
        append("--\(boundary)--\r\n")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NetworkError.serverError(0, String(data: data, encoding: .utf8))
        }
        return try decoder.decode(TranscribeAudioResponse.self, from: data)
    }

    // MARK: - History

    func fetchConversationList(userId: String, page: Int = 1) async throws -> [ConversationListItem] {
        let qs = "user_id=\(userId)&page=\(page)"
        guard let url = URL(string: "\(baseURL)/\(Endpoint.conversationList)?\(qs)") else {
            throw NetworkError.invalidURL
        }
        let token = await TokenStore.shared.accessToken
        var req = URLRequest(url: url, timeoutInterval: timeoutInterval)
        req.httpMethod = "GET"
        applyAuthHeaders(&req, accessToken: token)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
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

    // MARK: - Languages

    func getSupportedLanguages(countryCode: String? = nil) async throws -> [SupportedLanguageGroup] {
        var params: [String: String] = [:]
        if let cc = countryCode { params["country_code"] = cc }
        return try await getJSON(path: Endpoint.supportedLanguages, params: params,
                                 responseType: [SupportedLanguageGroup].self)
    }
}
