import SwiftUI

/// AI response card — light system theme.
///
/// Layout:
///   HStack(left-aligned)
///   ├── leaf.circle.fill avatar 32pt
///   └── VStack
///       ├── Bubble (systemGray6, 18pt radius top-left 4pt)
///       │   └── MarkdownContent
///       ├── "Related questions" + vertical Ask list
///       └── Listen button (TTS pill)
struct ResponseCard: View {

    let message: ChatViewModel.ChatMessage
    var isStreaming: Bool = false
    var onFollowUpClick: (String) -> Void = { _ in }
    var onFeedback: (String) -> Void = { _ in }

    @State private var feedbackRating: String?
    @State private var listenState: ListenState = .idle

    private var primaryColor: Color { colorFromHex(FarmerChat.getConfig().theme?.primaryColor ?? "#2E7D32") }

    enum ListenState { case idle, loading, playing }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar — leaf icon 32pt circle
            ZStack {
                Circle()
                    .fill(primaryColor)
                    .frame(width: 32, height: 32)
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 8) {
                // AI bubble — systemGray6, corners 18pt except top-left = 4pt
                VStack(alignment: .leading, spacing: 0) {
                    MarkdownContent(text: message.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .background(Color(.systemGray6))
                .clipShape(
                    RoundedCornerShape2(topLeft: 4, topRight: 18, bottomLeft: 18, bottomRight: 18)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)

                // ── Related questions ────────────────────────────────────────
                if !isStreaming && !message.followUps.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Related questions")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        ForEach(Array(message.followUps.enumerated()), id: \.offset) { idx, followUp in
                            if idx > 0 { Divider().padding(.leading, 16) }
                            HStack {
                                Text(followUp.question)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                Spacer()
                                Button("Ask") {
                                    onFollowUpClick(followUp.question)
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(primaryColor)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                    }
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // ── Action row — Listen pill ──────────────────────────────────
                if !isStreaming && !message.hideTtsSpeaker {
                    ListenButton(state: listenState) {
                        listenState = .loading
                        // TTS called from parent — placeholder
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Listen button

private struct ListenButton: View {
    let state: ResponseCard.ListenState
    let onTap: () -> Void

    private var primaryColor: Color { colorFromHex(FarmerChat.getConfig().theme?.primaryColor ?? "#2E7D32") }

    var body: some View {
        Button(action: onTap) {
            Group {
                switch state {
                case .idle:
                    Label("Listen", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(primaryColor)
                case .loading:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: primaryColor))
                        .frame(width: 16, height: 16)
                case .playing:
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(primaryColor)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(Capsule().stroke(primaryColor, lineWidth: 1))
    }
}

// MARK: - FlowLayout (used by chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangeSubviews(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private struct Result { let size: CGSize; let positions: [CGPoint] }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> Result {
        let maxW = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, totalW: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxW && x > 0 { x = 0; y += lineH + lineSpacing; lineH = 0 }
            positions.append(CGPoint(x: x, y: y))
            lineH = max(lineH, s.height)
            x += s.width + spacing
            totalW = max(totalW, x - spacing)
        }
        return Result(size: CGSize(width: totalW, height: y + lineH), positions: positions)
    }
}
