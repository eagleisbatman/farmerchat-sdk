import Foundation

// MARK: - FarmerChatEvent

/// All SDK lifecycle events emitted to the host app.
///
/// Register a listener via ``FarmerChatConfig/onEvent`` to receive these events.
/// Each case carries a `timestamp` (`Date`) for ordering and analytics.
///
/// Maps 1:1 with the core TypeScript `SDKEvent` union in `types/events.ts`
/// and the Android `FarmerChatEvent` sealed interface.
public enum FarmerChatEvent {

    /// Emitted when the chat screen is opened.
    case chatOpened(sessionId: String, timestamp: Date)

    /// Emitted when the chat screen is closed.
    case chatClosed(sessionId: String, messageCount: Int, timestamp: Date)

    /// Emitted when the user sends a query (text, voice, image, or follow-up).
    case querySent(sessionId: String, queryId: String, inputMethod: String, timestamp: Date)

    /// Emitted when a complete AI response is received.
    case responseReceived(sessionId: String, responseId: String, latencyMs: Int64, timestamp: Date)

    /// Emitted when an SDK error occurs.
    case error(code: String, message: String, fatal: Bool, timestamp: Date)

    /// Emitted when the first SSE token arrives for a streaming response.
    case streamingStarted(sessionId: String, queryId: String, timestamp: Date)

    /// Emitted on each individual SSE token during streaming.
    case streamingToken(sessionId: String, text: String, index: Int, timestamp: Date)

    /// Emitted when the user submits feedback on a response.
    case feedbackSubmitted(sessionId: String, responseId: String, rating: String, timestamp: Date)

    /// Emitted when the user changes the active language.
    case languageChanged(from: String, to: String, timestamp: Date)

    /// Emitted when the user completes the onboarding flow.
    case onboardingCompleted(
        sessionId: String,
        location: (lat: Double, lng: Double),
        language: String,
        timestamp: Date
    )

    /// Emitted when network connectivity status changes.
    case connectivityChanged(isConnected: Bool, timestamp: Date)
}

// MARK: - CrashReporter Protocol

/// Protocol for pluggable crash reporter adapters.
/// Partners implement this to forward SDK crashes to their crash tool.
public protocol CrashReporter {
    /// Report a crash with error details and SDK breadcrumbs.
    func reportCrash(_ error: Error, breadcrumbs: [String])
    /// Add a breadcrumb for crash context.
    func addBreadcrumb(_ message: String)
    /// Set a custom key-value pair on crash reports.
    func setCustomKey(_ key: String, value: String)
}

// MARK: - CrashConfig

/// Configuration for crash reporting integration.
public struct CrashConfig {
    /// Enable crash reporting. Defaults to `true` (uses built-in auto-detected reporter).
    public var enabled: Bool
    /// Custom crash reporter adapter (Firebase, Sentry, Bugsnag, or custom).
    public var reporter: CrashReporter?

    public init(
        enabled: Bool = true,
        reporter: CrashReporter? = nil
    ) {
        self.enabled = enabled
        self.reporter = reporter
    }
}

// MARK: - ThemeConfig

/// Theme customization for the SDK UI.
///
/// Colors are specified as hex strings (e.g., "#1B6B3A"). UIKit-specific
/// conversion to `UIColor` happens internally via `UIColor(hex:)`.
public struct ThemeConfig {
    /// Primary brand color as hex string (e.g., "#1B6B3A").
    public var primaryColor: String
    /// Secondary/accent color as hex string.
    public var secondaryColor: String?
    /// Font family name (must be available on iOS).
    public var fontFamily: String?
    /// Corner radius for cards and buttons in points.
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
/// Passed to `FarmerChat.initialize()`.
public struct FarmerChatConfig {

    /// Partner API key issued by Digital Green.
    public var apiKey: String

    /// Base URL for the FarmerChat API.
    public var baseUrl: String

    /// Partner identifier used for analytics segmentation and content injection.
    public var partnerId: String?

    /// External session ID. If omitted, the SDK generates one internally.
    /// Use this to correlate FarmerChat sessions with your own analytics.
    public var sessionId: String?

    /// User's location for geo-contextualized agricultural advice.
    public var location: (lat: Double, lng: Double)?

    /// UI theme customization.
    public var theme: ThemeConfig?

    /// Crash reporting configuration.
    public var crash: CrashConfig?

    /// Header title displayed in the chat screen.
    public var headerTitle: String

    /// Default language code (e.g., "hi", "en", "sw"). Loaded from server if not set.
    public var defaultLanguage: String?

    /// Enable voice input. Defaults to `true`.
    public var voiceInputEnabled: Bool

    /// Enable image input (camera/gallery). Defaults to `true`.
    public var imageInputEnabled: Bool

    /// Enable chat history screen. Defaults to `true`.
    public var historyEnabled: Bool

    /// Enable profile/settings screen. Defaults to `true`.
    public var profileEnabled: Bool

    /// Show "Powered by FarmerChat" branding. Defaults to `true`.
    public var showPoweredBy: Bool

    /// Maximum number of messages to keep in memory. Defaults to 50.
    public var maxMessagesInMemory: Int

    /// Request timeout in milliseconds. Defaults to 15,000.
    public var requestTimeoutMs: Int

    /// Number of SSE reconnect attempts before showing a connection error. Defaults to 1.
    public var sseReconnectAttempts: Int

    /// Maximum thumbnail dimension in points for image previews.
    /// Images larger than this are down-scaled before display. Defaults to 300.
    public var maxImageDimension: Int

    /// Image compression quality (0-100) applied before uploading.
    /// Higher values produce better quality at the cost of larger payloads. Defaults to 80.
    public var imageCompressionQuality: Int

    /// Global event callback. Invoked for every SDK lifecycle event
    /// (chat opened/closed, queries, responses, errors, etc.).
    public var onEvent: ((FarmerChatEvent) -> Void)?

    // MARK: - Weather Widget

    /// Primary weather text shown in the weather card (e.g. "28°C ☀️").
    /// When nil the weather widget is hidden entirely.
    public var weatherTemp: String?

    /// Location label shown below the temperature (e.g. "Coorg, Karnataka").
    public var weatherLocation: String?

    /// Crop chip text on the weather card (e.g. "Rice").
    public var cropName: String?

    // MARK: - Country / Region

    /// ISO 3166-1 alpha-2 country code used for the language selection API.
    /// If blank, the SDK detects it from IP geolocation or SIM/locale.
    public var countryCode: String

    /// State/province code for more localised language lists (optional).
    public var stateCode: String?

    public init(
        apiKey: String = "",
        baseUrl: String = "https://api.farmerchat.digitalgreen.org",
        partnerId: String? = nil,
        sessionId: String? = nil,
        location: (lat: Double, lng: Double)? = nil,
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
        sseReconnectAttempts: Int = 1,
        maxImageDimension: Int = 300,
        imageCompressionQuality: Int = 80,
        weatherTemp: String? = nil,
        weatherLocation: String? = nil,
        cropName: String? = nil,
        countryCode: String = "",
        stateCode: String? = nil,
        onEvent: ((FarmerChatEvent) -> Void)? = nil
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.partnerId = partnerId
        self.sessionId = sessionId
        self.location = location
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
        self.sseReconnectAttempts = sseReconnectAttempts
        self.maxImageDimension = maxImageDimension
        self.imageCompressionQuality = imageCompressionQuality
        self.weatherTemp = weatherTemp
        self.weatherLocation = weatherLocation
        self.cropName = cropName
        self.countryCode = countryCode
        self.stateCode = stateCode
        self.onEvent = onEvent
    }
}
