import SwiftUI

/// Floating Action Button overlay for launching the FarmerChat widget.
///
/// Place this in a `ZStack` or `.overlay` in your SwiftUI view hierarchy.
/// The FAB wraps its action in do/catch so the SDK never crashes the host app.
///
/// ```swift
/// ZStack(alignment: .bottomTrailing) {
///     YourContentView()
///     FarmerChatFAB {
///         // Present the FarmerChat sheet
///     }
///     .padding()
/// }
/// ```
public struct FarmerChatFAB: View {

    /// Action invoked when the FAB is tapped.
    let action: () -> Void

    /// Primary brand color for the FAB background. Defaults to FarmerChat green.
    var primaryColor: Color

    /// Diameter of the FAB circle in points. Defaults to 56.
    var size: CGFloat

    /// Create a FarmerChat floating action button.
    ///
    /// - Parameters:
    ///   - action: Closure invoked when the FAB is tapped.
    ///   - primaryColor: Background color for the FAB circle.
    ///   - size: Diameter of the FAB in points.
    public init(
        action: @escaping () -> Void = {},
        primaryColor: Color = Color(red: 0.106, green: 0.420, blue: 0.227),
        size: CGFloat = 56
    ) {
        self.action = action
        self.primaryColor = primaryColor
        self.size = size
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "message.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(primaryColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("Open FarmerChat")
    }
}
