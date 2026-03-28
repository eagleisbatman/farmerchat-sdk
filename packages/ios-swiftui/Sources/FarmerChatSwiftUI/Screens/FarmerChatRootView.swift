import SwiftUI

/// Root container view that switches between SDK screens based on ViewModel navigation state.
///
/// This view owns the navigation flow — it observes `viewModel.currentScreen` and
/// renders the appropriate screen (Chat, Onboarding, History, or Profile).
struct FarmerChatRootView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        Group {
            switch viewModel.currentScreen {
            case .onboarding:
                OnboardingView(viewModel: viewModel)
            case .chat:
                ChatView(viewModel: viewModel)
            case .history:
                HistoryView(viewModel: viewModel)
            case .profile:
                ProfileView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentScreen)
    }
}
