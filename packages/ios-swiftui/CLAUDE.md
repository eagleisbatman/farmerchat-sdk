# CLAUDE.md — packages/ios-swiftui

## Purpose
SwiftUI SDK for FarmerChat. Ships as XCFramework via SPM.

## Architecture
- MVVM: SwiftUI Views → ObservableObject → ApiClient
- All state in @StateObject/@Published. No CoreData.
- Networking via URLSession + AsyncBytes (SSE streaming).
- Crash detection via NSClassFromString (Sentry, Crashlytics).

## Key Components
- `FarmerChat.swift` — Public API
- `FarmerChatFAB.swift` — FAB overlay view
- `Screens/ChatView.swift` — Main chat
- `Screens/OnboardingView.swift` — Location + language
- `Screens/HistoryView.swift` — Chat history (server-fetched)
- `Screens/ProfileView.swift` — Profile/settings
- `Components/InputBar.swift` — Input with voice + image
- `Components/ResponseCard.swift` — AI response card
- `Components/ConnectivityBanner.swift` — Offline state
- `Network/SSEParser.swift` — Async SSE line parser
- `Network/ApiClient.swift` — URLSession-based HTTP client

## Rules
- Min deployment target: iOS 16.0
- Use NavigationStack (not NavigationView).
- All colors via asset catalog or dynamic theming.
- No third-party dependencies. URLSession only.
- BUILD_LIBRARY_FOR_DISTRIBUTION=YES always.
- Test on iPhone SE (2nd gen) simulator for small screen.

## Commands
```bash
swift build
swift test
./build-xcframework.sh  # Produces .xcframework
```
