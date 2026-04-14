import SwiftUI
import UIKit

// MARK: - Dark palette (matches Compose / Views dark theme)

private let darkBg       = Color(red: 0.059, green: 0.102, blue: 0.051)  // #0F1A0D
private let darkSurface  = Color(red: 0.102, green: 0.137, blue: 0.094)  // #1A2318
private let darkSurface2 = Color(red: 0.141, green: 0.188, blue: 0.125)  // #243020
private let textPrimary  = Color(red: 0.910, green: 0.961, blue: 0.914)  // #E8F5E9
private let textSecondary = Color(red: 0.561, green: 0.659, blue: 0.549) // #8FA88C
private let onlineDot    = Color(red: 0.412, green: 0.941, blue: 0.682)  // #69F0AE
private let lightGreen   = Color(red: 0.298, green: 0.686, blue: 0.314)  // #4CAF50

private var primaryColor: Color {
    colorFromHex(FarmerChat.getConfig().theme?.primaryColor ?? "#4CAF50")
}
private var cardCornerRadius: Double {
    FarmerChat.getConfig().theme?.cornerRadius ?? 12
}

// MARK: - ChatView

/// Main chat screen — dark forest-green theme matching Compose and Views SDKs.
///
/// Layout: ChatTopBar → ConnectivityBanner → Messages / EmptyState → InputBar.
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    @State private var showVoiceOverlay = false
    @State private var showImageSourceSheet = false
    @State private var showCameraPicker = false
    @State private var showGalleryPicker = false
    @State private var selectedImageBase64: String? = nil

    private var config: FarmerChatConfig { FarmerChat.getConfig() }

    private var isInputDisabled: Bool {
        if case .sending = viewModel.chatState { return true }
        return false
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.082, green: 0.125, blue: 0.078), darkBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ChatTopBar(viewModel: viewModel)

                if !viewModel.isConnected {
                    ConnectivityBanner()
                }

                // Weather widget — shown when host app supplies weatherTemp in config
                if let weatherTemp = config.weatherTemp, !weatherTemp.isEmpty {
                    WeatherWidgetView(
                        weatherTemp: weatherTemp,
                        weatherLocation: config.weatherLocation,
                        cropName: config.cropName,
                        onTap: {
                            viewModel.sendWeatherQuery("Tell me about farming advice for this weather")
                        }
                    )
                }

                ZStack {
                    if viewModel.messages.isEmpty && selectedImageBase64 == nil {
                        EmptyStateArea()
                    } else {
                        MessageList(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if case let .error(_, message, retryable) = viewModel.chatState {
                    InlineErrorBanner(
                        message: message,
                        retryable: retryable,
                        onRetry: { viewModel.retryLastQuery() }
                    )
                }

                InputBar(
                    enabled:             !isInputDisabled && viewModel.isConnected,
                    onSend:              { text in viewModel.sendQuery(text: text) },
                    onSendWithImage:     { caption, b64 in
                        viewModel.sendQueryWithImage(caption: caption, base64Image: b64)
                        selectedImageBase64 = nil
                    },
                    selectedImageBase64: selectedImageBase64,
                    onMicTap:            { showVoiceOverlay = true },
                    onCameraTap:         { showImageSourceSheet = true },
                    voiceEnabled:        config.voiceInputEnabled,
                    cameraEnabled:       config.imageInputEnabled
                )
            }

            // Voice overlay
            if showVoiceOverlay {
                VoiceInputOverlay(
                    onConfirm: { data in
                        showVoiceOverlay = false
                        viewModel.transcribeAndSendAudio(audioData: data)
                    },
                    onCancel: { showVoiceOverlay = false }
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: showVoiceOverlay)
            }
        }
        .sheet(isPresented: $showImageSourceSheet) {
            ImageSourceSheet(
                onCamera: {
                    showImageSourceSheet = false
                    showCameraPicker = true
                },
                onGallery: {
                    showImageSourceSheet = false
                    showGalleryPicker = true
                },
                onCancel: { showImageSourceSheet = false }
            )
        }
        .sheet(isPresented: $showGalleryPicker) {
            PHImagePicker { image in
                showGalleryPicker = false
                if let b64 = image?.toBase64Jpeg() {
                    selectedImageBase64 = b64
                }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            CameraPicker { image in
                showCameraPicker = false
                if let b64 = image?.toBase64Jpeg() {
                    selectedImageBase64 = b64
                }
            }
        }
        .onAppear {
            // Ensure language list is loaded and auto-sync runs for returning users.
            // Without this, returning users who skip onboarding never call loadLanguages,
            // so the server never receives set_preferred_language and returns response: null.
            viewModel.loadLanguages()
        }
    }
}

// MARK: - ChatTopBar

private struct ChatTopBar: View {
    @ObservedObject var viewModel: ChatViewModel
    private var config: FarmerChatConfig { FarmerChat.getConfig() }

    var body: some View {
        HStack(spacing: 0) {
            // Avatar — 40pt green circle with leaf icon
            ZStack {
                Circle()
                    .fill(lightGreen)
                    .frame(width: 40, height: 40)
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            Spacer().frame(width: 10)

            // Title + online dot + subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(config.headerTitle.isEmpty ? "FarmerChat AI" : config.headerTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Circle()
                        .fill(onlineDot)
                        .frame(width: 7, height: 7)
                }
                Text("Smart Farming Assistant")
                    .font(.system(size: 11))
                    .foregroundColor(textSecondary)
            }

            Spacer()

            // Translate / language icon
            if config.historyEnabled {
                Button {
                    viewModel.navigateTo(.profile)
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 19))
                        .foregroundColor(textSecondary)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Language")
            }

            // History icon
            if config.historyEnabled {
                Button {
                    viewModel.navigateTo(.history)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 19))
                        .foregroundColor(textSecondary)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Chat history")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Extend the dark toolbar color behind the status bar while content stays
        // in the safe area (SwiftUI VStack already pushes content below status bar).
        .background(alignment: .top) {
            darkSurface.ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Empty state

private struct EmptyStateArea: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🌾")
                .font(.system(size: 56))
            Text("Ask a question about farming to get started")
                .font(.system(size: 16))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - Message list

private struct MessageList: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages) { message in
                        if message.role == "user" {
                            UserBubble(message: message)
                                .id(message.id)
                        } else {
                            ResponseCard(
                                message: message,
                                isStreaming: false,
                                onFollowUpClick: { text in viewModel.sendFollowUp(text: text) },
                                onFeedback: { _ in },
                                onSynthesise: { msgId, text in
                                    await viewModel.synthesiseAudio(
                                        serverMessageId: msgId, text: text)
                                }
                            )
                            .id(message.id)
                        }
                    }

                    if case .sending = viewModel.chatState {
                        LoadingBubble()
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

// MARK: - User bubble

private struct UserBubble: View {
    let message: ChatViewModel.ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedCornerShape2(
                            topLeft: 18, topRight: 18,
                            bottomLeft: 18, bottomRight: 4
                        )
                        .fill(lightGreen)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
                Text(message.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Loading bubble (3 animated dots)

struct LoadingBubble: View {
    @State private var scale1: CGFloat = 0.5
    @State private var scale2: CGFloat = 0.5
    @State private var scale3: CGFloat = 0.5

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar
            ZStack {
                Circle().fill(lightGreen).frame(width: 36, height: 36)
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            // Dots bubble
            HStack(spacing: 6) {
                dotView(scale: $scale1)
                dotView(scale: $scale2)
                dotView(scale: $scale3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(darkSurface)
            .clipShape(
                RoundedCornerShape2(topLeft: 4, topRight: 18, bottomLeft: 18, bottomRight: 18)
            )

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onAppear {
            animate(delay: 0.0, scale: $scale1)
            animate(delay: 0.2, scale: $scale2)
            animate(delay: 0.4, scale: $scale3)
        }
    }

    private func dotView(scale: Binding<CGFloat>) -> some View {
        Circle()
            .fill(lightGreen)
            .frame(width: 8, height: 8)
            .scaleEffect(scale.wrappedValue)
    }

    private func animate(delay: Double, scale: Binding<CGFloat>) {
        withAnimation(
            Animation.easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(delay)
        ) {
            scale.wrappedValue = 1.0
        }
    }
}

// MARK: - Inline error banner

private struct InlineErrorBanner: View {
    let message: String
    let retryable: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(red: 0.81, green: 0.40, blue: 0.47))
            Text(message)
                .font(.subheadline)
                .foregroundColor(textPrimary)
                .lineLimit(2)
            Spacer()
            if retryable {
                Button("Retry", action: onRetry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(lightGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(Color(red: 0.24, green: 0.11, blue: 0.13))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(Color(red: 0.81, green: 0.40, blue: 0.47).opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Custom corner radius shape

/// Allows different corner radii per corner (SwiftUI workaround).
struct RoundedCornerShape2: Shape {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = min(topLeft, min(rect.width, rect.height) / 2)
        let tr = min(topRight, min(rect.width, rect.height) / 2)
        let bl = min(bottomLeft, min(rect.width, rect.height) / 2)
        let br = min(bottomRight, min(rect.width, rect.height) / 2)

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - WeatherWidgetView

/// Weather card shown at the top of the chat when the host app provides weather data.
/// Tapping sends a query with weather_cta_triggered = true.
private struct WeatherWidgetView: View {
    let weatherTemp: String
    let weatherLocation: String?
    let cropName: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weatherTemp)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    if let loc = weatherLocation, !loc.isEmpty {
                        Text("📍  \(loc)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.56, green: 0.66, blue: 0.55))
                    }
                }
                Spacer()
                if let crop = cropName, !crop.isEmpty {
                    Text("🌾  \(crop)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.298, green: 0.686, blue: 0.314))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.298, green: 0.686, blue: 0.314).opacity(0.22))
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.090, green: 0.133, blue: 0.075))
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
