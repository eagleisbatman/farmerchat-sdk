import SwiftUI

/// User profile and settings view.
struct ProfileView: View {
    @ObservedObject var viewModel: ChatViewModel

    private var config: FarmerChatConfig { FarmerChat.getConfig() }

    private var themeColor: Color {
        colorFromHex(config.theme?.primaryColor ?? "#1B6B3A")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button {
                    viewModel.navigateTo(.chat)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Back to chat")

                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeColor)

            Spacer()

            // Footer
            VStack(spacing: 8) {
                Divider()
                    .padding(.horizontal, 16)

                if config.showPoweredBy {
                    Text("Powered by FarmerChat")
                        .font(.caption)
                        .foregroundColor(Color.gray.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }

                Text("SDK v0.0.0")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)
            }
        }
        .background(Color(white: 0.95))
    }
}
