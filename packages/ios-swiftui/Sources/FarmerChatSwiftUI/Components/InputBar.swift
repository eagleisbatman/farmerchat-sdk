import SwiftUI

/// Chat input bar — light theme.
///
/// Layout: Camera circle → TextField (20pt radius pill, secondarySystemBg) → Mic/Send icon.
/// Padding: h 12, v 10.
struct InputBar: View {

    var enabled: Bool = true
    var onSend: (String) -> Void
    var onSendWithImage: ((String, String) -> Void)? = nil
    var selectedImageBase64: String? = nil
    var onMicTap: (() -> Void)? = nil
    var onCameraTap: (() -> Void)? = nil
    var voiceEnabled: Bool = true
    var cameraEnabled: Bool = true

    @State private var text = ""

    private var primaryColor: Color {
        colorFromHex(FarmerChat.getConfig().theme?.primaryColor ?? "#2E7D32")
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasText: Bool { !trimmed.isEmpty }
    private var canSend: Bool { hasText || selectedImageBase64 != nil }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {

                // Camera circle button
                if cameraEnabled {
                    Button {
                        onCameraTap?()
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .disabled(!enabled)
                    .accessibilityLabel("Attach photo")
                }

                // Multi-line text field (20pt radius, secondarySystemBg)
                TextField("Ask about your crops…", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .disabled(!enabled)

                // Mic → Send (primary green circle)
                if canSend {
                    Button {
                        guard enabled else { return }
                        if let b64 = selectedImageBase64 {
                            onSendWithImage?(trimmed, b64)
                        } else if hasText {
                            onSend(trimmed)
                        }
                        text = ""
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(enabled ? primaryColor : Color.gray)
                            .clipShape(Circle())
                    }
                    .disabled(!enabled)
                    .accessibilityLabel("Send message")
                } else if voiceEnabled {
                    Button {
                        onMicTap?()
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                            .frame(width: 36, height: 36)
                    }
                    .disabled(!enabled)
                    .accessibilityLabel("Voice input")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color(.systemBackground))
        }
        .opacity(enabled ? 1.0 : 0.6)
    }
}
