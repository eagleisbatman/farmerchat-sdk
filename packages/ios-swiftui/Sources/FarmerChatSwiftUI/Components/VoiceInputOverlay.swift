import SwiftUI
import AVFoundation

/// Full-screen voice recording overlay.
/// Records audio with AVAudioRecorder and returns raw Data to onConfirm.
struct VoiceInputOverlay: View {

    var onConfirm: (Data) -> Void
    var onCancel: () -> Void

    @State private var recorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var state: OverlayState = .requestingPermission
    @State private var errorMessage: String?

    private enum OverlayState { case requestingPermission, recording, processing, error(String) }

    private let green = Color(red: 0.18, green: 0.49, blue: 0.20)

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 32) {
                Text("Voice Input")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                switch state {
                case .requestingPermission:
                    ProgressView().progressViewStyle(.circular).tint(.white)
                    Text("Requesting microphone…").foregroundColor(.white.opacity(0.7))

                case .recording:
                    WaveformView()
                    Text("Speak your question clearly")
                        .foregroundColor(.white.opacity(0.7))
                    HStack(spacing: 32) {
                        CircleButton(icon: "xmark", color: Color.red.opacity(0.8), size: 64) { cancelRecording() }
                        CircleButton(icon: "checkmark", color: green, size: 72) { stopRecording() }
                    }

                case .processing:
                    ProgressView().progressViewStyle(.circular).tint(green)
                    Text("Processing…").foregroundColor(.white.opacity(0.7))

                case .error(let msg):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44)).foregroundColor(.orange)
                    Text(msg).foregroundColor(.white).multilineTextAlignment(.center)
                    CircleButton(icon: "xmark", color: .gray, size: 56) { onCancel() }
                }
            }
            .padding(40)
        }
        .onAppear { requestPermissionAndRecord() }
    }

    private func requestPermissionAndRecord() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted { startRecording() }
                else { state = .error("Microphone permission denied.\nPlease enable it in Settings.") }
            }
        }
    }

    private func startRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            let dir = FileManager.default.temporaryDirectory
            let url = dir.appendingPathComponent("fc_recording_\(UUID().uuidString).m4a")
            recordingURL = url
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            state = .recording
        } catch {
            state = .error("Could not start recording:\n\(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        recorder?.stop()
        recorder = nil
        state = .processing
        guard let url = recordingURL,
              let data = try? Data(contentsOf: url) else {
            state = .error("Could not read audio file.")
            return
        }
        try? FileManager.default.removeItem(at: url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onConfirm(data)
        }
    }

    private func cancelRecording() {
        recorder?.stop()
        recorder = nil
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        onCancel()
    }
}

private struct CircleButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(color)
                .clipShape(Circle())
        }
    }
}

private struct WaveformView: View {
    @State private var phase: Double = 0
    let bars = 9
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<bars, id: \.self) { i in
                let height = 20 + 28 * abs(sin(phase + Double(i) * .pi / Double(bars)))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.18, green: 0.49, blue: 0.20))
                    .frame(width: 5, height: CGFloat(height))
            }
        }
        .frame(height: 56)
        .onAppear {
            withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
