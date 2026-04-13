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
        case .unauthorized:             return "Unauthorized — token refresh failed"
        case .serverError(let c, let m): return "Server error \(c): \(m ?? "")"
        case .networkUnavailable:       return "No internet connection"
        case .decodingError(let s):     return "Decoding error: \(s)"
        case .invalidURL:               return "Invalid URL"
        case .unknown(let s):           return s
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

struct FollowUpQuestionOption: Decodable {
    let followUpQuestionId: String?
    let question: String?
    let sequence: Int?
}

// MARK: - Intent classification

struct IntentClassificationOutput: Decodable {
    let intent: String?
    let confidence: String?
    let assetType: String?
    let assetName: String?
    let assetStatus: String?
    let concern: String?
    let stage: String?
    let likelyActivity: String?
    let rephrasedQuery: String?
    let seasonalRelevance: String?
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
    let intentClassificationOutput: IntentClassificationOutput?
}

// MARK: - Image analysis

struct ImageAnalysisResponse: Decodable {
    let error: Bool
    let message: String
    let messageId: String
    let response: String
    let followUpQuestions: [FollowUpQuestionOption]?
    let contentProviderLogo: String?
    let hideTtsSpeaker: Bool?
    let points: Int?
}

// MARK: - Follow-up questions response

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

// MARK: - TTS

public struct SynthesiseAudioResponse: Decodable {
    public let audioUrl: String?
    public let messageId: String?
    public let status: String?
}

// MARK: - STT (multipart/form-data)

public struct TranscribeAudioRequest {
    public let audioData: Data
    public let userId: String
    public let conversationId: String?
    public let language: String?

    public init(audioData: Data, userId: String, conversationId: String? = nil, language: String? = nil) {
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

public struct SupportedLanguage: Decodable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let code: String
    public let displayName: String

    enum CodingKeys: String, CodingKey {
        case id, name, code
        case displayName = "display_name"
    }

    public static func == (lhs: SupportedLanguage, rhs: SupportedLanguage) -> Bool {
        lhs.id == rhs.id
    }
}

public struct SupportedLanguageGroup: Decodable {
    public let displayName: String?
    public let flag: String?
    public let languages: [SupportedLanguage]

    enum CodingKeys: String, CodingKey {
        case displayName = "displayName"
        case flag = "flag"
        case languages
    }
}

// MARK: - History

public struct ConversationListItem: Decodable, Identifiable {
    public var id: String { conversationId ?? UUID().uuidString }
    public let conversationId: String?
    public let conversationTitle: String?
    public let createdOn: String?
    public let messageType: String?
    public let grouping: String?
    public let contentProviderLogo: String?
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

/// A single Server-Sent Event, parsed by SSEParser.
struct SseEvent {
    let event: String
    let data: String
}
