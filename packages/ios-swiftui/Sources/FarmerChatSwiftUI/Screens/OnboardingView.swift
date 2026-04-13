import SwiftUI

// MARK: - OnboardingView

/// Two-step onboarding:
///   Step 1 — Region auto-detected (IP geolocation from initialize_user). NO GPS permission.
///   Step 2 — Language selection
struct OnboardingView: View {
    @ObservedObject var viewModel: ChatViewModel

    @State private var step: Int = 1
    @State private var langLoadError: Bool = false

    private var themeColor: Color {
        colorFromHex(FarmerChat.getConfig().theme?.primaryColor ?? "#2E7D32")
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────────
            VStack(spacing: 10) {
                Spacer().frame(height: 52)

                ZStack {
                    Circle()
                        .fill(themeColor)
                        .frame(width: 72, height: 72)
                    Text("🌱")
                        .font(.system(size: 36))
                }

                Text("FarmChat AI")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)

                Text("Smart Farming Assistant")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 28)
            .background(themeColor)

            // ── Step indicator ────────────────────────────────────────────────
            HStack(spacing: 6) {
                Capsule().fill(step == 1 ? themeColor : Color.gray.opacity(0.3))
                    .frame(width: step == 1 ? 24 : 16, height: 6)
                Capsule().fill(step == 2 ? themeColor : Color.gray.opacity(0.3))
                    .frame(width: step == 2 ? 24 : 16, height: 6)
            }
            .padding(.top, 16)

            // ── Content ────────────────────────────────────────────────────────
            if step == 1 {
                RegionDetectedStep(themeColor: themeColor)
            } else {
                LanguageStep(
                    viewModel: viewModel,
                    themeColor: themeColor,
                    hasError: langLoadError && viewModel.availableLanguageGroups.isEmpty,
                    onRetry: {
                        langLoadError = false
                        viewModel.loadLanguages()
                    }
                )
            }

            Spacer()

            // ── Primary button ────────────────────────────────────────────────
            VStack(spacing: 12) {
                if step == 1 {
                    Button { step = 2 } label: {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 26).fill(themeColor))
                    }
                } else {
                    Button {
                        viewModel.navigateTo(.chat)
                    } label: {
                        Text("Get Started")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 26)
                                    .fill(viewModel.selectedLanguage.isEmpty
                                          ? themeColor.opacity(0.35) : themeColor)
                            )
                    }
                    .disabled(viewModel.selectedLanguage.isEmpty)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if viewModel.availableLanguageGroups.isEmpty {
                viewModel.loadLanguages()
            }
        }
        .onChange(of: step) { newStep in
            if newStep == 2 && viewModel.availableLanguageGroups.isEmpty {
                langLoadError = false
                viewModel.loadLanguages()
            }
        }
    }
}

// MARK: - Region Detected Step (replaces GPS permission step)

/// Shows the region auto-detected via IP geolocation (initialize_user).
/// Per WEATHER_GPS_FLOW spec — no CLLocationManager / no GPS permission.
private struct RegionDetectedStep: View {
    let themeColor: Color

    private var locationLabel: String {
        let country = TokenStore.shared.country
        let state   = TokenStore.shared.state
        if !state.isEmpty && !country.isEmpty { return "\(state), \(country)" }
        if !country.isEmpty { return country }
        return "Your Region"
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 24)

            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(themeColor)
            }

            Text("Your Region")
                .font(.system(size: 20, weight: .semibold))

            // Show the IP-detected region as a pill badge
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(themeColor)
                    .font(.system(size: 14))
                Text(locationLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(themeColor.opacity(0.12))
                    .overlay(Capsule().stroke(themeColor.opacity(0.4), lineWidth: 1))
            )

            Text("Your region was automatically detected from your network. This helps us recommend farming advice relevant to your area.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Language step

private struct LanguageStep: View {
    @ObservedObject var viewModel: ChatViewModel
    let themeColor: Color
    let hasError: Bool
    let onRetry: () -> Void

    private var languages: [SupportedLanguage] {
        viewModel.availableLanguageGroups.flatMap(\.languages)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECT YOUR LANGUAGE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.8)
                .foregroundColor(themeColor)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            if hasError {
                VStack(spacing: 12) {
                    Text("Could not load languages")
                        .foregroundColor(.secondary)
                    Button("Retry", action: onRetry)
                        .foregroundColor(themeColor)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else if languages.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .frame(height: 200)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(languages) { language in
                            LanguageCard(
                                language: language,
                                isSelected: language.code == viewModel.selectedLanguage,
                                themeColor: themeColor,
                                onSelect: { viewModel.setPreferredLanguage(language) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

// MARK: - Language card

private struct LanguageCard: View {
    let language: SupportedLanguage
    let isSelected: Bool
    let themeColor: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? themeColor : Color.gray.opacity(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName.isEmpty ? language.name : language.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if language.name != language.displayName && !language.name.isEmpty {
                        Text(language.name)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    ZStack {
                        Circle().fill(themeColor).frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    Spacer().frame(width: 20, height: 20)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? themeColor.opacity(0.10) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? themeColor : Color.gray.opacity(0.15),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
