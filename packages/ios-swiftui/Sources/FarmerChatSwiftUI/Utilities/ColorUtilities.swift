import SwiftUI

/// Default FarmerChat green color (#1B6B3A).
internal let farmerChatGreen = Color(red: 0.106, green: 0.420, blue: 0.227)

/// Parse a hex color string (e.g., "#1B6B3A") into a SwiftUI `Color`.
/// Falls back to FarmerChat green if parsing fails.
internal func colorFromHex(_ hex: String) -> Color {
    let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "#", with: "")
    guard cleaned.count == 6,
          let value = UInt64(cleaned, radix: 16) else {
        return farmerChatGreen
    }
    let r = Double((value >> 16) & 0xFF) / 255.0
    let g = Double((value >> 8) & 0xFF) / 255.0
    let b = Double(value & 0xFF) / 255.0
    return Color(red: r, green: g, blue: b)
}
