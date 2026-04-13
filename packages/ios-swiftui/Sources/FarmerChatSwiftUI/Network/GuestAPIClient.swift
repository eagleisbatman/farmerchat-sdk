import Foundation
import os

/// Standalone client used exclusively for guest user initialisation.
///
/// Uses `API-Key: <key>` header — the only endpoint
/// that does not require a prior JWT token.
///
/// Endpoint: `POST /api/user/initialize_user/`
struct GuestAPIClient {

    private static let logger = Logger(
        subsystem: "org.digitalgreen.farmerchat",
        category: "GuestAPIClient"
    )

    static let guestApiKey = "Y2K3kW5R9uQ0fL2X8zI7hT3aJ7"

    private let baseUrl: String

    init(baseUrl: String) {
        self.baseUrl = baseUrl.trimmingCharacters(in: .init(charactersIn: "/"))
    }

    /// Initialize (or re-identify) a guest user by device ID.
    ///
    /// On success, tokens are saved to `TokenStore.shared`.
    ///
    /// - Parameter deviceId: Stable device UUID from `DeviceInfoProvider.stableDeviceId()`.
    @discardableResult
    func initializeUser(deviceId: String) async throws -> InitializeGuestUserResponse {
        guard let url = URL(string: "\(baseUrl)/api/user/initialize_user/") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.guestApiKey, forHTTPHeaderField: "API-Key")
        request.httpBody = try JSONEncoder().encode(["device_id": deviceId])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NetworkError.serverError(http.statusCode, body)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let parsed = try decoder.decode(InitializeGuestUserResponse.self, from: data)

        await TokenStore.shared.saveTokens(
            accessToken: parsed.accessToken,
            refreshToken: parsed.refreshToken,
            userId: parsed.userId ?? "",
            countryCode: parsed.countryCode,
            country: parsed.country,
            state: parsed.state
        )

        Self.logger.debug("Guest user initialized. userId=\(parsed.userId ?? "nil")")
        return parsed
    }
}
