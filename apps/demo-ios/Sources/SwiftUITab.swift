import SwiftUI
import FarmerChatSwiftUI

/// Demo tab showcasing the SwiftUI SDK.
///
/// Displays app info with the FarmerChatFAB overlaid in the bottom-trailing corner.
/// Tapping the FAB presents the SwiftUI chat view as a full-screen cover.
struct SwiftUITab: View {
    @State private var showChat = false

    private let farmerChatGreen = Color.farmerChatGreen

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Content
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundColor(farmerChatGreen)

                Text("FarmerChat SDK")
                    .font(.largeTitle.bold())

                Text("SwiftUI Demo")
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text("This tab demonstrates the SwiftUI variant of the FarmerChat SDK. Tap the floating button to open the chat.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Text("FarmerChatSwiftUI")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)

            // FAB overlay
            FarmerChatSwiftUI.FarmerChatFAB {
                showChat = true
            }
            .padding(24)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showChat) {
            FarmerChatSwiftUI.FarmerChat.shared.chatView()
        }
        #else
        .sheet(isPresented: $showChat) {
            FarmerChatSwiftUI.FarmerChat.shared.chatView()
        }
        #endif
    }
}
