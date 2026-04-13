import Foundation

/// In-memory store for JWT tokens and device identity.
/// All state is held only for the lifetime of the process — no local persistence.
///
/// Thread-safe: all mutations are isolated inside a Swift `actor`.
actor TokenStore {

    static let shared = TokenStore()

    private(set) var accessToken: String = ""
    private(set) var refreshToken: String = ""
    private(set) var userId: String = ""
    private(set) var deviceId: String = ""
    private(set) var isInitialized: Bool = false

    /// IP-geolocation data returned by initialize_user (no GPS permission needed)
    private(set) var countryCode: String = ""
    private(set) var country: String = ""
    private(set) var state: String = ""

    private init() {}

    func saveTokens(
        accessToken: String,
        refreshToken: String,
        userId: String,
        countryCode: String? = nil,
        country: String? = nil,
        state: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.isInitialized = true
        if let cc = countryCode, !cc.isEmpty { self.countryCode = cc }
        if let c  = country,     !c.isEmpty  { self.country = c }
        if let s  = state,       !s.isEmpty  { self.state = s }
    }

    func saveAccessToken(_ accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        if !refreshToken.isEmpty {
            self.refreshToken = refreshToken
        }
    }

    func setDeviceId(_ id: String) {
        self.deviceId = id
    }

    /// Clear auth tokens but keep the device ID (which must never change).
    func clearTokens() {
        accessToken = ""
        refreshToken = ""
        userId = ""
        isInitialized = false
    }
}
