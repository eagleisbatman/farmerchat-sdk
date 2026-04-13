import Foundation

// MARK: - Network errors

enum NetworkError: Error, LocalizedError {
    case unauthorized
    case serverError(Int, String?)
    case networkUnavailable
    case decodingError(String)
    case invalidURL
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:                return "Unauthorized — token refresh failed"
        case .serverError(let c, let m):   return "Server error \(c): \(m ?? "")"
        case .networkUnavailable:          return "No internet connection"
        case .decodingError(let s):        return "Decoding error: \(s)"
        case .invalidURL:                  return "Invalid URL"
        case .unknown(let s):              return s
        }
    }
}

// MARK: - Auth / Guest

struct InitializeGuestUserResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let userId: String?
    let createdNow: Bool?
    let countryCode: String?
    let country: String?
    let state: String?
}

struct TokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
}

// MARK: - Conversation

struct NewConversationResponse: Decodable {
    let conversationId: String
    let message: String
    let showPopup: Bool
}

// MARK: - Follow-up

struct FollowUpQuestionOption: Decodable, Equatable {
    let followUpQuestionId: String?
    let question: String?
    let sequence: Int?
}

// MARK: - Text prompt

struct TextPromptResponse: Decodable {
    let error: Bool
    let message: String?
    let messageId: String?
    let response: String?
    let translatedResponse: String?
    let followUpQuestions: [FollowUpQuestionOption]?
    let sectionMessageId: String?
    let contentProviderLogo: String?
    let hideFollowUpQuestion: Bool?
    let hideTtsSpeaker: Bool?
    let points: Int?
}

// MARK: - Image analysis

struct ImageAnalysisResponse: Decodable {
    let error: Bool
    let message: String
    let messageId: String
    let response: String
    let followUpQuestions: [FollowUpQuestionOption]?
}

// MARK: - Follow-up questions

struct FollowUpQuestionsResponse: Decodable {
    let messageId: String
    let sectionMessageId: String
    let questions: [FollowUpQuestion]?
}

struct FollowUpQuestion: Decodable {
    let followUpQuestionId: String
    let question: String
    let sequence: Int
}

// MARK: - TTS / STT

struct SynthesiseAudioResponse: Decodable {
    let audioUrl: String?
    let messageId: String?
    let status: String?
}

struct TranscribeAudioRequest {
    let audioData: Data
    let userId: String
    let conversationId: String?
    let language: String?

    init(audioData: Data, userId: String, conversationId: String? = nil, language: String? = nil) {
        self.audioData = audioData
        self.userId = userId
        self.conversationId = conversationId
        self.language = language
    }
}

struct TranscribeAudioResponse: Decodable {
    let message: String?
    let heardInputQuery: String?
    let confidenceScore: Double?
    let error: Bool
    let messageId: String
    let transcriptionId: String?
}

// MARK: - Language

struct SupportedLanguage: Decodable, Equatable {
    let id: Int
    let name: String
    let code: String
    /// Native/display name. May be absent in API response; falls back to `name`.
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id, name, code
        case displayName = "display_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(Int.self,    forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        code        = try c.decode(String.self, forKey: .code)
        // display_name is optional in the API response; fall back to name
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
    }
}

struct SupportedLanguageGroup: Decodable {
    let displayName: String?
    let flag: String?
    let languages: [SupportedLanguage]

    enum CodingKeys: String, CodingKey {
        case displayName = "displayName"
        case flag        = "flag"
        case languages
    }
}

// MARK: - History / Conversation list

struct ConversationListItem: Decodable {
    var id: String { conversationId ?? UUID().uuidString }
    let conversationId: String?
    let conversationTitle: String?
    let createdOn: String?
    let messageType: String?
    let grouping: String?
    let contentProviderLogo: String?
}

struct HistoryFollowUpQuestion: Decodable {
    let followUpQuestionId: String
    let question: String
    let sequence: Int
}

struct ChatHistoryItem: Decodable {
    let messageTypeId: Int
    let messageType: String
    let messageId: String
    let queryText: String?
    let heardQueryText: String?
    let responseText: String?
    let questions: [HistoryFollowUpQuestion]?
    let queryMediaFileUrl: String?
    let contentProviderLogo: String?
    let hideTtsSpeaker: Bool?
    let messageInputTime: String?
}

struct ConversationChatHistoryResponse: Decodable {
    let conversationId: String
    let data: [ChatHistoryItem]
}

// MARK: - SSE

/// A single Server-Sent Event parsed from the stream.
struct SseEvent {
    let event: String
    let data: String
}

// MARK: - API Error (legacy, kept for old code compatibility)

struct ApiError: Error, LocalizedError {
    let statusCode: Int
    let errorBody: String

    var errorDescription: String? { "HTTP \(statusCode): \(errorBody)" }
}

// MARK: - Geographic coordinates

struct Location {
    let lat: Double
    let lng: Double
}
