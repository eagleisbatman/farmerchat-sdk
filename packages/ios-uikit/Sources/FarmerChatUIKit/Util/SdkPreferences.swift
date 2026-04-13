import Foundation

/// Thin wrapper around `UserDefaults` for persisting SDK-level settings.
/// All SDK state that must survive app restarts goes here.
final class SdkPreferences {

    private static let suite = "org.digitalgreen.farmerchat.uikit"
    private static let defaults = UserDefaults(suiteName: suite) ?? .standard

    private enum Keys {
        static let onboardingDone    = "fc_onboarding_done"
        static let selectedLanguage  = "fc_selected_language"
        static let deviceId          = "fc_device_id"
    }

    // MARK: - Onboarding

    static var isOnboardingDone: Bool {
        get { defaults.bool(forKey: Keys.onboardingDone) }
        set { defaults.set(newValue, forKey: Keys.onboardingDone) }
    }

    // MARK: - Language

    static var selectedLanguage: String? {
        get { defaults.string(forKey: Keys.selectedLanguage) }
        set { defaults.set(newValue, forKey: Keys.selectedLanguage) }
    }

    // MARK: - Stable device ID

    static var stableDeviceId: String {
        if let existing = defaults.string(forKey: Keys.deviceId), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: Keys.deviceId)
        return newId
    }
}
