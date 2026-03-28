# CLAUDE.md — packages/ios-uikit

## Purpose
UIKit SDK for FarmerChat. Ships as XCFramework via CocoaPods + SPM.
For partner apps not using SwiftUI.

## Architecture
- MVVM: UIViewController → ViewModel → ApiClient
- Modal or push presentation.
- Networking via URLSession.
- Shares FarmerChatCore Swift package with ios-swiftui.

## Key Components
- `FarmerChat.swift` — Public API
- `Views/ChatViewController.swift` — Main chat
- `Views/OnboardingViewController.swift` — Location + language
- `Views/HistoryViewController.swift` — Chat history
- `ObjCBridge/` — Objective-C interop for legacy partners

## Rules
- Min deployment target: iOS 15.0
- ObjC bridging header for legacy interop.
- BUILD_LIBRARY_FOR_DISTRIBUTION=YES always.
- No third-party dependencies.

## Commands
```bash
swift build
swift test
./build-xcframework.sh
```
