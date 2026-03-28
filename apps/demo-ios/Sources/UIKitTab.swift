import SwiftUI
import FarmerChatUIKit

#if canImport(UIKit)
import UIKit

// MARK: - UIKit Tab

/// Demo tab showcasing the UIKit SDK.
///
/// Displays app info with the UIKit FarmerChatFAB wrapped via UIViewRepresentable.
/// Tapping the FAB presents the UIKit chatViewController as a full-screen cover.
struct UIKitTab: View {
    @State private var showChat = false

    private let farmerChatGreen = Color.farmerChatGreen

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Content
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 48))
                    .foregroundColor(farmerChatGreen)

                Text("FarmerChat SDK")
                    .font(.largeTitle.bold())

                Text("UIKit Demo")
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text("This tab demonstrates the UIKit variant of the FarmerChat SDK. Tap the floating button to open the chat.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Text("FarmerChatUIKit")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)

            // FAB overlay (UIKit button wrapped for SwiftUI)
            UIKitFABWrapper {
                showChat = true
            }
            .frame(width: 56, height: 56)
            .padding(24)
        }
        .fullScreenCover(isPresented: $showChat) {
            UIKitChatWrapper()
                .ignoresSafeArea()
        }
    }
}

// MARK: - UIViewRepresentable: FAB

/// Wraps the UIKit `FarmerChatFAB` (a UIButton subclass) for use in SwiftUI.
struct UIKitFABWrapper: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> UIView {
        let fab = FarmerChatUIKit.FarmerChat.shared.fabView {
            // Will be updated in updateUIView via coordinator
        }
        // Store the action via the coordinator
        if let button = fab as? FarmerChatUIKit.FarmerChatFAB {
            button.tapAction = action
        }
        return fab
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let button = uiView as? FarmerChatUIKit.FarmerChatFAB {
            button.tapAction = action
        }
    }
}

// MARK: - UIViewControllerRepresentable: Chat

/// Wraps the UIKit `chatViewController()` (a UINavigationController) for use in SwiftUI.
struct UIKitChatWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        FarmerChatUIKit.FarmerChat.shared.chatViewController()
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed -- the chat VC manages its own state.
    }
}

#else

// MARK: - macOS Stub

/// Placeholder for non-UIKit platforms (macOS SPM resolution).
struct UIKitTab: View {
    var body: some View {
        Text("UIKit demo is only available on iOS.")
            .foregroundColor(.secondary)
    }
}

#endif
