# FarmerChat SDK

Embeddable AI-powered agricultural advisory chat SDK. Drop a chat widget into any mobile or web app with a few lines of code.

FarmerChat SDK connects farmers to AI-driven crop advisory through a conversational interface — with streaming responses, voice input, multilingual support, and markdown-rich answers. It ships as native libraries for **6 platform targets**, all built from this monorepo.

## Platform Support

| Platform | Package | Min Version | Distribution |
|----------|---------|-------------|--------------|
| Android (Compose) | `farmerchat-android-compose` | API 26 (Android 8.0) | Maven Central AAR |
| Android (XML Views) | `farmerchat-android-views` | API 26 (Android 8.0) | Maven Central AAR |
| iOS (SwiftUI) | `FarmerChatSwiftUI` | iOS 16.0 | SPM XCFramework |
| iOS (UIKit) | `FarmerChatUIKit` | iOS 15.0 | CocoaPods + SPM |
| React Native | `@digitalgreenorg/farmerchat-react-native` | Expo SDK 52+ / RN 0.76+ | npm |
| Web | `@digitalgreenorg/farmerchat-web` | Modern browsers | npm |

## Quick Start

### Android (Jetpack Compose)

```kotlin
// Application.onCreate()
FarmerChat.initialize(
    context = this,
    apiKey = "fc_pub_your_api_key",
)

// In your Composable
FarmerChatFAB(onClick = { /* launch chat */ })
```

### iOS (SwiftUI)

```swift
// App init
FarmerChat.shared.initialize(
    config: FarmerChatConfig(apiKey: "fc_pub_your_api_key")
)

// In your View
FarmerChatView()
```

### React Native (Expo)

```tsx
import { FarmerChat, ChatScreen } from '@digitalgreenorg/farmerchat-react-native';

<FarmerChat config={{ apiKey: 'fc_pub_your_api_key' }}>
  <ChatScreen />
</FarmerChat>
```

### Web

```typescript
import { FarmerChat } from '@digitalgreenorg/farmerchat-web';

const chat = new FarmerChat({ apiKey: 'fc_pub_your_api_key' });
chat.mount('#chat-container');
```

## Repository Structure

```
farmerchat-sdk/
├── packages/
│   ├── core/               # Shared TypeScript: API client, types, SSE parser, codegen
│   ├── android-compose/    # Kotlin + Jetpack Compose AAR
│   ├── android-views/      # Kotlin + XML Views AAR
│   ├── ios-swiftui/        # Swift + SwiftUI XCFramework
│   ├── ios-uikit/          # Swift + UIKit XCFramework
│   ├── react-native/       # TypeScript + Expo Modules SDK
│   ├── web/                # TypeScript Web SDK
│   └── docs/               # Docusaurus documentation site
├── apps/
│   ├── demo-android/       # Android demo app (Compose + Views tabs)
│   ├── demo-ios/           # iOS demo app (SwiftUI + UIKit tabs)
│   └── demo-rn/            # React Native Expo demo app
└── docs/                   # Internal project documentation
```

## Development Setup

### Prerequisites

- **Node.js** 22+ and **pnpm** 10+
- **Android Studio** with SDK 36, AGP 9.1+
- **Xcode** 16+ with Swift 5.9+
- **Expo CLI** for React Native development

### Install & Build

```bash
# Install all dependencies
pnpm install

# Build everything
pnpm turbo build

# Build a single package (with dependencies)
pnpm turbo build --filter=@digitalgreenorg/farmerchat-android-compose...

# Run all tests
pnpm turbo test

# Lint all packages
pnpm turbo lint

# Generate Kotlin/Swift types from core TypeScript
pnpm turbo codegen
```

### Per-Package Commands

```bash
# Core (TypeScript)
cd packages/core && pnpm test          # Vitest

# Android
cd packages/android-compose && ./gradlew build
cd packages/android-views && ./gradlew build

# iOS
cd packages/ios-swiftui && swift build
cd packages/ios-uikit && swift build

# React Native
cd packages/react-native && pnpm test  # Jest

# Docs site
cd packages/docs && pnpm start         # Dev server at localhost:3000
```

## Architecture

The SDK follows a **shared-core** architecture:

- **`packages/core`** defines the API client, types, SSE parser, and error codes in TypeScript
- A **codegen** step generates Kotlin data classes and Swift structs from the core types
- Each platform package wraps the native HTTP client (no third-party networking libraries) and provides a UI layer using platform-native components
- All conversation history is **server-side** — the SDK never caches messages locally
- The SDK is **online-only** with clear "No connection" UI states

### Design Principles

- **< 3 MB** binary size per platform target
- **< 40 MB** memory when chat is active, < 5 MB idle
- **Zero heavyweight dependencies** — no OkHttp, Retrofit, Alamofire, Axios, Room, CoreData
- **SDK crashes must never crash the host app** — all SDK code runs inside try-catch boundaries
- **16 KB page size compliance** for Android native code

## CI/CD

GitHub Actions workflows run per-package with path-filtered triggers:

| Workflow | Trigger Paths | What It Does |
|----------|---------------|--------------|
| `ci-core.yml` | `packages/core/**` | Lint, typecheck, test (Vitest) |
| `ci-android.yml` | `packages/android-*/**` | Gradle build + JUnit5 tests |
| `ci-ios.yml` | `packages/ios-*/**` | `swift build` + XCTest |
| `ci-react-native.yml` | `packages/react-native/**`, `packages/core/**` | Lint, typecheck, Jest |
| `ci-web.yml` | `packages/web/**`, `packages/core/**` | Lint, typecheck, build |
| `ci-docs.yml` | `packages/docs/**` | Docusaurus build |
| `release.yml` | Tags `v*` | Publish all packages |

## Documentation

Full documentation is available at the [docs site](https://sdk.farmerchat.digitalgreen.org) (built from `packages/docs/`).

- [Android Compose Quickstart](packages/docs/docs/quickstart/android-compose.md)
- [Android Views Quickstart](packages/docs/docs/quickstart/android-views.md)
- [iOS SwiftUI Quickstart](packages/docs/docs/quickstart/ios-swiftui.md)
- [iOS UIKit Quickstart](packages/docs/docs/quickstart/ios-uikit.md)
- [React Native Quickstart](packages/docs/docs/quickstart/react-native.md)
- [Configuration & Theming](packages/docs/docs/configuration/)
- [Error Codes](packages/docs/docs/error-codes.md)

## License

Copyright Digital Green Foundation. All rights reserved.
