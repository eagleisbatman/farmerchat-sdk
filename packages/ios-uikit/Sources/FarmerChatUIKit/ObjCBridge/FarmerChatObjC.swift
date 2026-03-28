import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Objective-C compatible bridge for legacy partner apps.
///
/// Exposes the core FarmerChat API through `@objc`-compatible methods so that
/// Objective-C codebases can use the SDK without Swift interop complexity.
@objc @MainActor public class FarmerChatObjC: NSObject {

    /// Initialize the SDK with just an API key (uses all defaults).
    @objc public static func initialize(apiKey: String) {
        let config = FarmerChatConfig(apiKey: apiKey)
        FarmerChat.shared.initialize(config: config)
    }

    /// Initialize the SDK with an API key, custom base URL, and header title.
    @objc public static func initialize(apiKey: String, baseUrl: String, headerTitle: String) {
        let config = FarmerChatConfig(
            apiKey: apiKey,
            baseUrl: baseUrl,
            headerTitle: headerTitle
        )
        FarmerChat.shared.initialize(config: config)
    }

    #if canImport(UIKit)
    /// Returns the chat navigation controller for modal/push presentation.
    @objc public static func chatViewController() -> UINavigationController {
        FarmerChat.shared.chatViewController()
    }
    #endif

    /// Destroy the SDK and release all resources.
    @objc public static func destroy() {
        FarmerChat.shared.destroy()
    }
}
