import Foundation
import os

/// HTTP client using `URLSession` (no Alamofire).
///
/// All network calls use Swift structured concurrency (`async`/`await`).
/// JSON is parsed with `JSONSerialization` — no Codable overhead for partial/streaming data.
///
/// Every public method is wrapped in do-catch so that a network failure never propagates
/// an unchecked exception to the host app.
internal final class ApiClient {

    // MARK: - Constants

    private static let sdkVersion = "0.0.0"
    private static let logger = Logger(
        subsystem: "org.digitalgreen.farmerchat",
        category: "ApiClient"
    )

    // API endpoint paths (mirrors core/src/api/endpoints.ts)
    private enum Endpoint {
        static let chatSend    = "/v1/chat/send"
        static let feedback    = "/v1/chat/feedback"
        static let history     = "/v1/chat/history"
        static let languages   = "/v1/config/languages"
        static let starters    = "/v1/config/starters"
        static let tts         = "/v1/chat/tts"
        static let onboarding  = "/v1/user/onboarding"
    }

    // MARK: - Properties

    private let baseURL: URL
    private let apiKey: String
    private let requestTimeoutMs: Int
    private let sseTimeoutMs: Int
    private let session: URLSession

    // MARK: - Init

    /// Create an API client.
    ///
    /// - Parameters:
    ///   - baseURL: API base URL.
    ///   - apiKey: Partner API key for authentication.
    ///   - requestTimeoutMs: Timeout for standard HTTP requests in milliseconds.
    ///   - sseTimeoutMs: Timeout for SSE streaming connections in milliseconds.
    init(
        baseURL: URL,
        apiKey: String,
        requestTimeoutMs: Int = 15_000,
        sseTimeoutMs: Int = 30_000
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.requestTimeoutMs = requestTimeoutMs
        self.sseTimeoutMs = sseTimeoutMs

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(requestTimeoutMs) / 1_000.0
        config.timeoutIntervalForResource = TimeInterval(sseTimeoutMs) / 1_000.0
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
            "X-SDK-Version": Self.sdkVersion,
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Default Headers

    /// Headers applied to every request.
    private func defaultHeaders() -> [String: String] {
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
            "X-SDK-Version": Self.sdkVersion,
        ]
    }

    // MARK: - Generic HTTP Helpers

    /// Execute a POST request and return the parsed JSON dictionary.
    private func postJSON(endpoint: String, body: Data) async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(requestTimeoutMs) / 1_000.0
        request.httpBody = body
        applyHeaders(&request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError(statusCode: 0, errorBody: "Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw ApiError(statusCode: httpResponse.statusCode, errorBody: errorBody)
        }

        if data.isEmpty {
            return [:]
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    /// Execute a GET request and return the raw response body as a `String`.
    private func getString(endpoint: String, params: [String: String] = [:]) async throws -> String {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        )
        if !params.isEmpty {
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components?.url else {
            throw ApiError(statusCode: 0, errorBody: "Invalid URL for endpoint: \(endpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = TimeInterval(requestTimeoutMs) / 1_000.0
        applyHeaders(&request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError(statusCode: 0, errorBody: "Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw ApiError(statusCode: httpResponse.statusCode, errorBody: errorBody)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Execute a POST request and return the raw response bytes (for binary payloads like audio).
    private func postBytes(endpoint: String, body: Data) async throws -> Data {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(requestTimeoutMs) / 1_000.0
        request.httpBody = body
        applyHeaders(&request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError(statusCode: 0, errorBody: "Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw ApiError(statusCode: httpResponse.statusCode, errorBody: errorBody)
        }

        return data
    }

    // MARK: - Public API Methods

    /// Send a query and return an `AsyncThrowingStream` of `SseEvent`.
    ///
    /// Inspects the response `Content-Type`:
    /// - `text/event-stream` — parses as SSE line-by-line using `URLSession.bytes(for:)`.
    /// - `application/json` — emits a single "message" event followed by "done".
    func sendQuery(_ query: QueryRequest) -> AsyncThrowingStream<SseEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = baseURL.appendingPathComponent(Endpoint.chatSend)
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = TimeInterval(sseTimeoutMs) / 1_000.0
                    request.httpBody = try query.toJsonData()
                    applyHeaders(&request)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.yield(SseEvent(
                            event: "error",
                            data: "{\"code\":0,\"message\":\"Invalid response type\"}"
                        ))
                        continuation.finish()
                        return
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        // Collect the error body from the byte stream.
                        var errorBytes = Data()
                        for try await byte in bytes {
                            errorBytes.append(byte)
                        }
                        let errorBody = String(data: errorBytes, encoding: .utf8) ?? ""
                        continuation.yield(SseEvent(
                            event: "error",
                            data: Self.buildErrorJson(code: httpResponse.statusCode, message: errorBody)
                        ))
                        continuation.finish()
                        return
                    }

                    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""

                    if contentType.contains("text/event-stream") {
                        // SSE streaming path
                        let parser = SSEParser()
                        var receivedDone = false

                        for try await line in bytes.lines {
                            if Task.isCancelled { break }

                            if let event = parser.feed(line: line) {
                                continuation.yield(event)
                                if event.event == "done" {
                                    receivedDone = true
                                }
                            }
                        }

                        // Flush any trailing event without a final blank line.
                        if let trailingEvent = parser.flush() {
                            continuation.yield(trailingEvent)
                            if trailingEvent.event == "done" {
                                receivedDone = true
                            }
                        }

                        // Emit synthetic done if the stream ended without one.
                        if !receivedDone {
                            continuation.yield(SseEvent(event: "done", data: "{}"))
                        }

                    } else if contentType.contains("application/json") {
                        // Non-streaming JSON path
                        var allBytes = Data()
                        for try await byte in bytes {
                            allBytes.append(byte)
                            if Task.isCancelled { break }
                        }
                        let responseText = String(data: allBytes, encoding: .utf8) ?? "{}"
                        continuation.yield(SseEvent(event: "message", data: responseText))
                        continuation.yield(SseEvent(event: "done", data: "{}"))

                    } else {
                        continuation.yield(SseEvent(
                            event: "error",
                            data: Self.buildErrorJson(code: 0, message: "Unexpected Content-Type: \(contentType)")
                        ))
                    }

                    continuation.finish()

                } catch {
                    if Task.isCancelled {
                        continuation.finish()
                    } else {
                        Self.logger.warning("Error in sendQuery stream: \(error.localizedDescription)")
                        continuation.yield(SseEvent(
                            event: "error",
                            data: Self.buildErrorJson(code: 0, message: error.localizedDescription)
                        ))
                        continuation.finish()
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Submit feedback (thumbs up/down) for a response.
    func submitFeedback(_ feedback: FeedbackRequest) async throws {
        do {
            let body = try feedback.toJsonData()
            _ = try await postJSON(endpoint: Endpoint.feedback, body: body)
        } catch {
            Self.logger.warning("Failed to submit feedback: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch conversation history from the server.
    func getHistory() async throws -> [ConversationResponse] {
        do {
            let text = try await getString(endpoint: Endpoint.history)
            guard let data = text.data(using: .utf8),
                  let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return array.map { ConversationResponse.fromJson($0) }
        } catch {
            Self.logger.warning("Failed to get history: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch available languages from the server.
    func getLanguages() async throws -> [LanguageResponse] {
        do {
            let text = try await getString(endpoint: Endpoint.languages)
            guard let data = text.data(using: .utf8),
                  let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return array.map { LanguageResponse.fromJson($0) }
        } catch {
            Self.logger.warning("Failed to get languages: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch starter questions for the empty chat state.
    func getStarters(language: String) async throws -> [StarterQuestionResponse] {
        do {
            let text = try await getString(endpoint: Endpoint.starters, params: ["lang": language])
            guard let data = text.data(using: .utf8),
                  let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return array.map { StarterQuestionResponse.fromJson($0) }
        } catch {
            Self.logger.warning("Failed to get starters: \(error.localizedDescription)")
            throw error
        }
    }

    /// Submit onboarding data — user-selected location and language.
    func submitOnboarding(location: Location, language: String) async throws {
        do {
            let dict: [String: Any] = [
                "location": ["lat": location.lat, "lng": location.lng],
                "language": language,
            ]
            let body = try JSONSerialization.data(withJSONObject: dict, options: [])
            _ = try await postJSON(endpoint: Endpoint.onboarding, body: body)
        } catch {
            Self.logger.warning("Failed to submit onboarding: \(error.localizedDescription)")
            throw error
        }
    }

    /// Convert text to speech. Returns raw audio bytes.
    func textToSpeech(text: String, language: String) async throws -> Data {
        do {
            let dict: [String: Any] = [
                "text": text,
                "language": language,
            ]
            let body = try JSONSerialization.data(withJSONObject: dict, options: [])
            return try await postBytes(endpoint: Endpoint.tts, body: body)
        } catch {
            Self.logger.warning("Failed to get TTS audio: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Private Helpers

    /// Apply default headers to a mutable URLRequest.
    private func applyHeaders(_ request: inout URLRequest) {
        for (key, value) in defaultHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    /// Build a JSON error string safely using JSONSerialization.
    private static func buildErrorJson(code: Int, message: String) -> String {
        let dict: [String: Any] = ["code": code, "message": message]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
