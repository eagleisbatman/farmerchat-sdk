import SwiftUI

/// Chat history view — light system theme.
///
/// Displays past conversations grouped (if the server returns a `grouping` field).
/// Tapping a conversation loads it into the chat screen.
struct HistoryView: View {
    @ObservedObject var viewModel: ChatViewModel

    private var primaryColor: Color {
        colorFromHex(FarmerChat.getConfig().theme?.primaryColor ?? "#2E7D32")
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ────────────────────────────────────────────────────────
            HStack(spacing: 12) {
                Button {
                    viewModel.navigateTo(.chat)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("Back to chat")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat History")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Your farming conversations")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // New conversation
                Button {
                    viewModel.startNewConversation()
                    viewModel.navigateTo(.chat)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(primaryColor)
                        .clipShape(Circle())
                }
                .accessibilityLabel("New conversation")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(Divider(), alignment: .bottom)

            // ── Content ────────────────────────────────────────────────────────
            let conversations = viewModel.conversationList

            if viewModel.historyLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: primaryColor))
                    .scaleEffect(1.4)
                Spacer()
            } else if conversations.isEmpty {
                EmptyHistoryState()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(conversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                primaryColor: primaryColor,
                                onTap: { viewModel.loadConversation(conversation) }
                            )
                        }
                    }
                }
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .task {
            viewModel.loadConversationList()
        }
    }
}

// MARK: - Conversation row

private struct ConversationRow: View {
    let conversation: ConversationListItem
    let primaryColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon circle 40pt
                ZStack {
                    Circle()
                        .fill(primaryColor.opacity(0.10))
                        .frame(width: 40, height: 40)
                    Text(topicEmoji(conversation.conversationTitle))
                        .font(.system(size: 18))
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.conversationTitle ?? "Conversation")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Text(formatRelativeDate(conversation.createdOn))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Divider()
            .padding(.leading, 68)
    }
}

// MARK: - Empty state

private struct EmptyHistoryState: View {
    var body: some View {
        Spacer()
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.18, green: 0.49, blue: 0.20).opacity(0.10))
                    .frame(width: 90, height: 90)
                Text("💬").font(.system(size: 40))
            }
            Text("No conversations yet")
                .font(.system(size: 18, weight: .semibold))
            Text("Your past conversations will appear here")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        Spacer()
    }
}

// MARK: - Date formatting

private func formatRelativeDate(_ dateStr: String?) -> String {
    guard let str = dateStr, !str.isEmpty else { return "" }
    let formatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
        ]
        return patterns.map { p in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = p
            return f
        }
    }()
    var date: Date?
    for f in formatters {
        if let d = f.date(from: str) { date = d; break }
    }
    guard let d = date else { return str }
    let now = Date()
    let secs = now.timeIntervalSince(d)
    if secs < 60 { return "Just now" }
    if secs < 3600 { return "\(Int(secs / 60))m ago" }
    if secs < 86400 { return "\(Int(secs / 3600))h ago" }
    if secs < 172800 { return "Yesterday" }
    let display = DateFormatter()
    display.dateFormat = "MMM d"
    return display.string(from: d)
}

// MARK: - Topic emoji helper

private func topicEmoji(_ title: String?) -> String {
    let t = title?.lowercased() ?? ""
    if t.contains("tomato") || t.contains("vegetable") { return "🍅" }
    if t.contains("weather") || t.contains("rain") { return "🌧️" }
    if t.contains("soil") || t.contains("npk") { return "🌱" }
    if t.contains("irrigation") || t.contains("water") { return "💧" }
    if t.contains("fertilizer") || t.contains("nutrient") { return "🌻" }
    if t.contains("pest") || t.contains("insect") { return "🐛" }
    if t.contains("wheat") || t.contains("rice") || t.contains("crop") { return "🌾" }
    if t.contains("disease") { return "⚠️" }
    return "💬"
}
