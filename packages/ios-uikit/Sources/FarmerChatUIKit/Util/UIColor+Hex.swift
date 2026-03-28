#if canImport(UIKit)
import UIKit

extension UIColor {
    /// Create a `UIColor` from a hex string (e.g., "#1B6B3A" or "1B6B3A").
    /// Falls back to FarmerChat green if parsing fails.
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6,
              let value = UInt64(cleaned, radix: 16) else {
            self.init(red: 0.106, green: 0.420, blue: 0.227, alpha: 1.0)
            return
        }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#else
import AppKit

extension NSColor {
    /// Create an `NSColor` from a hex string (e.g., "#1B6B3A" or "1B6B3A").
    /// Falls back to FarmerChat green if parsing fails.
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6,
              let value = UInt64(cleaned, radix: 16) else {
            self.init(red: 0.106, green: 0.420, blue: 0.227, alpha: 1.0)
            return
        }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif
