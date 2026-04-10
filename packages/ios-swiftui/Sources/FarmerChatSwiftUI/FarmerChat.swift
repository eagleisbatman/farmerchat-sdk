import Foundation
import SwiftUI

/// Main entry point for the FarmerChat SwiftUI SDK.
///
/// Initialize once early in your app lifecycle (e.g. `App.init()` or `AppDelegate`):
/// ```swift
/// FarmerChat.shared.configure(
///     FarmerChatConfig(
///         baseUrl:   "https://farmerchat.farmstack.co/mobile-app-dev",
///         sdkApiKey: "fc_test_<your_key>"
///     )
/// )
/// ```
@MainActor
public final class FarmerChat {

    private static let tag = "FC.FarmerChat"

    /// Shared singleton instance.
    public static let shared = FarmerChat()

    /// Whether the SDK has been initialized.
    public private(set) var isInitialized = false

    /// The current SDK configuration.
    public private(set) var config: FarmerChatConfig?

    // MARK: - Internal components

    internal var apiClient: ApiClient?
    internal var connectivityMonitor: ConnectivityMonitor?
    internal var crashBridge: CrashBridge?
    internal var eventCallback: ((FarmerChatEvent) -> Void)?
    internal var chatViewModel: ChatViewModel?

    private var sessionId: String?

    private init() {}

    // MARK: - Public API

    /// Configure and initialize the SDK. Idempotent — safe to call more than once.
    ///
    /// On first call this will:
    /// 1. Store the device ID in `UserDefaults` and `TokenStore`.
    /// 2. Create the `ApiClient`.
    /// 3. Launch a background task to call `initialize_user` (guest auth).
    public func configure(_ config: FarmerChatConfig) {
        guard !isInitialized else { return }

        self.config = config
        self.sessionId = UUID().uuidString
        self.eventCallback = config.onEvent

        let deviceId = DeviceInfoProvider.stableDeviceId()
        let deviceInfo = DeviceInfoProvider.buildHeader(deviceId: deviceId)
        Task { await TokenStore.shared.setDeviceId(deviceId) }

        self.apiClient = ApiClient(
            baseUrl: config.baseUrl,
            sdkApiKey: config.sdkApiKey,
            deviceInfo: deviceInfo,
            timeoutMs: config.requestTimeoutMs
        )

        let monitor = ConnectivityMonitor()
        monitor.start()
        self.connectivityMonitor = monitor

        let bridge = CrashBridge()
        bridge.detect()
        self.crashBridge = bridge

        self.chatViewModel = ChatViewModel()
        self.isInitialized = true

        // Background: ensure guest tokens are available before first chat
        Task {
            do {
                let initialized = await TokenStore.shared.isInitialized
                if !initialized {
                    try await GuestAPIClient(baseUrl: config.baseUrl).initializeUser(deviceId: deviceId)
                }
            } catch {
                print("[\(FarmerChat.tag)] Background guest init failed (will retry on chat open): \(error)")
            }
        }

        print("[\(FarmerChat.tag)] SDK initialized")
    }

    /// Returns the main chat view. Present as a sheet, fullScreenCover, or push.
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
    /// After calling this, `configure(_:)` may be called again.
    public func destroy() {
        connectivityMonitor?.stop()
        Task { await TokenStore.shared.clearTokens() }
        apiClient = nil
        connectivityMonitor = nil
        crashBridge = nil
        eventCallback = nil
        chatViewModel = nil
        config = nil
        sessionId = nil
        isInitialized = false
        print("[\(FarmerChat.tag)] SDK destroyed")
    }

    // MARK: - Internal accessors

    internal func getSessionId() -> String { sessionId ?? "" }

    nonisolated internal static func getConfig() -> FarmerChatConfig {
        MainActor.assumeIsolated { shared.config } ?? FarmerChatConfig()
    }
}
