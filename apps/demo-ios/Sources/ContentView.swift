import SwiftUI

// MARK: - Shared Constants

extension Color {
    /// FarmerChat brand green (#1B6B3A)
    static let farmerChatGreen = Color(red: 0.106, green: 0.420, blue: 0.227)
}

/// Root view with a tab bar for switching between SwiftUI and UIKit SDK demos.
struct ContentView: View {
    var body: some View {
        TabView {
            SwiftUITab()
                .tabItem {
                    Label("SwiftUI", systemImage: "swift")
                }

            UIKitTab()
                .tabItem {
                    Label("UIKit", systemImage: "hammer.fill")
                }
        }
        .tint(.farmerChatGreen)
    }
}
