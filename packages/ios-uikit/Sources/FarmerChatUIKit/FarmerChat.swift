import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Main entry point for the FarmerChat UIKit SDK.
///
/// Initialize once in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`:
/// ```swift
/// FarmerChat.shared.initialize(config: FarmerChatConfig(apiKey: "your-key"))
/// ```
@MainActor
public final class FarmerChat {

    private static let tag = "FC.FarmerChat"

    public static let shared = FarmerChat()
    private init() {}

    public private(set) var isInitialized = false
    public private(set) var config: FarmerChatConfig?

    internal var apiClient: ApiClient?
    internal var connectivityMonitor: ConnectivityMonitor?
    internal var crashBridge: CrashBridge?
    internal var eventCallback: ((FarmerChatEvent) -> Void)?
    private var generatedSessionId: String?

    // MARK: - Public API

    public func initialize(config: FarmerChatConfig) {
        guard !isInitialized else { return }
        do {
            try setupSDK(config: config)
        } catch {
            print("[\(FarmerChat.tag)] Initialization error: \(error)")
        }
    }

    private func setupSDK(config: FarmerChatConfig) throws {
        self.config = config
        self.generatedSessionId = UUID().uuidString
        self.eventCallback = config.onEvent

        guard let baseURL = URL(string: config.baseUrl),
              let scheme = baseURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            print("[\(FarmerChat.tag)] Invalid base URL: \(config.baseUrl)")
            return
        }

        let deviceInfo = "iOS/UIKit/\(UIDevice.current.systemVersion)"
        self.apiClient = ApiClient(
            baseUrl: config.baseUrl,
            sdkApiKey: config.apiKey,
            deviceInfo: deviceInfo,
            timeoutMs: config.requestTimeoutMs
        )

        let monitor = ConnectivityMonitor()
        monitor.start()
        self.connectivityMonitor = monitor

        let bridge = CrashBridge()
        bridge.detect()
        bridge.setCustomKey("sdk_version", value: "0.0.0")
        if let partnerId = config.partnerId { bridge.setCustomKey("partner_id", value: partnerId) }
        self.crashBridge = bridge

        self.isInitialized = true
        print("[\(FarmerChat.tag)] SDK initialized")

        // Kick off guest user initialization in the background
        let deviceId = SdkPreferences.stableDeviceId
        let baseUrl  = config.baseUrl
        Task {
            await self.ensureGuestUser(baseUrl: baseUrl, deviceId: deviceId)
        }
    }

    internal func ensureGuestUser(baseUrl: String, deviceId: String) async {
        await TokenStore.shared.setDeviceId(deviceId)
        let isInitialized = await TokenStore.shared.isInitialized
        guard !isInitialized else { return }
        do {
            let guestClient = GuestAPIClient(baseUrl: baseUrl)
            _ = try await guestClient.initializeUser(deviceId: deviceId)
            print("[\(FarmerChat.tag)] Guest user initialized")
        } catch {
            print("[\(FarmerChat.tag)] Guest user init failed: \(error)")
        }
    }

    public func destroy() {
        connectivityMonitor?.stop()
        connectivityMonitor = nil
        apiClient = nil
        crashBridge = nil
        eventCallback = nil
        config = nil
        generatedSessionId = nil
        isInitialized = false
    }

    #if canImport(UIKit)
    /// Returns a `UINavigationController` hosting the chat UI.
    /// Shows onboarding on first launch; shows chat on subsequent launches.
    public func chatViewController() -> UINavigationController {
        guard isInitialized else {
            print("[\(FarmerChat.tag)] Call initialize(config:) first.")
            let vc = UIViewController()
            vc.view.backgroundColor = .systemBackground
            return UINavigationController(rootViewController: vc)
        }

        let rootVC: UIViewController
        if !SdkPreferences.isOnboardingDone {
            rootVC = OnboardingViewController()
        } else {
            rootVC = ChatViewController()
        }
        let nav = UINavigationController(rootViewController: rootVC)
        nav.modalPresentationStyle = .fullScreen
        return nav
    }

    public func fabView(action: @escaping () -> Void) -> UIView {
        let fab = FarmerChatFAB()
        fab.tapAction = action
        return fab
    }
    #endif

    // MARK: - Internal

    internal func getSessionId() -> String {
        config?.sessionId ?? generatedSessionId ?? ""
    }

    nonisolated internal static func getConfig() -> FarmerChatConfig {
        MainActor.assumeIsolated { shared.config ?? FarmerChatConfig() }
    }
}
