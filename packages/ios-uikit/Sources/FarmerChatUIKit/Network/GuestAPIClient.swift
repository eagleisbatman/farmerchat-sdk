import Foundation
import os

/// Handles guest-user initialisation via POST /api/user/initialize_user/
/// Uses Api-Key auth — the only endpoint that doesn't require a JWT first.
struct GuestAPIClient {

    private static let logger = Logger(
        subsystem: "org.digitalgreen.farmerchat",
        category: "UIKit.GuestAPIClient"
    )

    static let guestApiKey = "Y2K3kW5R9uQ0fL2X8zI7hT3aJ7"

    private let baseUrl: String

    init(baseUrl: String) {
        self.baseUrl = baseUrl.trimmingCharacters(in: .init(charactersIn: "/"))
    }

    @discardableResult
    func initializeUser(deviceId: String) async throws -> InitializeGuestUserResponse {
        guard let url = URL(string: "\(baseUrl)/api/user/initialize_user/") else {
            throw ApiError(statusCode: 0, errorBody: "Invalid URL")
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json",         forHTTPHeaderField: "Content-Type")
        request.setValue("Api-Key \(Self.guestApiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["device_id": deviceId])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ApiError(statusCode: 0, errorBody: "Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw ApiError(statusCode: http.statusCode, errorBody: String(data: data, encoding: .utf8) ?? "")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let parsed = try decoder.decode(InitializeGuestUserResponse.self, from: data)

        await TokenStore.shared.saveTokens(
            accessToken:  parsed.accessToken,
            refreshToken: parsed.refreshToken,
            userId:       parsed.userId ?? "",
            countryCode:  parsed.countryCode,
            country:      parsed.country,
            state:        parsed.state
        )

        Self.logger.debug("Guest user initialized. userId=\(parsed.userId ?? "nil")")
        return parsed
    }
}
