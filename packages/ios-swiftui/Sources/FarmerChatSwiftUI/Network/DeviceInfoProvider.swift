import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Builds the URL-encoded JSON string for the `Device-Info` request header.
///
/// Format (JSON, then percent-encoded):
/// ```json
/// {
///   "device_id":   "<stored stable uuid>",
///   "platform":    "ios",
///   "os_version":  "<UIDevice.systemVersion>",
///   "app_version": "<CFBundleShortVersionString>",
///   "model":       "<UIDevice.model>"
/// }
/// ```
enum DeviceInfoProvider {

    /// Returns a stable UUID for this device.
    /// The UUID is stored in `UserDefaults` so it survives app restarts.
    static func stableDeviceId() -> String {
        let key = "org.digitalgreen.farmerchat.device_id"
        if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
            return stored
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }

    static func buildHeader(deviceId: String) -> String {
        let osVersion: String
        let model: String
        #if canImport(UIKit)
        osVersion = UIDevice.current.systemVersion
        model = UIDevice.current.model
        #else
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        model = "Mac"
        #endif

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        let dict: [String: String] = [
            "device_id":   deviceId,
            "platform":    "ios",
            "os_version":  osVersion,
            "app_version": appVersion,
            "model":       model,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }

        return json.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? json
    }
}
