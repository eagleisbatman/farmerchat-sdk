import SwiftUI
import CoreLocation

// MARK: - LocationHelper

/// Lightweight CLLocationManager wrapper for requesting location permission and coordinates.
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

/// Onboarding view — requests location permission then navigates to chat.
struct OnboardingView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var locationHelper = LocationHelper()

    private var themeColor: Color {
        colorFromHex(FarmerChat.getConfig().theme?.primaryColor ?? "#1B6B3A")
    }

    private var cornerRadius: Double {
        FarmerChat.getConfig().theme?.cornerRadius ?? 12
    }

    private var hasPermission: Bool {
        switch locationHelper.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
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
                if hasPermission {
                    if locationHelper.locationObtained {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Location shared")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ProgressView("Getting your location...")
                            .padding(.bottom, 8)
                    }

                    Button {
                        viewModel.navigateTo(.chat)
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: cornerRadius).fill(themeColor)
                            )
                    }
                    .padding(.horizontal, 24)
                } else {
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
                            RoundedRectangle(cornerRadius: cornerRadius).fill(themeColor)
                        )
                    }
                    .padding(.horizontal, 24)

                    Button {
                        viewModel.navigateTo(.chat)
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
        .background(Color.white)
    }
}
