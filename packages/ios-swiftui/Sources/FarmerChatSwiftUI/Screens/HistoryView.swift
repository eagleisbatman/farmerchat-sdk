import SwiftUI

/// Chat history view (data fetched from server).
///
/// Displays a list of past conversations. Tapping a conversation loads its messages
/// into the chat and navigates back to the chat screen.
struct HistoryView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isLoading = true
    @State private var conversations: [ConversationResponse] = []
    @State private var errorMessage: String?

    private var themeColor: Color {
        let config = FarmerChat.getConfig()
        return colorFromHex(config.theme?.primaryColor ?? "#1B6B3A")
    }

    private var cornerRadius: Double {
        FarmerChat.getConfig().theme?.cornerRadius ?? 12
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button {
                    viewModel.navigateTo(screen: .chat)
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
            if isLoading {
                Spacer()
                ProgressView("Loading history...")
                    .foregroundColor(.secondary)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button {
                        fetchHistory()
                    } label: {
                        Text("Try Again")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themeColor)
                            )
                    }
                }
                Spacer()
            } else if conversations.isEmpty {
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
                        ForEach(conversations, id: \.id) { conversation in
                            ConversationCard(
                                conversation: conversation,
                                themeColor: themeColor,
                                cornerRadius: cornerRadius,
                                onTap: {
                                    loadConversation(conversation)
                                }
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
            fetchHistory()
        }
    }

    // MARK: - Actions

    private func fetchHistory() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let client = FarmerChat.shared.apiClient else {
                    errorMessage = "SDK not initialized"
                    isLoading = false
                    return
                }

                let result = try await client.getHistory()
                conversations = result
                isLoading = false
            } catch {
                errorMessage = "Could not load history. Please check your connection."
                isLoading = false
            }
        }
    }

    private func loadConversation(_ conversation: ConversationResponse) {
        viewModel.loadHistory()
        viewModel.navigateTo(screen: .chat)
    }
}

// MARK: - ConversationCard

/// A card representing a single conversation in the history list.
private struct ConversationCard: View {
    let conversation: ConversationResponse
    let themeColor: Color
    let cornerRadius: Double
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
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

                if let preview = lastMessagePreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.4))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }

    /// Use conversation title if available, otherwise derive from first message.
    private var conversationTitle: String {
        if !conversation.title.isEmpty {
            return conversation.title
        }
        if let first = conversation.messages.first {
            return String(first.text.prefix(60))
        }
        return "Conversation"
    }

    /// Preview text from the last message.
    private var lastMessagePreview: String? {
        guard let last = conversation.messages.last else { return nil }
        let text = last.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(120))
    }

    /// Format the conversation date for display.
    private var formattedDate: String {
        let timestamp = conversation.updatedAt > 0 ? conversation.updatedAt : conversation.createdAt
        guard timestamp > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
