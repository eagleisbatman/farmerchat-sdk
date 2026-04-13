import SwiftUI

// ── Dark palette (mirrors Compose / React Native) ──────────────────────────────
private let historyBg       = Color(red: 0.059, green: 0.102, blue: 0.051) // #0F1A0D
private let historyToolbar  = Color(red: 0.102, green: 0.137, blue: 0.094) // #1A2318
private let historyCard     = Color(red: 0.090, green: 0.133, blue: 0.075) // #172213
private let historyLabel    = Color(red: 0.290, green: 0.369, blue: 0.282) // #4A5E48
private let textPrimary     = Color(red: 0.910, green: 0.961, blue: 0.914) // #E8F5E9
private let textSecondary   = Color(red: 0.561, green: 0.659, blue: 0.549) // #8FA88C
private let textMuted       = Color(red: 0.353, green: 0.420, blue: 0.345) // #5A6B58
private let accentGreen     = Color(red: 0.298, green: 0.686, blue: 0.314) // #4CAF50

/// Chat history view — dark forest theme.
///
/// Displays past conversations grouped by date section.
/// Tapping a conversation loads it into the chat screen.
struct HistoryView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var searchQuery = ""

    var body: some View {
        ZStack {
            historyBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Toolbar ────────────────────────────────────────────────────
                HStack(spacing: 12) {
                    Button {
                        viewModel.navigateTo(.chat)
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                    .accessibilityLabel("Back to chat")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chat History")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(textPrimary)
                        Text("Your farming conversations")
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                    }

                    Spacer()

                    // New conversation button
                    Button {
                        viewModel.startNewConversation()
                        viewModel.navigateTo(.chat)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(accentGreen)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("New conversation")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .top) {
                    historyToolbar.ignoresSafeArea(edges: .top)
                }

                // ── Search bar ─────────────────────────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(textMuted)
                    TextField("Search conversations...", text: $searchQuery)
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary)
                        .accentColor(accentGreen)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(red: 0.141, green: 0.188, blue: 0.125)) // #243020
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(historyBg)

                // ── Content ────────────────────────────────────────────────────
                let filtered = searchQuery.isEmpty
                    ? viewModel.conversationList
                    : viewModel.conversationList.filter {
                        ($0.conversationTitle ?? "").localizedCaseInsensitiveContains(searchQuery)
                    }

                if viewModel.historyLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accentGreen))
                        .scaleEffect(1.4)
                    Spacer()
                } else if filtered.isEmpty {
                    EmptyHistoryState()
                } else {
                    let grouped = Dictionary(grouping: filtered) { $0.grouping ?? "Older" }
                    let sortedKeys = grouped.keys.sorted(by: >)

                    List {
                        ForEach(sortedKeys, id: \.self) { key in
                            Section(header:
                                Text(key.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(historyLabel)
                                    .kerning(1.5)
                            ) {
                                ForEach(grouped[key] ?? []) { conversation in
                                    ConversationRow(
                                        conversation: conversation,
                                        onTap: { viewModel.loadConversation(conversation) }
                                    )
                                    .listRowBackground(historyCard)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        viewModel.loadConversationList()
                    }
                }
            }
        }
        .task {
            viewModel.loadConversationList()
        }
    }
}

// MARK: - Conversation row

private struct ConversationRow: View {
    let conversation: ConversationListItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon circle 44pt
                ZStack {
                    Circle()
                        .fill(accentGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(topicEmoji(conversation.conversationTitle))
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        (conversation.conversationTitle?.trimmingCharacters(in: .whitespaces)
                            .isEmpty == false)
                        ? conversation.conversationTitle!
                        : "Conversation"
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)

                    Text(formatRelativeDate(conversation.createdOn))
                        .font(.system(size: 11))
                        .foregroundColor(textMuted)
                }

                Spacer()

                Text("›")
                    .font(.system(size: 20))
                    .foregroundColor(historyLabel)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(historyCard)
            .cornerRadius(14)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty state

private struct EmptyHistoryState: View {
    var body: some View {
        Spacer()
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentGreen.opacity(0.10))
                    .frame(width: 90, height: 90)
                Text("💬").font(.system(size: 40))
            }
            Text("No conversations yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)
            Text("Your past conversations will appear here")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        Spacer()
    }
}

// MARK: - Date formatting

private func formatRelativeDate(_ dateStr: String?) -> String {
    guard let str = dateStr, !str.isEmpty else { return "" }
    let normalized = str
        .replacingOccurrences(of: "T", with: " ")
        .components(separatedBy: "Z").first?
        .components(separatedBy: "+").first?
        .trimmingCharacters(in: .whitespaces) ?? str
    let trimmed = normalized.count > 19 ? String(normalized.prefix(19)) : normalized

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = TimeZone(identifier: "UTC")
    guard let date = formatter.date(from: trimmed) else { return str }

    let secs = Date().timeIntervalSince(date)
    if secs < 0     { let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date) }
    if secs < 60    { return "Just now" }
    if secs < 3600  { return "\(Int(secs / 60))m ago" }
    if secs < 86400 { return "\(Int(secs / 3600))h ago" }
    if secs < 172800 { return "Yesterday" }
    if secs < 604800 { return "\(Int(secs / 86400))d ago" }
    let display = DateFormatter()
    display.dateFormat = "MMM d"
    return display.string(from: date)
}

// MARK: - Topic emoji helper

private func topicEmoji(_ title: String?) -> String {
    let t = title?.lowercased() ?? ""
    if t.contains("tomato") || t.contains("vegetable") { return "🍅" }
    if t.contains("weather") || t.contains("rain")     { return "🌧️" }
    if t.contains("soil") || t.contains("npk")         { return "🌱" }
    if t.contains("irrigation") || t.contains("water") { return "💧" }
    if t.contains("fertilizer") || t.contains("nutrient") { return "🌻" }
    if t.contains("pest") || t.contains("insect")      { return "🐛" }
    if t.contains("wheat") || t.contains("rice") || t.contains("crop") { return "🌾" }
    if t.contains("disease")                            { return "⚠️" }
    return "💬"
}
