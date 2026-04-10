import SwiftUI

/// Chat history view — displays the user's past conversations.
///
/// Tapping a conversation loads its messages into the chat screen.
struct HistoryView: View {
    @ObservedObject var viewModel: ChatViewModel

    private var themeColor: Color {
        colorFromHex(FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
    }

    private var cornerRadius: Double {
        FarmerChat.getConfig().theme?.cornerRadius ?? 12
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

                Text("Chat History")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeColor)

            // Content
            let conversations = viewModel.conversationList
            if conversations.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(Color.gray.opacity(0.5))
                    Text("No conversations yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("Start chatting to see your history here.")
                        .font(.caption)
                        .foregroundColor(Color.gray.opacity(0.4))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(conversations) { conversation in
                            ConversationCard(
                                conversation: conversation,
                                themeColor: themeColor,
                                cornerRadius: cornerRadius,
                                onTap: { viewModel.loadConversation(conversation) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(white: 0.95))
        .task {
            viewModel.loadConversationList()
        }
    }
}

// MARK: - ConversationCard

private struct ConversationCard: View {
    let conversation: ConversationListItem
    let themeColor: Color
    let cornerRadius: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(conversationTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color.gray.opacity(0.5))
                }
                Text(conversation.createdOn ?? "")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.4))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius).fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var conversationTitle: String {
        if let title = conversation.conversationTitle, !title.isEmpty { return title }
        return "Conversation"
    }
}
