import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Main entry point for the FarmerChat UIKit SDK.
///
/// Initialize once early in your app's lifecycle (e.g., in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`).
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

        self.isInitialized = true
        print("[\(FarmerChat.tag)] SDK initialized successfully")
    }

    /// Destroy the SDK and release all resources.
    ///
    /// After calling this, ``initialize(config:)`` may be called again.
    public func destroy() {
        connectivityMonitor?.stop()
        connectivityMonitor = nil
        apiClient = nil
        crashBridge = nil
        eventCallback = nil
        config = nil
        generatedSessionId = nil
        isInitialized = false
        print("[\(FarmerChat.tag)] SDK destroyed")
    }

    #if canImport(UIKit)
    /// Returns a `UINavigationController` hosting the chat UI.
    ///
    /// Present modally or push onto your navigation stack.
    /// The SDK must be initialized before calling this method.
    ///
    /// ```swift
    /// let chatNav = FarmerChat.shared.chatViewController()
    /// present(chatNav, animated: true)
    /// ```
    public func chatViewController() -> UINavigationController {
        guard isInitialized else {
            print("[\(FarmerChat.tag)] SDK not initialized. Call initialize(config:) first.")
            let placeholder = UIViewController()
            placeholder.view.backgroundColor = .systemBackground
            return UINavigationController(rootViewController: placeholder)
        }

        let chatVC = ChatViewController()
        let navController = UINavigationController(rootViewController: chatVC)
        navController.modalPresentationStyle = .fullScreen
        return navController
    }

    /// Returns a standalone FAB (Floating Action Button) UIView.
    ///
    /// Place it in your view hierarchy with Auto Layout constraints.
    /// Tap triggers the provided action closure.
    ///
    /// - Parameter action: Closure invoked when the FAB is tapped.
    /// - Returns: A `FarmerChatFAB` instance (UIButton subclass).
    public func fabView(action: @escaping () -> Void) -> UIView {
        let fab = FarmerChatFAB()
        fab.tapAction = action
        return fab
    }
    #endif

    // MARK: - Internal Accessors

    /// Get the current session ID.
    ///
    /// Returns the config-provided session ID if set, otherwise the auto-generated one.
    /// Returns an empty string if the SDK has not been initialized.
    internal func getSessionId() -> String {
        config?.sessionId ?? generatedSessionId ?? ""
    }

    /// Get the current SDK configuration, or defaults if not yet initialized.
    nonisolated internal static func getConfig() -> FarmerChatConfig {
        MainActor.assumeIsolated {
            shared.config ?? FarmerChatConfig()
        }
    }
}
