import Foundation

// MARK: - SSE

/// A single Server-Sent Event parsed from the stream.
///
/// - `event`: Event type — "token", "followup", "done", "message", "error".
/// - `data`: Raw JSON string payload.
internal struct SseEvent {
    let event: String
    let data: String
}

// MARK: - Requests

/// Request body for sending a chat query.
internal struct QueryRequest {
    let text: String
    let inputMethod: String
    let language: String
    let imageData: String?
    let location: Location?

    init(
        text: String,
        inputMethod: String,
        language: String,
        imageData: String? = nil,
        location: Location? = nil
    ) {
        self.text = text
        self.inputMethod = inputMethod
        self.language = language
        self.imageData = imageData
        self.location = location
    }

    /// Serialize to a JSON dictionary for the request body.
    func toJsonData() throws -> Data {
        var dict: [String: Any] = [
            "text": text,
            "input_method": inputMethod,
            "language": language,
        ]
        if let imageData = imageData {
            dict["image_data"] = imageData
        }
        if let location = location {
            dict["location"] = ["lat": location.lat, "lng": location.lng]
        }
        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }
}

/// Request body for submitting feedback on a response.
internal struct FeedbackRequest {
    let responseId: String
    let rating: String
    let comment: String?

    init(responseId: String, rating: String, comment: String? = nil) {
        self.responseId = responseId
        self.rating = rating
        self.comment = comment
    }

    /// Serialize to a JSON dictionary for the request body.
    func toJsonData() throws -> Data {
        var dict: [String: Any] = [
            "response_id": responseId,
            "rating": rating,
        ]
        if let comment = comment {
            dict["comment"] = comment
        }
        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }
}

// MARK: - Responses

/// A single message within a conversation history entry.
internal struct MessageResponse {
    let id: String
    let role: String
    let text: String
    let timestamp: Int64
    let imageData: String?
    let followUps: [String]

    /// Parse from a JSON dictionary.
    static func fromJson(_ json: [String: Any]) -> MessageResponse {
        let followUpsArray = json["follow_ups"] as? [String] ?? []
        return MessageResponse(
            id: json["id"] as? String ?? "",
            role: json["role"] as? String ?? "",
            text: json["text"] as? String ?? "",
            timestamp: (json["timestamp"] as? NSNumber)?.int64Value ?? 0,
            imageData: json["image_data"] as? String,
            followUps: followUpsArray
        )
    }
}

/// A conversation returned from the history endpoint.
internal struct ConversationResponse {
    let id: String
    let title: String
    let messages: [MessageResponse]
    let createdAt: Int64
    let updatedAt: Int64

    /// Parse from a JSON dictionary.
    static func fromJson(_ json: [String: Any]) -> ConversationResponse {
        let messagesArray = json["messages"] as? [[String: Any]] ?? []
        let messages = messagesArray.map { MessageResponse.fromJson($0) }
        return ConversationResponse(
            id: json["id"] as? String ?? "",
            title: json["title"] as? String ?? "",
            messages: messages,
            createdAt: (json["created_at"] as? NSNumber)?.int64Value ?? 0,
            updatedAt: (json["updated_at"] as? NSNumber)?.int64Value ?? 0
        )
    }
}

/// A language option returned from the languages endpoint.
internal struct LanguageResponse {
    let code: String
    let name: String
    let nativeName: String

    /// Parse from a JSON dictionary.
    static func fromJson(_ json: [String: Any]) -> LanguageResponse {
        LanguageResponse(
            code: json["code"] as? String ?? "",
            name: json["name"] as? String ?? "",
            nativeName: json["native_name"] as? String ?? ""
        )
    }
}

/// A starter question returned from the starters endpoint.
internal struct StarterQuestionResponse {
    let text: String
    let category: String?

    /// Parse from a JSON dictionary.
    static func fromJson(_ json: [String: Any]) -> StarterQuestionResponse {
        StarterQuestionResponse(
            text: json["text"] as? String ?? "",
            category: json["category"] as? String
        )
    }
}

/// Geographic coordinates.
internal struct Location {
    let lat: Double
    let lng: Double
}

// MARK: - API Error

/// Error representing an HTTP error from the FarmerChat API.
///
/// - `statusCode`: HTTP status code.
/// - `errorBody`: Raw error response body from the server.
internal struct ApiError: Error, LocalizedError {
    let statusCode: Int
    let errorBody: String

    var errorDescription: String? {
        "HTTP \(statusCode): \(errorBody)"
    }
}
