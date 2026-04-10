import SwiftUI

// MARK: - Color / corner helpers

private let sdkPrimary = Color(red: 0.18, green: 0.49, blue: 0.20) // #2E7D32

private var primaryColor: Color {
    colorFromHex(FarmerChat.getConfig().theme?.primaryColor ?? "#2E7D32")
}

private var cardCornerRadius: Double {
    FarmerChat.getConfig().theme?.cornerRadius ?? 12
}

// MARK: - ChatView

/// Main chat screen — light system theme.
///
/// Layout: ChatTopBar → ConnectivityBanner → Messages / EmptyState → InputBar.
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    private var config: FarmerChatConfig { FarmerChat.getConfig() }

    private var isInputDisabled: Bool {
        if case .sending = viewModel.chatState { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatTopBar(viewModel: viewModel)

            if !viewModel.isConnected {
                ConnectivityBanner()
            }

            ZStack {
                Color(.systemBackground).ignoresSafeArea(edges: .bottom)

                if viewModel.messages.isEmpty {
                    EmptyStateArea()
                } else {
                    MessageList(viewModel: viewModel)
                }
            }

            // Error banner
            if case let .error(_, message, retryable) = viewModel.chatState {
                InlineErrorBanner(
                    message: message,
                    retryable: retryable,
                    onRetry: { viewModel.retryLastQuery() }
                )
            }

            InputBar(
                enabled:      !isInputDisabled && viewModel.isConnected,
                onSend:       { text in viewModel.sendQuery(text: text) },
                voiceEnabled: config.voiceInputEnabled,
                cameraEnabled: config.imageInputEnabled
            )
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - ChatTopBar

private struct ChatTopBar: View {
    @ObservedObject var viewModel: ChatViewModel
    private var config: FarmerChatConfig { FarmerChat.getConfig() }

    var body: some View {
        HStack(spacing: 10) {
            // Logo circle 32pt with leaf icon
            ZStack {
                Circle()
                    .fill(primaryColor)
                    .frame(width: 32, height: 32)
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            // Title column
            VStack(alignment: .leading, spacing: 2) {
                Text(config.headerTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("AI Farm Assistant")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // History icon
            if config.historyEnabled {
                Button {
                    viewModel.navigateTo(.history)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundColor(primaryColor)
                }
                .accessibilityLabel("Chat history")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(
            Divider(), alignment: .bottom
        )
    }
}

// MARK: - Empty state

private struct EmptyStateArea: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 48))
                .foregroundColor(primaryColor.opacity(0.5))
            Text("Ask a question about farming to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - Message list

private struct MessageList: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages) { message in
                        if message.role == "user" {
                            UserBubble(message: message)
                                .id(message.id)
                        } else {
                            ResponseCard(
                                message: message,
                                isStreaming: false,
                                onFollowUpClick: { text in viewModel.sendFollowUp(text: text) },
                                onFeedback: { _ in }
                            )
                            .id(message.id)
                        }
                    }

                    // Typing indicator when sending
                    if case .sending = viewModel.chatState {
                        LoadingBubble()
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

// MARK: - User bubble

private struct UserBubble: View {
    let message: ChatViewModel.ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        // #2E7D32 — user bubble, bottom-right 4pt
                        RoundedCornerShape2(
                            topLeft: 18, topRight: 18,
                            bottomLeft: 18, bottomRight: 4
                        )
                        .fill(Color(red: 0.18, green: 0.49, blue: 0.20))
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                Text(message.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Loading bubble (3 animated dots)

struct LoadingBubble: View {
    @State private var scale1: CGFloat = 0.5
    @State private var scale2: CGFloat = 0.5
    @State private var scale3: CGFloat = 0.5

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar
            ZStack {
                Circle().fill(Color(red: 0.18, green: 0.49, blue: 0.20)).frame(width: 32, height: 32)
                Image(systemName: "leaf.circle.fill").font(.system(size: 18)).foregroundColor(.white)
            }

            // Dots bubble
            HStack(spacing: 6) {
                dotView(scale: $scale1)
                dotView(scale: $scale2)
                dotView(scale: $scale3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(
                RoundedCornerShape2(topLeft: 4, topRight: 18, bottomLeft: 18, bottomRight: 18)
            )

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onAppear {
            animate(delay: 0.0, scale: $scale1)
            animate(delay: 0.2, scale: $scale2)
            animate(delay: 0.4, scale: $scale3)
        }
    }

    private func dotView(scale: Binding<CGFloat>) -> some View {
        Circle()
            .fill(Color(.systemGray3))
            .frame(width: 8, height: 8)
            .scaleEffect(scale.wrappedValue)
    }

    private func animate(delay: Double, scale: Binding<CGFloat>) {
        withAnimation(
            Animation.easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(delay)
        ) {
            scale.wrappedValue = 1.0
        }
    }
}

// MARK: - Inline error banner

private struct InlineErrorBanner: View {
    let message: String
    let retryable: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            Spacer()
            if retryable {
                Button("Retry", action: onRetry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(primaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Custom corner radius shape

/// Allows different corner radii per corner (SwiftUI workaround).
struct RoundedCornerShape2: Shape {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = min(topLeft, min(rect.width, rect.height) / 2)
        let tr = min(topRight, min(rect.width, rect.height) / 2)
        let bl = min(bottomLeft, min(rect.width, rect.height) / 2)
        let br = min(bottomRight, min(rect.width, rect.height) / 2)

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
