import SwiftUI
import CoreLocation

// MARK: - LocationHelper

/// Lightweight CLLocationManager wrapper for requesting location permission and coordinates.
/// Uses delegation via a coordinator pattern suitable for SwiftUI @State lifecycle.
private final class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var locationObtained: Bool = false
    @Published var locationDenied: Bool = false

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        locationObtained = true
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[FC.Onboarding] Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationObtained = false
            requestLocation()
        case .denied, .restricted:
            locationDenied = true
        default:
            break
        }
    }
}

// MARK: - OnboardingView

/// Onboarding view for location and language selection.
///
/// Step 1: Location permission request.
/// Step 2: Language picker from available languages.
/// Calls `viewModel.completeOnboarding` on completion.
struct OnboardingView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var step = 1
    @State private var selectedLanguageCode = ""
    @StateObject private var locationHelper = LocationHelper()

    private var themeColor: Color {
        let config = FarmerChat.getConfig()
        return colorFromHex(config.theme?.primaryColor ?? "#1B6B3A")
    }

    private var cornerRadius: Double {
        FarmerChat.getConfig().theme?.cornerRadius ?? 12
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top progress indicator
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(themeColor)
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(step >= 2 ? themeColor : Color.gray.opacity(0.4))
                    .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)

            if step == 1 {
                LocationStep(
                    locationHelper: locationHelper,
                    themeColor: themeColor,
                    cornerRadius: cornerRadius,
                    onContinue: {
                        step = 2
                    },
                    onSkip: {
                        step = 2
                    }
                )
            } else {
                LanguageStep(
                    viewModel: viewModel,
                    selectedLanguageCode: $selectedLanguageCode,
                    themeColor: themeColor,
                    cornerRadius: cornerRadius,
                    onGetStarted: {
                        viewModel.completeOnboarding(
                            lat: locationHelper.latitude,
                            lng: locationHelper.longitude,
                            language: selectedLanguageCode.isEmpty
                                ? (viewModel.selectedLanguage)
                                : selectedLanguageCode
                        )
                    }
                )
            }
        }
        .background(Color.white)
        .task {
            viewModel.loadLanguages()
        }
    }
}

// MARK: - Step 1: Location

/// Location permission request step.
private struct LocationStep: View {
    @ObservedObject var locationHelper: LocationHelper
    let themeColor: Color
    let cornerRadius: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    private var hasPermission: Bool {
        switch locationHelper.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(themeColor)

            Text("Share Your Location")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)

            Text("Your location helps us provide accurate, region-specific agricultural advice for your area.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if locationHelper.locationDenied {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text("Location access was denied. You can change this in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                if hasPermission && locationHelper.locationObtained {
                    // Permission granted and location obtained
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Location shared")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        onContinue()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(themeColor)
                            )
                    }
                    .padding(.horizontal, 24)
                } else if hasPermission && !locationHelper.locationObtained {
                    // Waiting for location
                    ProgressView("Getting your location...")
                        .padding(.bottom, 8)

                    Button {
                        onContinue()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(themeColor)
                            )
                    }
                    .padding(.horizontal, 24)
                } else {
                    // No permission yet
                    Button {
                        locationHelper.requestPermission()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                            Text("Share Location")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(themeColor)
                        )
                    }
                    .padding(.horizontal, 24)

                    Button {
                        onSkip()
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Step 2: Language

/// Language picker step.
private struct LanguageStep: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var selectedLanguageCode: String
    let themeColor: Color
    let cornerRadius: Double
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundColor(themeColor)

            Text("Choose Your Language")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)

            Text("Select the language you'd like to use for your farming conversations.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if viewModel.availableLanguages.isEmpty {
                Spacer()
                ProgressView("Loading languages...")
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.availableLanguages, id: \.code) { language in
                            LanguageCard(
                                language: language,
                                isSelected: resolvedSelection == language.code,
                                themeColor: themeColor,
                                cornerRadius: cornerRadius,
                                onTap: {
                                    selectedLanguageCode = language.code
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            Button {
                onGetStarted()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(themeColor)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    /// If the user hasn't explicitly selected a language, fall back to the viewModel's default.
    private var resolvedSelection: String {
        selectedLanguageCode.isEmpty ? viewModel.selectedLanguage : selectedLanguageCode
    }
}

/// A single language option card.
private struct LanguageCard: View {
    let language: LanguageResponse
    let isSelected: Bool
    let themeColor: Color
    let cornerRadius: Double
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.nativeName)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)

                    if language.nativeName != language.name {
                        Text(language.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(themeColor)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? themeColor.opacity(0.06) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isSelected ? themeColor : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            )
        }
    }
}
