# FarmerChat SDK — Technical Architecture & Monorepo Scaffolding

**Version:** 1.0 | **Date:** March 26, 2026 | **Classification:** Confidential

---

## 1. System Architecture Overview

### 1.1 Architecture Principles

| Principle | Rationale |
|-----------|-----------|
| **Online-only** | No local DB, no offline queue, no sync. Keeps SDK < 3 MB and avoids stale advisory data. |
| **Thin client** | All AI inference, RAG, and conversation management is server-side. SDK handles only UI + networking. |
| **Zero heavyweight deps** | Use platform-native HTTP/JSON. No OkHttp, Retrofit, Alamofire. Minimizes version conflicts with host apps. |
| **Crash-transparent** | SDK hooks into the host app's existing crash tool (Firebase, Sentry, Bugsnag). Ships 0 KB of crash library. |
| **Monorepo, independent builds** | Single repo for all 5 SDK variants. Each builds and publishes independently. Shared types via codegen. |

### 1.2 Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        PARTNER APP                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   FarmerChat SDK Widget                    │  │
│  │  ┌──────────┐  ┌──────────────┐  ┌───────────────────┐   │  │
│  │  │ UI Layer │  │ Network Layer │  │ Crash Integration │   │  │
│  │  │          │  │               │  │                   │   │  │
│  │  │ • FAB    │  │ • HTTP Client │  │ • Exception catch │   │  │
│  │  │ • Chat   │  │ • SSE Parser  │  │ • Breadcrumbs     │   │  │
│  │  │ • Onboard│  │ • Retry Logic │  │ • Custom keys     │   │  │
│  │  │ • Input  │  │ • Connectivity│  │ • onCrash callback│   │  │
│  │  │ • Actions│  │   Monitor     │  │                   │   │  │
│  │  └──────────┘  └───────┬───────┘  └───────────────────┘   │  │
│  └────────────────────────┼──────────────────────────────────┘  │
└───────────────────────────┼─────────────────────────────────────┘
                            │ HTTPS / TLS 1.3
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   FARMERCHAT CLOUD                               │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐    │
│  │ API Gateway   │  │ AI Advisory  │  │ Knowledge Base     │    │
│  │ • Auth        │  │ Engine       │  │ • Curated content  │    │
│  │ • Rate limit  │  │ • LLM        │  │ • Crop calendar    │    │
│  │ • Routing     │  │ • RAG        │  │ • Geo-context      │    │
│  │ • Analytics   │  │ • Streaming  │  │ • Extension docs   │    │
│  └──────────────┘  └──────────────┘  └────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Data Flow (Happy Path)

1. Partner app initializes SDK with API key + config
2. User taps FAB → SDK opens chat screen
3. First-time user → onboarding (location + language, in-memory only)
4. User types/speaks/photographs a query
5. SDK sends POST to `/v1/chat/send` with: query, location, language, session context
6. Server opens SSE stream → SDK renders tokens incrementally
7. Response complete → SDK shows follow-up chips + action bar
8. User can thumbs up/down, listen (TTS), share, or ask follow-up
9. User closes chat → SSE disconnected, in-memory state retained for session

---

## 2. Platform-Specific Architecture

### 2.1 Android (XML Views)

| Aspect | Detail |
|--------|--------|
| **Build** | Kotlin, Android library module, published as AAR to Maven Central |
| **Min SDK** | API 26 (Android 8.0) — covers 97%+ of active devices |
| **UI** | XML layouts + ViewBinding. Fragment-based chat screen launched via `FarmerChatActivity` |
| **Networking** | `java.net.HttpURLConnection` + `BufferedReader` for SSE. No OkHttp. |
| **Image** | `CameraX` for capture, `BitmapFactory` for compression. No Glide/Coil bundled. |
| **Voice** | `SpeechRecognizer` (on-device STT). Falls back to server STT if unavailable. |
| **Memory** | All state in `ViewModel` (AndroidX). No Room/SQLite. Cleared on process death. |
| **Crash** | Detects Crashlytics/Sentry/Bugsnag via reflection. `onCrash` callback as fallback. |
| **ProGuard** | Ships `consumer-rules.pro` in AAR. Auto-applied by host's R8. |
| **16 KB** | All `.so` files built with 16 KB ELF alignment. Validated in CI. |

### 2.2 Android (Jetpack Compose)

| Aspect | Detail |
|--------|--------|
| **Build** | Kotlin, Compose AAR. Requires Compose BOM 2024.06+ |
| **UI** | `@Composable` functions. Chat screen as composable or launched via `Activity`. |
| **Theming** | `FarmerChatTheme` composable extends `MaterialTheme`. |
| **State** | `State` + `StateFlow` in ViewModel. No persistence across process death. |
| **Shared** | Shares `network`, `crash`, `config` modules with android-views via Gradle. |

### 2.3 iOS (SwiftUI)

| Aspect | Detail |
|--------|--------|
| **Build** | Swift 5.9+, XCFramework via SPM |
| **Min iOS** | 16.0 (NavigationStack, async/await stable) |
| **UI** | SwiftUI views. Presented as `.sheet` or `NavigationLink`. |
| **Networking** | `URLSession` + `AsyncBytes` for SSE. No Alamofire. |
| **Image** | `PHPickerViewController` for gallery, `AVCaptureSession` for camera. |
| **Voice** | `SFSpeechRecognizer` (on-device). |
| **Memory** | `@StateObject` / `@ObservableObject`. No CoreData. |
| **Crash** | Detects Sentry/Crashlytics via `NSClassFromString`. |
| **Distribution** | `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`. Device + simulator slices. |

### 2.4 iOS (UIKit)

| Aspect | Detail |
|--------|--------|
| **Build** | Swift + UIKit. ObjC bridging for legacy partners. |
| **Min iOS** | 15.0 |
| **UI** | `UIViewController`-based. Modal or push presentation. |
| **Distribution** | CocoaPods (`.podspec`) + SPM. |
| **Shared** | Shares `FarmerChatCore` Swift package with ios-swiftui. |

### 2.5 React Native (Expo)

| Aspect | Detail |
|--------|--------|
| **Build** | TypeScript, Expo Modules API. Published to npm. |
| **Min** | RN 0.73+ / Expo SDK 52+ |
| **UI** | React components. Modal or full-screen. |
| **Networking** | `fetch` + `EventSource` polyfill for SSE. |
| **Image** | `expo-image-picker` (peer dep). |
| **Voice** | `expo-speech` for TTS, native bridge for STT. |
| **Memory** | React state only. No AsyncStorage. |

---

## 3. Monorepo Structure

### 3.1 Complete Directory Tree

```
farmerchat-sdk/
├── .github/
│   ├── workflows/
│   │   ├── ci-android-views.yml
│   │   ├── ci-android-compose.yml
│   │   ├── ci-ios-swiftui.yml
│   │   ├── ci-ios-uikit.yml
│   │   ├── ci-react-native.yml
│   │   ├── ci-core.yml
│   │   ├── release-android.yml
│   │   ├── release-ios.yml
│   │   └── release-npm.yml
│   └── CODEOWNERS
├── packages/
│   ├── core/                        # Shared TS: API client, types, config
│   │   ├── src/
│   │   │   ├── api/
│   │   │   │   ├── client.ts
│   │   │   │   ├── sse-parser.ts
│   │   │   │   ├── endpoints.ts
│   │   │   │   └── retry.ts
│   │   │   ├── types/
│   │   │   │   ├── config.ts
│   │   │   │   ├── events.ts
│   │   │   │   ├── messages.ts
│   │   │   │   └── errors.ts
│   │   │   ├── constants/
│   │   │   │   ├── defaults.ts
│   │   │   │   ├── languages.json
│   │   │   │   └── error-codes.ts
│   │   │   └── index.ts
│   │   ├── codegen/
│   │   │   ├── kotlin-gen.ts
│   │   │   ├── swift-gen.ts
│   │   │   └── templates/
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── android-views/
│   │   ├── farmerchat-views/src/main/
│   │   │   ├── kotlin/org/digitalgreen/farmerchat/
│   │   │   │   ├── FarmerChat.kt
│   │   │   │   ├── FarmerChatActivity.kt
│   │   │   │   ├── FarmerChatFAB.kt
│   │   │   │   ├── config/
│   │   │   │   ├── ui/ (fragments, adapters, views)
│   │   │   │   ├── network/ (ApiClient, SseReader, ConnectivityMonitor)
│   │   │   │   ├── crash/ (CrashBridge, CrashProviderDetector)
│   │   │   │   └── media/ (VoiceRecorder, ImagePicker)
│   │   │   └── res/ (layouts, values, drawables)
│   │   ├── build.gradle.kts
│   │   └── publish.gradle.kts
│   ├── android-compose/
│   │   ├── farmerchat-compose/src/main/kotlin/.../compose/
│   │   │   ├── FarmerChat.kt
│   │   │   ├── FarmerChatFAB.kt
│   │   │   ├── theme/FarmerChatTheme.kt
│   │   │   ├── screens/ (Chat, Onboarding, History, Profile)
│   │   │   ├── components/ (InputBar, ResponseCard, FollowUpChips, etc.)
│   │   │   └── viewmodel/
│   │   ├── build.gradle.kts
│   │   └── publish.gradle.kts
│   ├── ios-swiftui/
│   │   ├── Sources/FarmerChatSwiftUI/
│   │   │   ├── FarmerChat.swift
│   │   │   ├── Config/, Screens/, Components/
│   │   │   ├── Network/, Crash/, Media/
│   │   │   └── Resources/
│   │   ├── Package.swift
│   │   └── build-xcframework.sh
│   ├── ios-uikit/
│   │   ├── Sources/FarmerChatUIKit/
│   │   │   ├── Views/, ObjCBridge/
│   │   ├── FarmerChatUIKit.podspec
│   │   └── Package.swift
│   ├── react-native/
│   │   ├── src/
│   │   │   ├── index.ts, screens/, components/, hooks/, native/
│   │   ├── expo-module.config.json
│   │   └── package.json
│   └── docs/
│       ├── docusaurus.config.js
│       └── docs/ (quickstarts, config, theming, errors, API ref)
├── apps/
│   ├── demo-android/
│   ├── demo-ios/
│   └── demo-rn/
├── scripts/ (codegen, build-all, publish scripts)
├── turbo.json
├── pnpm-workspace.yaml
├── package.json
├── CLAUDE.md
└── README.md
```

### 3.2 Build Independence

Each package builds independently via Turborepo task graph:

- **Core changes** → triggers all downstream packages (codegen + rebuild)
- **android-compose change** → triggers only android-compose build
- **iOS changes** → no Android builds triggered
- CI workflows use `paths:` filters to avoid unnecessary jobs

### 3.3 Publishing

| Package | Target | Method |
|---------|--------|--------|
| android-views | Maven Central | `./gradlew publish` via `publish.gradle.kts` |
| android-compose | Maven Central | Same |
| ios-swiftui | SPM (GitHub tag) | `build-xcframework.sh` + git tag |
| ios-uikit | CocoaPods + SPM | `pod trunk push` + git tag |
| react-native | npm | `npm publish` |

---

## 4. Networking Architecture

### 4.1 SSE Stream Protocol

```
POST /v1/chat/send
→ SSE stream response

event: token    data: {"text":"To","index":0}
event: token    data: {"text":" treat","index":1}
event: followup data: {"questions":["How often water?","What fertilizer?"]}
event: done     data: {"response_id":"resp_xxx","latency_ms":2340}
```

### 4.2 Retry Strategy

| Failure | Strategy |
|---------|----------|
| Network unreachable | No retry. Show UI. Auto-recover on connectivity change. |
| Timeout (>30s) | Cancel. Show "Tap to retry." |
| HTTP 5xx | Exponential backoff: 1s, 2s, 4s. Max 3. Then error UI. |
| HTTP 429 | Respect `Retry-After`. Show countdown. |
| SSE disconnect | 1 immediate retry. Then "Tap to continue." |

### 4.3 Connectivity Monitoring

- **Android:** `ConnectivityManager.registerNetworkCallback`
- **iOS:** `NWPathMonitor`
- **React Native:** `@react-native-community/netinfo` or Expo equivalent

---

## 5. Crash Integration

### 5.1 Detection (No bundled crash library)

SDK checks classpath/runtime for known crash providers. Zero binary overhead.

### 5.2 What Gets Logged

| Data | Logged | Notes |
|------|--------|-------|
| SDK version | Yes | |
| Session ID | Yes | Anonymized |
| Error type | Yes | e.g., "sse_disconnect" |
| Stack trace | Yes | Unhandled only |
| Device/OS | Yes | Via crash provider |
| Partner key | Yes | SHA-256 hashed |
| Query text | **NO** | |
| Response | **NO** | |
| GPS coords | **NO** | |

---

## 6. Memory Management

### 6.1 Lifecycle

```
FAB only (idle):          ~3-5 MB
Chat active:              ~25-40 MB
Chat closed (session):    ~5-8 MB
Session expired / kill:   ~3-5 MB (fresh)
```

### 6.2 Constraints

- Max 50 messages in memory. Older via History API.
- Images as compressed thumbnails (300x300 dp max).
- Full-res loaded on-demand, released on dismiss.
- All image refs released on chat close.

---

## 7. CI/CD

Per-package GitHub Actions with path filters. Turborepo caching. Release via git tags per package. 16 KB alignment check in Android CI.

---

## 8. Testing Strategy

| Level | Tools |
|-------|-------|
| Unit | Vitest (core), JUnit5 (Android), XCTest (iOS), Jest (RN) |
| Component | Compose Previews, SwiftUI Previews, RN Testing Library |
| Integration | WireMock, MSW (mock API) |
| E2E | Maestro (Android/iOS), Detox (RN) |
| Performance | Android Profiler, Instruments, apkscale |
