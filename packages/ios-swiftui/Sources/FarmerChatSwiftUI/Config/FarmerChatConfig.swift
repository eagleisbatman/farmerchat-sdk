import Foundation

// MARK: - FarmerChatEvent

/// All SDK lifecycle events emitted to the host app.
public enum FarmerChatEvent {
    case chatOpened(sessionId: String, timestamp: Date)
    case chatClosed(sessionId: String, messageCount: Int, timestamp: Date)
    case querySent(sessionId: String, queryId: String, inputMethod: String, timestamp: Date)
    case responseReceived(sessionId: String, responseId: String, latencyMs: Int64, timestamp: Date)
    case error(code: String, message: String, fatal: Bool, timestamp: Date)
    case languageChanged(from: String, to: String, timestamp: Date)
    case connectivityChanged(isConnected: Bool, timestamp: Date)
}

// MARK: - CrashReporter

public protocol CrashReporter {
    func reportCrash(_ error: Error, breadcrumbs: [String])
    func addBreadcrumb(_ message: String)
    func setCustomKey(_ key: String, value: String)
}

// MARK: - CrashConfig

public struct CrashConfig {
    public var enabled: Bool
    public var reporter: CrashReporter?
    public init(enabled: Bool = true, reporter: CrashReporter? = nil) {
        self.enabled = enabled
        self.reporter = reporter
    }
}

// MARK: - ThemeConfig

public struct ThemeConfig {
    public var primaryColor: String
    public var secondaryColor: String?
    public var fontFamily: String?
    public var cornerRadius: Double?
    public init(
        primaryColor: String = "#1B6B3A",
        secondaryColor: String? = nil,
        fontFamily: String? = nil,
        cornerRadius: Double? = nil
    ) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.fontFamily = fontFamily
        self.cornerRadius = cornerRadius
    }
}

// MARK: - FarmerChatConfig

/// Primary configuration for the FarmerChat SDK.
/// Pass to `FarmerChatSDK.shared.configure(_:)`.
public struct FarmerChatConfig {

    /// Base URL for the FarmerChat API.
    public var baseUrl: String

    /**
     * SDK API key issued by Digital Green.
     * Format: `fc_live_<16+ alphanumeric>` (production) or `fc_test_<16+ alphanumeric>` (sandbox).
     * Sent on every request as the `X-SDK-Key` header.
     */
    public var sdkApiKey: String

    /// Optional multi-tenant content provider identifier.
    public var contentProviderId: String?

    // ── UI / behaviour ──────────────────────────────────────────────

    public var theme: ThemeConfig?
    public var crash: CrashConfig?
    public var headerTitle: String
    public var defaultLanguage: String?
    public var voiceInputEnabled: Bool
    public var imageInputEnabled: Bool
    public var historyEnabled: Bool
    public var profileEnabled: Bool
    public var showPoweredBy: Bool
    public var maxMessagesInMemory: Int
    public var requestTimeoutMs: Int
    public var maxImageDimension: Int
    public var imageCompressionQuality: Int

    /// Global event callback for SDK lifecycle events.
    public var onEvent: ((FarmerChatEvent) -> Void)?

    public init(
        baseUrl: String = "https://farmerchat.farmstack.co/mobile-app-dev",
        sdkApiKey: String = "",
        contentProviderId: String? = nil,
        theme: ThemeConfig? = nil,
        crash: CrashConfig? = nil,
        headerTitle: String = "FarmerChat",
        defaultLanguage: String? = nil,
        voiceInputEnabled: Bool = true,
        imageInputEnabled: Bool = true,
        historyEnabled: Bool = true,
        profileEnabled: Bool = true,
        showPoweredBy: Bool = true,
        maxMessagesInMemory: Int = 50,
        requestTimeoutMs: Int = 15_000,
        maxImageDimension: Int = 300,
        imageCompressionQuality: Int = 80,
        onEvent: ((FarmerChatEvent) -> Void)? = nil
    ) {
        self.baseUrl = baseUrl
        self.sdkApiKey = sdkApiKey
        self.contentProviderId = contentProviderId
        self.theme = theme
        self.crash = crash
        self.headerTitle = headerTitle
        self.defaultLanguage = defaultLanguage
        self.voiceInputEnabled = voiceInputEnabled
        self.imageInputEnabled = imageInputEnabled
        self.historyEnabled = historyEnabled
        self.profileEnabled = profileEnabled
        self.showPoweredBy = showPoweredBy
        self.maxMessagesInMemory = maxMessagesInMemory
        self.requestTimeoutMs = requestTimeoutMs
        self.maxImageDimension = maxImageDimension
        self.imageCompressionQuality = imageCompressionQuality
        self.onEvent = onEvent
    }
}
