import SwiftUI

// MARK: - Platform Color Helpers

/// Border color for the text field, adapting to platform.
private var inputBorderColor: Color {
    #if os(iOS)
    return Color(.systemGray4)
    #else
    return Color.gray.opacity(0.3)
    #endif
}

/// Background color for the input bar surface.
private var inputSurfaceColor: Color {
    #if os(iOS)
    return Color(.systemBackground)
    #else
    return Color(nsColor: .windowBackgroundColor)
    #endif
}

/// Chat input bar with text, voice, and camera inputs.
///
/// Displays a text field with an adaptive trailing button: voice (mic) when the
/// field is empty, send (arrow) when text is present. An optional camera button
/// appears to the left.
///
/// Port of `InputBar.kt` from the Android Compose SDK.
struct InputBar: View {

    var enabled: Bool = true
    var onSend: (String) -> Void
    var voiceEnabled: Bool = true
    var cameraEnabled: Bool = true

    @State private var text = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Camera button (if enabled)
            if cameraEnabled {
                Button {
                    // TODO: launch image picker
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 36, height: 36)
                }
                .disabled(!enabled)
                .accessibilityLabel("Attach image")
            }

            // Text field with rounded border
            TextField("Ask about farming\u{2026}", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(inputBorderColor, lineWidth: 1)
                )
                .disabled(!enabled)

            // Voice or Send button
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && voiceEnabled {
                Button {
                    // TODO: voice input
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 36, height: 36)
                }
                .disabled(!enabled)
                .accessibilityLabel("Voice input")
            } else {
                Button {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSend(trimmed)
                    text = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            enabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(red: 0.106, green: 0.420, blue: 0.227) // #1B6B3A
                                : Color.secondary
                        )
                        .frame(width: 36, height: 36)
                }
                .disabled(!enabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(inputSurfaceColor)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: -2)
        .opacity(enabled ? 1.0 : 0.5)
    }
}
