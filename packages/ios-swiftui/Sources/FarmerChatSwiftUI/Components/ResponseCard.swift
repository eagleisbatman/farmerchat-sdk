import SwiftUI

/// AI response card with markdown rendering and action bar.
///
/// Displays the assistant avatar, rendered markdown content, optional follow-up
/// suggestion chips, and a feedback action row (thumbs up/down + share).
///
/// Port of `ResponseCard.kt` from the Android Compose SDK.
struct ResponseCard: View {

    let message: ChatViewModel.ChatMessage
    var isStreaming: Bool = false
    var onFollowUpClick: (String) -> Void = { _ in }
    var onFeedback: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Avatar + content row
            HStack(alignment: .top, spacing: 8) {
                // Small green circle avatar with "FC"
                ZStack {
                    Circle()
                        .fill(Color(red: 0.106, green: 0.420, blue: 0.227)) // #1B6B3A
                        .frame(width: 28, height: 28)

                    Text("FC")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Markdown rendered content
                    MarkdownContent(text: message.text)

                    // Blinking cursor while streaming
                    if isStreaming {
                        BlinkingCursor()
                    }
                }
            }

            // Follow-up chips (only when not streaming and followUps present)
            if !isStreaming && !message.followUps.isEmpty {
                FollowUpChips(
                    followUps: message.followUps,
                    onTap: onFollowUpClick
                )
                .padding(.leading, 36)
                .padding(.top, 8)
            }

            // Action bar (only when not streaming)
            if !isStreaming {
                ActionBar(
                    feedbackRating: message.feedbackRating,
                    onFeedback: onFeedback
                )
                .padding(.leading, 36)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Follow-Up Chips

/// Horizontally wrapping row of tappable suggestion chips.
private struct FollowUpChips: View {

    let followUps: [String]
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 4) {
            ForEach(followUps, id: \.self) { followUp in
                Button {
                    onTap(followUp)
                } label: {
                    Text(followUp)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.106, green: 0.420, blue: 0.227))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 0.106, green: 0.420, blue: 0.227).opacity(0.4), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Follow up: \(followUp)")
            }
        }
    }
}

// MARK: - Action Bar

/// Thumbs up, thumbs down, and share buttons.
private struct ActionBar: View {

    let feedbackRating: String?
    let onFeedback: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Thumbs up
            Button {
                onFeedback("positive")
            } label: {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        feedbackRating == "positive"
                            ? Color(red: 0.106, green: 0.420, blue: 0.227)
                            : Color.secondary
                    )
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Helpful")

            // Thumbs down
            Button {
                onFeedback("negative")
            } label: {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        feedbackRating == "negative"
                            ? Color.red
                            : Color.secondary
                    )
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Not helpful")

            // Share
            Button {
                // TODO: share message text via UIActivityViewController
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Share")

            Spacer()
        }
    }
}

// MARK: - Blinking Cursor

/// A small pulsing rectangle that indicates the stream is still producing tokens.
private struct BlinkingCursor: View {

    @State private var isVisible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color(red: 0.106, green: 0.420, blue: 0.227))
            .frame(width: 8, height: 16)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: isVisible
            )
            .onAppear { isVisible = false }
            .padding(.top, 2)
    }
}

// MARK: - FlowLayout

/// A horizontal wrapping layout (replacement for Compose's FlowRow).
///
/// Lays children out left-to-right, wrapping to the next line when
/// the current line exceeds the available width.
private struct FlowLayout: Layout {

    var spacing: CGFloat
    var lineSpacing: CGFloat

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

    private struct ArrangementResult {
        let size: CGSize
        let positions: [CGPoint]
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Wrap to next line
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        let totalHeight = currentY + lineHeight
        return ArrangementResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            positions: positions
        )
    }
}
