import SwiftUI
import FarmerChatSwiftUI
import FarmerChatUIKit

@main
struct FarmerChatDemoApp: App {
    // API key from environment (set via Xcode scheme or launch argument); falls back to placeholder.
    // WARNING: Replace "demo-key" with your real key or set FC_API_KEY in your scheme environment.
    private static let apiKey = ProcessInfo.processInfo.environment["FC_API_KEY"] ?? "demo-key"

    init() {
        // Initialize the SwiftUI SDK (uses SDK default base URL).
        // SDK.initialize() never throws — all errors are handled internally per design rule #10.
        FarmerChatSwiftUI.FarmerChat.shared.initialize(
            config: FarmerChatSwiftUI.FarmerChatConfig(
                apiKey: Self.apiKey
            )
        )

        // Initialize the UIKit SDK (uses SDK default base URL).
        FarmerChatUIKit.FarmerChat.shared.initialize(
            config: FarmerChatUIKit.FarmerChatConfig(
                apiKey: Self.apiKey
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
