import Foundation
import os

/// Actor that handles JWT token refresh with a 2-step fallback.
///
/// Being an `actor` guarantees that only one refresh runs at a time —
/// concurrent callers will suspend and share the same refreshed token.
///
/// Step 1: POST /api/user/get_new_access_token/ with `refresh_token`
/// Step 2 (fallback): POST /api/user/send_tokens/ with `device_id` + `user_id`
actor TokenRefreshHandler {

    private static let logger = Logger(
        subsystem: "org.digitalgreen.farmerchat",
        category: "TokenRefreshHandler"
    )

    private let baseUrl: String
    private let sdkApiKey: String
    private var refreshTask: Task<String, Error>?

    init(baseUrl: String, sdkApiKey: String) {
        self.baseUrl = baseUrl.trimmingCharacters(in: .init(charactersIn: "/"))
        self.sdkApiKey = sdkApiKey
    }

    /// Refresh tokens. Returns the new access token.
    /// If a refresh is already in-flight, waits for it and returns its result.
    func refreshToken() async throws -> String {
        if let existing = refreshTask {
            return try await existing.value
        }

        let task = Task<String, Error> {
            defer { Task { await self.clearRefreshTask() } }
            return try await self.performRefresh()
        }
        self.refreshTask = task
        return try await task.value
    }

    private func clearRefreshTask() {
        refreshTask = nil
    }

    private func performRefresh() async throws -> String {
        // Step 1: primary refresh
        if let token = await tryPrimaryRefresh() {
            return token
        }
        Self.logger.warning("Primary token refresh failed; trying fallback")

        // Step 2: fallback
        if let token = await tryFallbackRefresh() {
            return token
        }

        throw NetworkError.unauthorized
    }

    private func tryPrimaryRefresh() async -> String? {
        guard let url = URL(string: "\(baseUrl)/api/user/get_new_access_token/") else { return nil }
        let refreshToken = await TokenStore.shared.refreshToken

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sdkApiKey, forHTTPHeaderField: "X-SDK-Key")
        request.httpBody = try? JSONEncoder().encode(["refresh_token": refreshToken])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let parsed = try? decoder.decode(TokenResponse.self, from: data),
              let newAccess = parsed.accessToken, !newAccess.isEmpty else {
            return nil
        }

        await TokenStore.shared.saveAccessToken(newAccess, refreshToken: parsed.refreshToken ?? "")
        Self.logger.debug("Token refresh step 1 succeeded")
        return newAccess
    }

    private func tryFallbackRefresh() async -> String? {
        guard let url = URL(string: "\(baseUrl)/api/user/send_tokens/") else { return nil }
        let deviceId = await TokenStore.shared.deviceId
        let userId   = await TokenStore.shared.userId

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(GuestAPIClient.guestApiKey, forHTTPHeaderField: "API-Key")
        request.httpBody = try? JSONEncoder().encode([
            "device_id": deviceId,
            "user_id":   userId,
        ])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let parsed = try? decoder.decode(TokenResponse.self, from: data),
              let newAccess = parsed.accessToken, !newAccess.isEmpty else {
            return nil
        }

        await TokenStore.shared.saveAccessToken(newAccess, refreshToken: parsed.refreshToken ?? "")
        Self.logger.debug("Token refresh fallback (step 2) succeeded")
        return newAccess
    }
}
