import Foundation
import SwiftUI

/// Main entry point for the FarmerChat SwiftUI SDK.
///
/// Initialize once early in your app's lifecycle (e.g., in `App.init()` or `AppDelegate`).
/// Access the singleton via ``FarmerChat/shared``.
///
/// ```swift
/// FarmerChat.shared.initialize(config: FarmerChatConfig(
///     apiKey: "your-api-key",
///     defaultLanguage: "en"
/// ))
/// ```
///
/// All methods are wrapped in do/catch -- the SDK must NEVER crash the host app.
@MainActor
public final class FarmerChat {

    private static let tag = "FC.FarmerChat"

    /// Shared singleton instance.
    public static let shared = FarmerChat()

    /// Whether the SDK has been initialized.
    public private(set) var isInitialized = false

    /// The current SDK configuration, or `nil` if not yet initialized.
    public private(set) var config: FarmerChatConfig?

    // MARK: - Internal Components (accessed by ChatViewModel)

    /// HTTP client for API calls.
    internal var apiClient: ApiClient?

    /// Network connectivity monitor.
    internal var connectivityMonitor: ConnectivityMonitor?

    /// Crash reporting bridge.
    internal var crashBridge: CrashBridge?

    /// Event callback for SDK lifecycle events.
    internal var eventCallback: ((FarmerChatEvent) -> Void)?

    /// Shared ViewModel instance — created once during initialize, torn down in destroy.
    internal var chatViewModel: ChatViewModel?

    /// Auto-generated session ID (used when config.sessionId is nil).
    private var generatedSessionId: String?

    private init() {}

    // MARK: - Public API

    /// Initialize the FarmerChat SDK with configuration.
    ///
    /// This method is idempotent -- calling it more than once is a no-op.
    /// All work is wrapped in do/catch so SDK initialization can never crash the host app.
    ///
    /// - Parameter config: SDK configuration including API key, theme, and callbacks.
    public func initialize(config: FarmerChatConfig) {
        guard !isInitialized else { return }

        self.config = config
        self.generatedSessionId = UUID().uuidString
        self.eventCallback = config.onEvent

        // Validate and create the API client
        guard let baseURL = URL(string: config.baseUrl),
              let scheme = baseURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            print("[\(FarmerChat.tag)] Invalid base URL (must be http/https): \(config.baseUrl)")
            return
        }
        self.apiClient = ApiClient(
            baseURL: baseURL,
            apiKey: config.apiKey,
            requestTimeoutMs: config.requestTimeoutMs,
            sseTimeoutMs: config.requestTimeoutMs * 2
        )

        // Create and start the connectivity monitor
        let monitor = ConnectivityMonitor()
        monitor.start()
        self.connectivityMonitor = monitor

        // Create and detect the crash bridge
        let bridge = CrashBridge()
        bridge.detect()
        self.crashBridge = bridge

        // Set custom keys on crash bridge for diagnostics
        bridge.setCustomKey("sdk_version", value: "0.0.0")
        if let partnerId = config.partnerId {
            bridge.setCustomKey("partner_id", value: partnerId)
        }

        self.chatViewModel = ChatViewModel()
        self.isInitialized = true
        print("[\(FarmerChat.tag)] SDK initialized successfully")
    }

    /// Returns the main chat view.
    ///
    /// Present this as a sheet, fullScreenCover, or push onto a NavigationStack.
    /// The SDK must be initialized before calling this method.
    ///
    /// ```swift
    /// .fullScreenCover(isPresented: $showChat) {
    ///     FarmerChat.shared.chatView()
    /// }
    /// ```
    @MainActor @ViewBuilder
    public func chatView() -> some View {
        if isInitialized, let viewModel = chatViewModel {
            FarmerChatRootView(viewModel: viewModel)
        } else {
            Text("FarmerChat SDK not initialized")
                .foregroundColor(.secondary)
        }
    }

    /// Destroy the SDK and release all resources.
    ///
    /// After calling this, ``initialize(config:)`` may be called again.
    public func destroy() {
        chatViewModel?.stopStream()
        connectivityMonitor?.stop()
        connectivityMonitor = nil
        apiClient = nil
        crashBridge = nil
        eventCallback = nil
        chatViewModel = nil
        config = nil
        generatedSessionId = nil
        isInitialized = false
        print("[\(FarmerChat.tag)] SDK destroyed")
    }

    // MARK: - Internal Accessors

    /// Get the current session ID.
    ///
    /// Returns the config-provided session ID if set, otherwise the auto-generated one.
    /// Returns an empty string if the SDK has not been initialized.
    internal func getSessionId() -> String {
        config?.sessionId ?? generatedSessionId ?? ""
    }

    /// Get the current SDK configuration, or defaults if not yet initialized.
    ///
    /// All callers must be on the MainActor (SwiftUI view bodies, @MainActor ViewModels).
    nonisolated internal static func getConfig() -> FarmerChatConfig {
        MainActor.assumeIsolated { shared.config } ?? FarmerChatConfig()
    }
}
