# FarmerChat SDK — Claude Code Build Workflow

**Version:** 1.0 | **Date:** March 26, 2026

---

## 1. CLAUDE.md (Root)

Place this file at `farmerchat-sdk/CLAUDE.md`. Claude Code reads this automatically.

```markdown
# CLAUDE.md — FarmerChat SDK Monorepo

## Project Overview
FarmerChat SDK is an embeddable AI-powered agricultural advisory chat widget.
It ships as native libraries for 5 platform targets, all built from this monorepo.
The SDK is online-only (no offline/local storage) and designed to be < 3 MB per platform.

## Repository Structure
- `packages/core/` — Shared TypeScript: API client, types, SSE parser, codegen
- `packages/android-views/` — Kotlin + XML Views AAR
- `packages/android-compose/` — Kotlin + Jetpack Compose AAR
- `packages/ios-swiftui/` — Swift + SwiftUI XCFramework
- `packages/ios-uikit/` — Swift + UIKit XCFramework
- `packages/react-native/` — TypeScript + Expo Modules SDK
- `packages/docs/` — Docusaurus documentation site
- `apps/demo-android/` — Android demo/playground app
- `apps/demo-ios/` — iOS demo/playground app
- `apps/demo-rn/` — React Native demo app

## Tech Stack
- **Package manager:** pnpm (workspace)
- **Build orchestration:** Turborepo
- **Android:** Kotlin, Gradle (KTS), AGP 8.5+, Compose BOM 2024.06+
- **iOS:** Swift 5.9+, Xcode 16+, SPM, CocoaPods
- **React Native:** TypeScript, Expo SDK 52+, Expo Modules API
- **Core:** TypeScript 5.5+, Vitest for tests
- **CI:** GitHub Actions (per-package path-filtered workflows)

## Critical Design Rules
1. **NO heavyweight dependencies.** Use platform-native HTTP (HttpURLConnection, URLSession, fetch). No OkHttp, Retrofit, Alamofire, Axios.
2. **NO local database.** No Room, CoreData, SQLite, AsyncStorage, MMKV. All state is in-memory.
3. **NO bundled crash library.** Detect host app's crash tool at runtime via reflection/NSClassFromString.
4. **NO offline queue.** SDK requires active internet. Show clear "No connection" UI.
5. **SDK binary < 3 MB** per platform target. Monitor in CI.
6. **Memory < 40 MB** when chat is active, < 5 MB when idle (FAB only).
7. **16 KB page size compliance** for all Android native code.

## Common Commands
```bash
pnpm install                    # Install all dependencies
pnpm turbo codegen              # Generate Kotlin/Swift types from core TS
pnpm turbo build                # Build all packages
pnpm turbo build --filter=android-compose  # Build single package
pnpm turbo test                 # Run all tests
pnpm turbo lint                 # Lint all packages
```

## Build Targets
- Android AARs: `packages/android-*/build/outputs/aar/`
- iOS XCFrameworks: `packages/ios-*/build/*.xcframework`
- npm package: `packages/react-native/dist/`

## Type Codegen (core → platform)
When you modify types in `packages/core/src/types/`, run:
```bash
pnpm turbo codegen
```
This generates:
- `packages/android-views/farmerchat-views/src/main/kotlin/.../generated/` (Kotlin data classes)
- `packages/ios-swiftui/Sources/.../Generated/` (Swift structs)
- React Native consumes core types directly via workspace dependency.

## Testing
- Core: `cd packages/core && pnpm test` (Vitest)
- Android: `cd packages/android-compose && ./gradlew test` (JUnit5)
- iOS: `cd packages/ios-swiftui && swift test` (XCTest)
- RN: `cd packages/react-native && pnpm test` (Jest)
- E2E: `cd apps/demo-android && maestro test .maestro/` (Maestro)

## File Naming Conventions
- Kotlin: `PascalCase.kt` (e.g., `ChatViewModel.kt`)
- Swift: `PascalCase.swift` (e.g., `ChatView.swift`)
- TypeScript: `PascalCase.tsx` for components, `camelCase.ts` for utils
- XML layouts: `snake_case.xml` (e.g., `fragment_chat.xml`)
- Test files: `*.test.ts`, `*Test.kt`, `*Tests.swift`

## PR Rules
- Each PR should touch only ONE package (or core + one downstream).
- Run `pnpm turbo build --filter=<package>` before pushing.
- All PRs require passing CI for affected packages.
- Binary size is checked in CI; PRs that exceed budget are blocked.
```

---

## 2. Package-Level CLAUDE.md Files

### packages/core/CLAUDE.md

```markdown
# CLAUDE.md — packages/core

## Purpose
Platform-agnostic shared logic: API client, types, SSE parser, retry logic, constants.
This package is the single source of truth for all data types used across SDKs.

## Key Files
- `src/api/client.ts` — HTTP client abstraction (platform-specific implementations inject fetch)
- `src/api/sse-parser.ts` — Parse SSE text streams into typed events
- `src/types/config.ts` — FarmerChatConfig, ThemeConfig, CrashConfig
- `src/types/events.ts` — All SDK callback event types
- `src/types/messages.ts` — Query, Response, FollowUp, Feedback types
- `src/constants/defaults.ts` — Default values for all config options
- `codegen/kotlin-gen.ts` — Generates Kotlin data classes from TS types
- `codegen/swift-gen.ts` — Generates Swift structs from TS types

## Rules
- Every exported type MUST have JSDoc comments (used by codegen).
- Never import platform-specific code (no 'react-native', no 'android', no 'swift').
- All API response types must handle partial/streaming data.
- Error codes are in `constants/error-codes.ts` — add new codes there, not inline.

## Commands
```bash
pnpm test    # Vitest
pnpm build   # tsc
pnpm codegen # Generate Kotlin + Swift types
```
```

### packages/android-compose/CLAUDE.md

```markdown
# CLAUDE.md — packages/android-compose

## Purpose
Jetpack Compose SDK for FarmerChat. Ships as AAR to Maven Central.

## Architecture
- MVVM: Composables → ViewModel → ApiClient
- All state in ViewModel (StateFlow). No persistence.
- Theme via FarmerChatTheme composable wrapper.
- Network via HttpURLConnection (no OkHttp).

## Key Components
- `FarmerChat.kt` — Public API (initialize, presentChat)
- `FarmerChatFAB.kt` — Floating action button composable
- `screens/ChatScreen.kt` — Main chat UI
- `components/InputBar.kt` — Text + voice + image input
- `components/ResponseCard.kt` — AI response rendering
- `components/ConnectivityBanner.kt` — Offline state UI
- `viewmodel/ChatViewModel.kt` — Chat state management

## Rules
- Use Material3 components only.
- All colors from FarmerChatTheme, never hardcoded.
- No Coil/Glide — use platform BitmapFactory + Canvas for image loading.
- Keep Compose BOM version in gradle.properties, not hardcoded.
- consumer-rules.pro must be updated if you add any new classes with reflection.
- Test with API 26 emulator before merging.

## Commands
```bash
./gradlew build
./gradlew test
./gradlew publishToMavenLocal  # Test publish locally
```
```

### packages/ios-swiftui/CLAUDE.md

```markdown
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
- `Components/InputBar.swift` — Input with voice + image
- `Components/ResponseCard.swift` — AI response card
- `Network/SSEParser.swift` — Async SSE line parser

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
```

### packages/react-native/CLAUDE.md

```markdown
# CLAUDE.md — packages/react-native

## Purpose
React Native SDK for FarmerChat. Expo Modules API. Published to npm.

## Architecture
- React components with hooks (useChat, useConnectivity, useVoice)
- State via useState/useReducer. No AsyncStorage.
- Networking via fetch + EventSource polyfill.
- Peer deps: expo-image-picker, expo (>= SDK 52).

## Key Components
- `FarmerChat.tsx` — Provider component (wraps config context)
- `FarmerChatFAB.tsx` — Pressable overlay FAB
- `screens/ChatScreen.tsx` — Main chat with FlatList
- `components/InputBar.tsx` — Text + voice + camera
- `hooks/useChat.ts` — Chat state machine + SSE management
- `hooks/useConnectivity.ts` — Network state hook

## Rules
- No class components. Functional + hooks only.
- No AsyncStorage, no MMKV, no local persistence.
- expo-image-picker is a peerDependency, not bundled.
- All styles via StyleSheet.create, themed from config context.
- Test on Android + iOS simulators before merging.

## Commands
```bash
pnpm build   # tsc
pnpm test    # jest
pnpm lint    # eslint
```
```

---

## 3. Build Workflow (Step-by-Step)

### Phase 1: Scaffold Monorepo (Week 1)

```bash
# 1. Create repo
mkdir farmerchat-sdk && cd farmerchat-sdk
git init

# 2. Initialize pnpm workspace
pnpm init
# Edit package.json: add "private": true, scripts

# 3. Create workspace config
cat > pnpm-workspace.yaml << 'EOF'
packages:
  - "packages/*"
  - "apps/*"
EOF

# 4. Install Turborepo
pnpm add -Dw turbo typescript

# 5. Create turbo.json
cat > turbo.json << 'EOF'
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "codegen": { "outputs": ["generated/**"] },
    "build": { "dependsOn": ["codegen", "^build"], "outputs": ["dist/**","build/**"] },
    "test": { "dependsOn": ["build"] },
    "lint": {},
    "clean": { "cache": false }
  }
}
EOF

# 6. Scaffold package directories
mkdir -p packages/{core,android-views,android-compose,ios-swiftui,ios-uikit,react-native,docs}
mkdir -p apps/{demo-android,demo-ios,demo-rn}
mkdir -p scripts .github/workflows
```

### Phase 2: Build Core Package (Week 1-2)

Claude Code prompt:
```
Build packages/core as a TypeScript library.
Read CLAUDE.md for rules.

Create:
1. src/types/config.ts — FarmerChatConfig, ThemeConfig, CrashConfig with JSDoc
2. src/types/messages.ts — Query, Response, FollowUp, Feedback types
3. src/types/events.ts — All SDK event callback types
4. src/types/errors.ts — FarmerChatError class + error code enum
5. src/api/client.ts — HTTP client abstraction (accepts fetch-like function)
6. src/api/sse-parser.ts — Parse SSE text stream into typed events
7. src/api/retry.ts — Exponential backoff with max retries
8. src/constants/defaults.ts — All default config values
9. src/constants/error-codes.ts — Enumerated error codes
10. src/constants/languages.json — Bundled language fallback list

Add vitest tests for sse-parser and retry logic.
```

### Phase 3: Build Android Compose SDK (Week 2-4)

Claude Code prompt:
```
Build packages/android-compose as a Kotlin Compose library.
Read CLAUDE.md for rules. Read packages/core/src/types/ for type definitions.

Create the Gradle module with:
- compileSdk 35, minSdk 26
- Compose BOM 2024.06, Material3
- No OkHttp, No Room, No Coil

Build in order:
1. Config types (mirroring core/types)
2. Network layer (HttpURLConnection + SSE + ConnectivityMonitor)
3. Crash bridge (runtime detection via reflection)
4. FarmerChat.kt (public init API)
5. FarmerChatTheme.kt (wraps MaterialTheme)
6. FarmerChatFAB.kt (composable FAB)
7. OnboardingScreen.kt (location + language)
8. ChatScreen.kt (main chat with LazyColumn)
9. InputBar.kt (text + mic + camera)
10. ResponseCard.kt (markdown rendering + action bar)
11. ConnectivityBanner.kt (offline state)
12. HistoryScreen.kt + ProfileScreen.kt

Test with JUnit5 for ViewModels. Test UI with Compose Preview tests.
```

### Phase 4: Build iOS SwiftUI SDK (Week 3-5)

Claude Code prompt:
```
Build packages/ios-swiftui as a Swift Package.
Read CLAUDE.md for rules.

Create Package.swift with:
- platforms: [.iOS(.v16)]
- No external dependencies

Build in order:
1. Config types (Swift structs matching core/types)
2. Network (URLSession + AsyncBytes SSE + NWPathMonitor)
3. Crash bridge (NSClassFromString detection)
4. FarmerChat.swift (public API)
5. FarmerChatFAB.swift (overlay button)
6. OnboardingView.swift
7. ChatView.swift (ScrollView + LazyVStack)
8. InputBar.swift
9. ResponseCard.swift
10. ConnectivityBanner.swift
11. HistoryView.swift + ProfileView.swift

Create build-xcframework.sh for distribution.
```

### Phase 5: Build React Native SDK (Week 4-6)

Claude Code prompt:
```
Build packages/react-native as an Expo module.
Read CLAUDE.md for rules.
Core types are available via workspace dependency @digitalgreenorg/farmerchat-core.

Create:
1. FarmerChat.tsx (Provider with config context)
2. FarmerChatFAB.tsx (Pressable overlay)
3. hooks/useChat.ts (state machine + SSE via fetch)
4. hooks/useConnectivity.ts (NetInfo wrapper)
5. hooks/useVoice.ts (STT bridge)
6. screens/ChatScreen.tsx (FlatList-based)
7. screens/OnboardingScreen.tsx
8. components/InputBar.tsx
9. components/ResponseCard.tsx (markdown rendering)
10. components/ConnectivityBanner.tsx
11. screens/HistoryScreen.tsx + ProfileScreen.tsx

expo-image-picker as peerDependency.
Jest tests for hooks.
```

### Phase 6: Android XML Views + iOS UIKit (Week 5-7)

Follow same pattern but using XML layouts / Fragments (Android) and UIKit ViewControllers (iOS).

### Phase 7: Demo Apps + Docs (Week 6-8)

```
Build apps/demo-android that integrates both android-views and android-compose SDKs.
Toggle between them via a settings screen.

Build apps/demo-rn with the react-native SDK.

Build packages/docs with Docusaurus — quickstart guides for each platform.
```

### Phase 8: CI/CD + Release (Week 7-8)

```
Create GitHub Actions workflows:
1. ci-core.yml — on packages/core/** changes → build + test
2. ci-android-compose.yml — on packages/android-compose/** or core/** → codegen + build + test + 16KB check
3. ci-ios-swiftui.yml — on packages/ios-swiftui/** or core/** → build + test
4. ci-react-native.yml — on packages/react-native/** or core/** → build + test + lint
5. release-android.yml — on tag android-*-v* → publish to Maven Central
6. release-ios.yml — on tag ios-*-v* → build XCFramework + create GitHub release
7. release-npm.yml — on tag react-native-v* → npm publish
```

---

## 4. Claude Code Session Tips

### Useful Patterns

```bash
# Start a focused session on one package
claude --cwd packages/android-compose

# Run a specific build check
claude "Build and test the android-compose package. Report any failures."

# Type codegen after core changes
claude "I updated packages/core/src/types/config.ts. Run codegen and verify the generated Kotlin and Swift types compile."

# Check binary size
claude "Build the android-compose AAR in release mode and report the file size."

# Debug connectivity handling
claude "Write a test for ConnectivityBanner that simulates network loss mid-response and verifies the UI shows the retry button."
```

### Multi-Agent Orchestration (cmux)

For parallel builds across packages:

```bash
# Terminal 1: Core + codegen
claude "Build core and run codegen"

# Terminal 2: Android (depends on core)
claude --cwd packages/android-compose "Wait for codegen output, then build"

# Terminal 3: iOS (depends on core)
claude --cwd packages/ios-swiftui "Wait for codegen output, then build"

# Terminal 4: React Native (depends on core)
claude --cwd packages/react-native "Build and test"
```
