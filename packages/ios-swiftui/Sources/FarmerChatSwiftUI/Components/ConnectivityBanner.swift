import SwiftUI

/// Banner shown when the device is offline.
///
/// Full-width bar with a wifi.slash icon and reconnecting message.
/// Uses a subtle red/error tint that adapts to light and dark mode.
///
/// Port of `ConnectivityBanner.kt` from the Android Compose SDK.
struct ConnectivityBanner: View {

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.red)

            Text("You\u{2019}re offline. Reconnecting\u{2026}")
                .font(.subheadline)
                .foregroundStyle(Color.red)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.08))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You are offline. Reconnecting.")
    }
}
