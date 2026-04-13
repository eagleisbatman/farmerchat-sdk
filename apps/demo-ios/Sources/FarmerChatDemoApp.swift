import SwiftUI
import FarmerChatSwiftUI
import FarmerChatUIKit

@main
struct FarmerChatDemoApp: App {
    // API key from environment (set via Xcode scheme or launch argument); falls back to placeholder.
    // WARNING: Replace "demo-key" with your real key or set FC_API_KEY in your scheme environment.
    private static let apiKey = ProcessInfo.processInfo.environment["FC_API_KEY"] ?? "demo-key"

    init() {
        // Initialize the SwiftUI SDK.
        FarmerChatSwiftUI.FarmerChat.shared.configure(
            FarmerChatSwiftUI.FarmerChatConfig(
                sdkApiKey:       Self.apiKey,
                weatherTemp:     "28°C ☀️",
                weatherLocation: "Coorg, Karnataka",
                cropName:        "Rice"
            )
        )

        // Initialize the UIKit SDK.
        FarmerChatUIKit.FarmerChat.shared.initialize(
            config: FarmerChatUIKit.FarmerChatConfig(
                apiKey:          Self.apiKey,
                weatherTemp:     "28°C ☀️",
                weatherLocation: "Coorg, Karnataka",
                cropName:        "Rice"
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
