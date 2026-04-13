import AVFoundation
import SwiftUI

/// AI response card — dark theme.
///
/// Layout:
///   HStack(left-aligned)
///   ├── leaf.circle.fill avatar 32pt
///   └── VStack
///       ├── Bubble (systemGray6, 18pt radius top-left 4pt)
///       │   └── MarkdownContent
///       ├── "Related questions" + vertical Ask list
///       └── HStack: Listen pill + Copy circle
struct ResponseCard: View {

    let message: ChatViewModel.ChatMessage
    var isStreaming: Bool = false
    var onFollowUpClick: (String) -> Void = { _ in }
    var onFeedback: (String) -> Void = { _ in }
    /// Called when Listen is tapped. Returns the audio URL or nil on failure.
    var onSynthesise: ((String, String) async -> String?)? = nil

    @State private var feedbackRating: String?
    @State private var listenState: ListenState = .idle
    @State private var audioPlayer: AVPlayer? = nil
    @State private var playerObserver: Any? = nil
    @State private var isCopied = false

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
                // AI bubble
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
                                Button("Ask") { onFollowUpClick(followUp.question) }
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

                // ── Action row — Listen pill + Copy circle ────────────────────
                if !isStreaming {
                    HStack(spacing: 8) {
                        if !message.hideTtsSpeaker && !(message.serverMessageId ?? "").isEmpty {
                            ListenButton(state: listenState, primaryColor: primaryColor) {
                                handleListenTap()
                            }
                        }

                        // Copy button — circle
                        Button {
                            UIPasteboard.general.string = message.text
                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
                        } label: {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13))
                                .foregroundColor(isCopied ? primaryColor : Color.secondary)
                                .frame(width: 30, height: 30)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onDisappear { stopAudio() }
    }

    // MARK: - Listen helpers

    private func handleListenTap() {
        switch listenState {
        case .idle:
            guard let msgId = message.serverMessageId, !msgId.isEmpty else { return }
            listenState = .loading
            Task {
                do {
                    let url = await onSynthesise?(msgId, message.text)
                    await MainActor.run {
                        if let url, let avUrl = URL(string: url) {
                            playAudio(url: avUrl)
                        } else {
                            listenState = .idle
                        }
                    }
                }
            }
        case .playing:
            stopAudio()
        case .loading:
            break
        }
    }

    private func playAudio(url: URL) {
        stopAudio()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        audioPlayer = player
        player.play()
        listenState = .playing
        // Observe end-of-playback
        let obs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            listenState = .idle
        }
        playerObserver = obs
    }

    private func stopAudio() {
        audioPlayer?.pause()
        audioPlayer = nil
        if let obs = playerObserver {
            NotificationCenter.default.removeObserver(obs)
            playerObserver = nil
        }
        listenState = .idle
    }
}

// MARK: - Listen button

private struct ListenButton: View {
    let state: ResponseCard.ListenState
    let primaryColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                switch state {
                case .idle:
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                    Text("Listen")
                        .font(.system(size: 13, weight: .medium))
                case .loading:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: primaryColor))
                        .scaleEffect(0.7)
                    Text("Loading…")
                        .font(.system(size: 11))
                case .playing:
                    Image(systemName: "stop.fill")
                        .font(.caption)
                    Text("Stop")
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .foregroundColor(primaryColor)
        }
        .disabled(state == .loading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(Capsule().stroke(primaryColor, lineWidth: 1))
        .buttonStyle(.plain)
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
