import SwiftUI
import CoreLocation

// MARK: - LocationHelper

private final class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationObtained: Bool = false
    @Published var locationDenied: Bool = false

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() { manager.requestWhenInUseAuthorization() }
    func requestLocation()   { manager.requestLocation() }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations _: [CLLocation]) {
        locationObtained = true
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError _: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocation()
        case .denied, .restricted:
            locationDenied = true
        default:
            break
        }
    }
}

// MARK: - OnboardingView

/// Two-step onboarding:
///   Step 1 — Location permission
///   Step 2 — Language selection
struct OnboardingView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var locationHelper = LocationHelper()

    @State private var step: Int = 1

    private var themeColor: Color {
        colorFromHex(FarmerChat.getConfig().theme?.primaryColor ?? "#2E7D32")
    }

    private var hasPermission: Bool {
        switch locationHelper.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
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
                LocationStep(
                    locationHelper: locationHelper,
                    hasPermission: hasPermission,
                    themeColor: themeColor,
                    onSkip: { step = 2 },
                    onContinue: { step = 2 }
                )
            } else {
                LanguageStep(
                    viewModel: viewModel,
                    themeColor: themeColor
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
            if step == 2 && viewModel.availableLanguageGroups.isEmpty {
                viewModel.loadLanguages()
            }
        }
        .onChange(of: step) { newStep in
            if newStep == 2 && viewModel.availableLanguageGroups.isEmpty {
                viewModel.loadLanguages()
            }
        }
    }
}

// MARK: - Location step

private struct LocationStep: View {
    @ObservedObject var locationHelper: LocationHelper
    let hasPermission: Bool
    let themeColor: Color
    let onSkip: () -> Void
    let onContinue: () -> Void

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

            Text("Share Your Location")
                .font(.system(size: 20, weight: .semibold))

            Text("Your location helps us provide accurate, region-specific agricultural advice for your area.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if locationHelper.locationDenied {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text("Location denied. You can change this in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 32)
            }

            if hasPermission {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeColor)
                    Text("Location permission granted")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Button {
                    locationHelper.requestPermission()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        Text("Share Location")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeColor)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(themeColor, lineWidth: 1.5))
                }

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Language step

private struct LanguageStep: View {
    @ObservedObject var viewModel: ChatViewModel
    let themeColor: Color

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

            if languages.isEmpty {
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
