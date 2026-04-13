import SwiftUI

/// Floating Action Button that opens the FarmerChat widget.
///
/// Spec (from UI guide):
///  - 56×56pt circle, bg #2E7D32 (PRIMARY_GREEN), shadow radius 4, y 2
///  - Icon: message.fill
///  - Opens .sheet with ChatContainerView, detent: .large, cornerRadius: 20
public struct FarmerChatFAB: View {
    @State private var isPresented = false
    private let primaryColor = Color(red: 0.18, green: 0.49, blue: 0.20) // #2E7D32

    public init() {}

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "message.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(primaryColor)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding(24)
        .sheet(isPresented: $isPresented) {
            if #available(iOS 16.4, *) {
                FarmerChat.shared.chatView()
                    .presentationDetents([.large])
                    .presentationCornerRadius(20)
            } else {
                FarmerChat.shared.chatView()
                    .presentationDetents([.large])
            }
        }
    }
}
