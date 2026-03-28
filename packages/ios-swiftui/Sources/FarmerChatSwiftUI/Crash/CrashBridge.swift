import Foundation
import os

/// Detects the host app's crash reporting provider at runtime via `NSClassFromString`
/// and forwards SDK errors through it.
///
/// Supports Firebase Crashlytics, Sentry, and Bugsnag. Falls back gracefully
/// to no-op when no provider is present.
///
/// All methods guard defensively -- this class must NEVER crash the host app.
internal final class CrashBridge {

    private static let logger = Logger(
        subsystem: "org.digitalgreen.farmerchat",
        category: "CrashBridge"
    )

    /// Detected crash provider in the host app.
    enum CrashProvider: String {
        case firebase = "Firebase"
        case sentry = "Sentry"
        case bugsnag = "Bugsnag"
        case none = "None"
    }

    /// The currently detected crash provider.
    private(set) var provider: CrashProvider = .none

    /// Detect the crash provider available in the host app's runtime.
    ///
    /// Call once during SDK initialization. Checks for Firebase Crashlytics,
    /// Sentry, and Bugsnag in that priority order.
    func detect() {
        if NSClassFromString("FIRCrashlytics") != nil {
            provider = .firebase
        } else if NSClassFromString("SentrySDK") != nil {
            provider = .sentry
        } else if NSClassFromString("Bugsnag") != nil {
            provider = .bugsnag
        } else {
            provider = .none
        }
        Self.logger.debug("Detected crash provider: \(self.provider.rawValue)")
    }

    /// Report an error to the host app's crash provider.
    ///
    /// - Parameters:
    ///   - error: The error to report.
    ///   - breadcrumbs: Optional context breadcrumbs attached before reporting.
    func reportError(_ error: Error, breadcrumbs: [String] = []) {
        // Attach breadcrumbs first
        for crumb in breadcrumbs {
            addBreadcrumb(crumb)
        }

        switch provider {
        case .firebase:
            reportFirebase(error)
        case .sentry:
            reportSentry(error)
        case .bugsnag:
            reportBugsnag(error)
        case .none:
            Self.logger.warning("SDK error (no crash provider): \(error.localizedDescription)")
        }
    }

    /// Add a breadcrumb for crash context.
    ///
    /// - Parameter message: Descriptive breadcrumb text.
    func addBreadcrumb(_ message: String) {
        switch provider {
        case .firebase:
            // FIRCrashlytics.crashlytics().log(message)
            guard let clazz = NSClassFromString("FIRCrashlytics") as? NSObject.Type,
                  clazz.responds(to: NSSelectorFromString("crashlytics")),
                  let instance = clazz.perform(NSSelectorFromString("crashlytics"))?.takeUnretainedValue(),
                  instance.responds(to: NSSelectorFromString("log:")) else { return }
            _ = instance.perform(NSSelectorFromString("log:"), with: message)

        case .sentry:
            // Create a SentryBreadcrumb and add it via SentrySDK.addBreadcrumb:
            guard let sentryClass = NSClassFromString("SentrySDK"),
                  let breadcrumbClass = NSClassFromString("SentryBreadcrumb") as? NSObject.Type else { return }
            let breadcrumb = breadcrumbClass.init()
            if breadcrumb.responds(to: NSSelectorFromString("setMessage:")) {
                _ = breadcrumb.perform(NSSelectorFromString("setMessage:"), with: message)
            }
            if breadcrumb.responds(to: NSSelectorFromString("setLevel:")) {
                // SentryLevel.info = 1
                _ = breadcrumb.perform(NSSelectorFromString("setLevel:"), with: NSNumber(value: 1))
            }
            let addSelector = NSSelectorFromString("addBreadcrumb:")
            if (sentryClass as AnyObject).responds(to: addSelector) {
                _ = (sentryClass as AnyObject).perform(addSelector, with: breadcrumb)
            }

        case .bugsnag:
            // Bugsnag.leaveBreadcrumb(withMessage:)
            guard let clazz = NSClassFromString("Bugsnag") else { return }
            let selector = NSSelectorFromString("leaveBreadcrumbWithMessage:")
            guard (clazz as AnyObject).responds(to: selector) else { return }
            _ = (clazz as AnyObject).perform(selector, with: message)

        case .none:
            break
        }
    }

    /// Set a custom key-value pair on crash reports for additional SDK context.
    ///
    /// - Parameters:
    ///   - key: The key name.
    ///   - value: The value.
    func setCustomKey(_ key: String, value: String) {
        switch provider {
        case .firebase:
            // FIRCrashlytics.crashlytics().setCustomValue(value, forKey: key)
            guard let clazz = NSClassFromString("FIRCrashlytics") as? NSObject.Type,
                  clazz.responds(to: NSSelectorFromString("crashlytics")),
                  let instance = clazz.perform(NSSelectorFromString("crashlytics"))?.takeUnretainedValue() else { return }
            let selector = NSSelectorFromString("setCustomValue:forKey:")
            guard instance.responds(to: selector) else { return }
            _ = instance.perform(selector, with: value, with: key)

        case .sentry:
            // Sentry's Swift-only API does not expose a simple setTag via ObjC selectors.
            // configureScope requires a closure which cannot be passed via perform:with:.
            // This is a known limitation of the reflection-based approach.
            Self.logger.debug("Sentry setCustomKey not available via ObjC reflection (key: \(key))")

        case .bugsnag:
            // Bugsnag.addMetadata(_:toSection:) with a dictionary
            // NSObject.perform only supports up to 2 arguments, so pass a dict.
            guard let clazz = NSClassFromString("Bugsnag") else { return }
            let selector = NSSelectorFromString("addMetadata:toSection:")
            guard (clazz as AnyObject).responds(to: selector) else { return }
            let metadata: NSDictionary = [key: value]
            _ = (clazz as AnyObject).perform(selector, with: metadata, with: "farmerchat")

        case .none:
            break
        }
    }

    // MARK: - Private Helpers

    /// Report error to Firebase Crashlytics via `recordError:`.
    private func reportFirebase(_ error: Error) {
        guard let clazz = NSClassFromString("FIRCrashlytics") as? NSObject.Type,
              clazz.responds(to: NSSelectorFromString("crashlytics")),
              let instance = clazz.perform(NSSelectorFromString("crashlytics"))?.takeUnretainedValue() else {
            return
        }
        let selector = NSSelectorFromString("recordError:")
        guard instance.responds(to: selector) else { return }
        _ = instance.perform(selector, with: error as NSError)
    }

    /// Report error to Sentry via `captureError:`.
    private func reportSentry(_ error: Error) {
        guard let sentryClass = NSClassFromString("SentrySDK") else { return }
        let selector = NSSelectorFromString("captureError:")
        guard (sentryClass as AnyObject).responds(to: selector) else { return }
        _ = (sentryClass as AnyObject).perform(selector, with: error as NSError)
    }

    /// Report error to Bugsnag via `notifyError:`.
    private func reportBugsnag(_ error: Error) {
        guard let clazz = NSClassFromString("Bugsnag") else { return }
        let selector = NSSelectorFromString("notifyError:")
        guard (clazz as AnyObject).responds(to: selector) else { return }
        _ = (clazz as AnyObject).perform(selector, with: error as NSError)
    }
}
