import Foundation

/// In-memory store for JWT tokens and device identity.
/// Thread-safe via Swift `actor`.
actor TokenStore {

    static let shared = TokenStore()
    private init() {}

    private(set) var accessToken:  String = ""
    private(set) var refreshToken: String = ""
    private(set) var userId:       String = ""
    private(set) var deviceId:     String = ""
    private(set) var isInitialized: Bool  = false

    // IP-geolocation from initialize_user (no GPS permission needed)
    private(set) var countryCode: String = ""
    private(set) var country:     String = ""
    private(set) var state:       String = ""

    func saveTokens(
        accessToken:  String,
        refreshToken: String,
        userId:       String,
        countryCode:  String? = nil,
        country:      String? = nil,
        state:        String? = nil
    ) {
        self.accessToken  = accessToken
        self.refreshToken = refreshToken
        self.userId       = userId
        self.isInitialized = true
        if let cc = countryCode, !cc.isEmpty { self.countryCode = cc }
        if let c  = country,    !c.isEmpty   { self.country = c }
        if let s  = state,      !s.isEmpty   { self.state = s }
    }

    func saveAccessToken(_ access: String, refreshToken: String) {
        self.accessToken = access
        if !refreshToken.isEmpty { self.refreshToken = refreshToken }
    }

    func setDeviceId(_ id: String) { self.deviceId = id }

    func clearTokens() {
        accessToken  = ""
        refreshToken = ""
        userId       = ""
        isInitialized = false
    }
}
