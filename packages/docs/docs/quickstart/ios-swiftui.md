---
sidebar_position: 3
title: iOS (SwiftUI)
---

# iOS (SwiftUI)

Integrate FarmerChat into your iOS app using SwiftUI.

## Prerequisites

- Xcode 16 or later
- Swift 5.9+
- iOS 16.0+ deployment target
- Swift Package Manager

## Installation

### Swift Package Manager

Add the FarmerChat SwiftUI package to your project:

1. In Xcode, go to **File > Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/digitalgreenorg/farmerchat-ios-swiftui.git
   ```
3. Set the version rule to **Up to Next Major Version** from `1.0.0`
4. Click **Add Package**

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/digitalgreenorg/farmerchat-ios-swiftui.git",
        from: "1.0.0"
    )
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["FarmerChatSwiftUI"]
)
```

## Configuration

Initialize the SDK early in your app's lifecycle. The recommended place is your `App` struct's initializer:

```swift
import SwiftUI
import FarmerChatSwiftUI

@main
struct MyApp: App {
    init() {
        FarmerChat.shared.initialize(config: FarmerChatConfig(
            apiKey: "fc_pub_your_api_key"
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

You can customize appearance and behavior via `FarmerChatConfig`:

```swift
FarmerChat.shared.initialize(config: FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    theme: ThemeConfig(
        primaryColor: "#1B6B3A",
        secondaryColor: "#F0F7F2",
        cornerRadius: 16
    ),
    headerTitle: "Crop Advisor",
    defaultLanguage: "hi",
    voiceInputEnabled: true,
    imageInputEnabled: true
))
```

See [Configuration Options](#configuration-options) below for the full list.

## Basic Usage

Add the floating action button to any view using a `ZStack` or `.overlay`:

```swift
import SwiftUI
import FarmerChatSwiftUI

struct ContentView: View {
    @State private var showChat = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Your existing content
            NavigationStack {
                Text("Welcome to my app")
                    .navigationTitle("Home")
            }

            // FarmerChat FAB
            FarmerChatFAB {
                showChat = true
            }
            .padding()
        }
        .sheet(isPresented: $showChat) {
            FarmerChat.shared.chatView()
        }
    }
}
```

The `FarmerChatFAB` renders a circular branded button with a message icon. The `FarmerChat.shared.chatView()` returns the full chat screen provided by the SDK.

## Event Listening

Listen to SDK lifecycle events by passing an `onEvent` callback in your config:

```swift
FarmerChat.shared.initialize(config: FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    onEvent: { event in
        switch event {
        case .chatOpened(let sessionId, _):
            Analytics.track("farmerchat_opened", sessionId: sessionId)
        case .querySent(_, _, let inputMethod, _):
            Analytics.track("farmerchat_query", method: inputMethod)
        case .error(let code, let message, let fatal, _):
            print("FarmerChat error [\(code)]: \(message), fatal: \(fatal)")
        default:
            break
        }
    }
))
```

## Full Example

```swift
import SwiftUI
import FarmerChatSwiftUI

@main
struct MyFarmApp: App {
    init() {
        FarmerChat.shared.initialize(config: FarmerChatConfig(
            apiKey: "fc_pub_your_api_key",
            theme: ThemeConfig(primaryColor: "#1B6B3A"),
            headerTitle: "Farm Advisor",
            defaultLanguage: "en",
            onEvent: { event in
                if case .error(let code, let message, _, _) = event {
                    print("SDK error [\(code)]: \(message)")
                }
            }
        ))
    }

    var body: some Scene {
        WindowGroup {
            HomeScreen()
        }
    }
}

struct HomeScreen: View {
    @State private var showChat = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                VStack {
                    Text("My Farming App")
                        .font(.largeTitle)
                }
                .navigationTitle("Home")
            }

            FarmerChatFAB { showChat = true }
                .padding()
        }
        .sheet(isPresented: $showChat) {
            FarmerChat.shared.chatView()
        }
    }
}
```

## Cleanup

When you need to release SDK resources (for example, on user logout):

```swift
FarmerChat.shared.destroy()
```

After calling `destroy()`, you can re-initialize the SDK by calling `FarmerChat.shared.initialize(config:)` again.

## Configuration Options

### FarmerChatConfig

| Parameter | Type | Default | Description |
|---|---|---|---|
| `apiKey` | `String` | `""` (required) | Partner API key from Digital Green |
| `baseUrl` | `String` | Production URL | FarmerChat API base URL |
| `partnerId` | `String?` | `nil` | Partner ID for analytics |
| `sessionId` | `String?` | `nil` (auto-generated) | External session ID for correlation |
| `location` | `(lat: Double, lng: Double)?` | `nil` | User's location for geo-contextualized advice |
| `theme` | `ThemeConfig?` | `nil` | UI theme customization |
| `crash` | `CrashConfig?` | `nil` | Crash reporting configuration |
| `headerTitle` | `String` | `"FarmerChat"` | Chat screen header title |
| `defaultLanguage` | `String?` | `nil` (server-decided) | Default language code |
| `voiceInputEnabled` | `Bool` | `true` | Enable voice input |
| `imageInputEnabled` | `Bool` | `true` | Enable camera/gallery input |
| `historyEnabled` | `Bool` | `true` | Enable chat history screen |
| `profileEnabled` | `Bool` | `true` | Enable profile/settings screen |
| `showPoweredBy` | `Bool` | `true` | Show "Powered by FarmerChat" |
| `maxMessagesInMemory` | `Int` | `50` | Max messages kept in memory |
| `requestTimeoutMs` | `Int` | `15000` | HTTP request timeout (ms) |
| `sseReconnectAttempts` | `Int` | `1` | SSE reconnect attempts |
| `maxImageDimension` | `Int` | `300` | Max image preview size (pt) |
| `imageCompressionQuality` | `Int` | `80` | Image upload quality (0-100) |
| `onEvent` | `((FarmerChatEvent) -> Void)?` | `nil` | Global event callback |

### ThemeConfig

| Parameter | Type | Default | Description |
|---|---|---|---|
| `primaryColor` | `String` | `"#1B6B3A"` | Primary brand color (hex) |
| `secondaryColor` | `String?` | `nil` | Secondary/accent color (hex) |
| `fontFamily` | `String?` | `nil` (system font) | Custom font family name |
| `cornerRadius` | `Double?` | `nil` | Corner radius for cards/buttons (pt) |
