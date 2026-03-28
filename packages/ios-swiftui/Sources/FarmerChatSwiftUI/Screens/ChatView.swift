import SwiftUI

/// Resolve the primary brand color from config, with a FarmerChat green fallback.
private var primaryColor: Color {
    let config = FarmerChat.getConfig()
    return colorFromHex(config.theme?.primaryColor ?? "#1B6B3A")
}

/// Default corner radius used across the SDK.
private var cardCornerRadius: Double {
    FarmerChat.getConfig().theme?.cornerRadius ?? 12
}

// MARK: - ChatView

/// Main chat screen view.
///
/// Layout: ChatTopBar + ConnectivityBanner + Messages/Starters + StreamingIndicator/ErrorBanner + InputBar
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    private var config: FarmerChatConfig { FarmerChat.getConfig() }

    /// Whether the input bar should be disabled.
    private var isInputDisabled: Bool {
        if case .sending = viewModel.chatState { return true }
        if case .streaming = viewModel.chatState { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatTopBar(viewModel: viewModel)

            if !viewModel.isConnected {
                ConnectivityBanner()
            }

            ZStack {
                Color(white: 0.95)
                    .ignoresSafeArea(edges: .bottom)

                if viewModel.messages.isEmpty {
                    StarterQuestionsArea(viewModel: viewModel)
                } else {
                    MessageList(viewModel: viewModel)
                }
            }

            VStack(spacing: 0) {
                if case .streaming = viewModel.chatState {
                    StreamingIndicator(viewModel: viewModel)
                }

                if case let .error(_, message, retryable) = viewModel.chatState {
                    ErrorBanner(
                        message: message,
                        retryable: retryable,
                        onRetry: { viewModel.retryLastQuery() }
                    )
                }

                // Follow-up chip row above input bar
                FollowUpRow(viewModel: viewModel, isDisabled: isInputDisabled)

                InputBar(
                    enabled: !isInputDisabled && viewModel.isConnected,
                    onSend: { text in
                        viewModel.sendQuery(text: text)
                    },
                    voiceEnabled: config.voiceInputEnabled,
                    cameraEnabled: config.imageInputEnabled
                )
            }
        }
        .task {
            viewModel.loadStarters()
        }
    }
}

// MARK: - ChatTopBar

/// Custom toolbar row with title, history, and profile buttons.
private struct ChatTopBar: View {
    @ObservedObject var viewModel: ChatViewModel

    private var config: FarmerChatConfig { FarmerChat.getConfig() }

    var body: some View {
        HStack(spacing: 12) {
            Text(config.headerTitle)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            if config.historyEnabled {
                Button {
                    viewModel.navigateTo(screen: .history)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Chat history")
            }

            if config.profileEnabled {
                Button {
                    viewModel.navigateTo(screen: .profile)
                } label: {
                    Image(systemName: "person.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(primaryColor)
    }
}

// MARK: - Starter Questions Area

/// Shown when the message list is empty. Displays a prompt and starter question chips.
private struct StarterQuestionsArea: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundColor(primaryColor.opacity(0.6))

                Text("Ask a question about farming to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if !viewModel.starterQuestions.isEmpty {
                    StarterChipGrid(
                        questions: viewModel.starterQuestions,
                        onTap: { text in
                            viewModel.sendQuery(text: text, inputMethod: "starter")
                        }
                    )
                    .padding(.horizontal, 16)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Flow-layout grid of starter question chips.
private struct StarterChipGrid: View {
    let questions: [StarterQuestionResponse]
    let onTap: (String) -> Void

    var body: some View {
        ChatFlowLayout(spacing: 8) {
            ForEach(Array(questions.enumerated()), id: \.offset) { _, question in
                Button {
                    onTap(question.text)
                } label: {
                    Text(question.text)
                        .font(.subheadline)
                        .foregroundColor(primaryColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: cardCornerRadius)
                                .fill(primaryColor.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cardCornerRadius)
                                .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
    }
}

// MARK: - ChatFlowLayout

/// A custom layout that wraps children into rows, similar to a CSS flexbox wrap.
/// Available on iOS 16+ via the `Layout` protocol.
private struct ChatFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        let totalHeight = currentY + rowHeight
        return ArrangeResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            positions: positions
        )
    }
}

// MARK: - Message List

/// Scrollable list of chat messages with auto-scroll to bottom.
private struct MessageList: View {
    @ObservedObject var viewModel: ChatViewModel

    /// Whether the last message is currently being streamed.
    private var isLastMessageStreaming: Bool {
        if case .streaming = viewModel.chatState { return true }
        return false
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        if message.role == "user" {
                            UserBubble(message: message)
                                .id(message.id)
                        } else {
                            let isThisStreaming = isLastMessageStreaming
                                && message.id == viewModel.messages.last?.id

                            ResponseCard(
                                message: message,
                                isStreaming: isThisStreaming,
                                onFollowUpClick: { text in
                                    viewModel.sendFollowUp(text: text)
                                },
                                onFeedback: { rating in
                                    viewModel.submitFeedback(
                                        messageId: message.id,
                                        rating: rating
                                    )
                                }
                            )
                            .id(message.id)
                        }
                    }

                    // Invisible anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id("chat_bottom_anchor")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("chat_bottom_anchor", anchor: .bottom)
                }
            }
            .onChange(of: streamingText) { _ in
                proxy.scrollTo("chat_bottom_anchor", anchor: .bottom)
            }
            .onAppear {
                proxy.scrollTo("chat_bottom_anchor", anchor: .bottom)
            }
        }
    }

    /// Extract streaming partial text for scroll tracking.
    private var streamingText: String {
        if case let .streaming(partialText, _) = viewModel.chatState {
            return partialText
        }
        return ""
    }
}

// MARK: - UserBubble

/// Right-aligned green bubble for a user message.
private struct UserBubble: View {
    let message: ChatViewModel.ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 60)

            VStack(alignment: .trailing, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: cardCornerRadius)
                            .fill(primaryColor)
                    )

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Follow-Up Row

/// Horizontal scroll of follow-up suggestion chips displayed above the input bar.
private struct FollowUpRow: View {
    @ObservedObject var viewModel: ChatViewModel
    let isDisabled: Bool

    var body: some View {
        if let lastAssistant = viewModel.messages.last(where: { $0.role == "assistant" }),
           !lastAssistant.followUps.isEmpty,
           !isDisabled {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(lastAssistant.followUps, id: \.self) { followUp in
                        Button {
                            viewModel.sendFollowUp(text: followUp)
                        } label: {
                            Text(followUp)
                                .font(.caption)
                                .foregroundColor(primaryColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(primaryColor.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - StreamingIndicator

/// Pulsing indicator shown during response generation.
private struct StreamingIndicator: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var dotOpacity: Double = 0.3

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(primaryColor)
                .frame(width: 8, height: 8)
                .opacity(dotOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        dotOpacity = 1.0
                    }
                }

            Text("Generating response...")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                viewModel.stopStream()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.5))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Stop generating")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
    }
}

// MARK: - ErrorBanner

/// Error card with a warning icon, message, and optional retry button.
private struct ErrorBanner: View {
    let message: String
    let retryable: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            if retryable {
                Button {
                    onRetry()
                } label: {
                    Text("Retry")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(primaryColor)
                        )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
