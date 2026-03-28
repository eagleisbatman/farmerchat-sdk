# FarmerChat SDK — Project Structure

**Date:** March 27, 2026

---

## Directory Layout

```
farmerchat-sdk/
├── CLAUDE.md                          # Root AI assistant instructions
├── package.json                       # Root workspace config (pnpm + turbo scripts)
├── pnpm-workspace.yaml                # Workspace package globs
├── turbo.json                         # Turborepo task definitions
├── tsconfig.base.json                 # Shared TypeScript base config
├── .npmrc                             # pnpm settings
├── .editorconfig                      # Editor formatting rules
├── .gitignore                         # Git ignore patterns
│
├── docs/                              # Project documentation (all .md)
│   ├── RESEARCH.md                    # Dependency research findings
│   ├── DEPENDENCIES.md                # Full dependency manifest
│   ├── STRUCTURE.md                   # This file
│   └── SETUP.md                       # Setup and build instructions
│
├── packages/
│   ├── core/                          # Shared TypeScript library
│   │   ├── src/
│   │   │   ├── index.ts               # Barrel exports
│   │   │   ├── types/
│   │   │   │   ├── config.ts          # FarmerChatConfig, ThemeConfig, CrashConfig
│   │   │   │   ├── events.ts          # SDKEvent union type
│   │   │   │   ├── messages.ts        # Query, Response, StreamToken, Conversation
│   │   │   │   └── errors.ts          # FarmerChatError class + error codes
│   │   │   ├── api/
│   │   │   │   ├── client.ts          # FarmerChatApiClient (fetch + SSE)
│   │   │   │   ├── sse-parser.ts      # Incremental SSE stream parser
│   │   │   │   ├── retry.ts           # Exponential backoff retry logic
│   │   │   │   ├── endpoints.ts       # API path constants
│   │   │   │   └── __tests__/         # Vitest unit tests
│   │   │   └── constants/
│   │   │       ├── defaults.ts        # Default config values
│   │   │       ├── error-codes.ts     # Error code string constants
│   │   │       └── languages.json     # Fallback language list (10 languages)
│   │   ├── codegen/
│   │   │   ├── run.ts                 # Codegen entry point
│   │   │   ├── kotlin-gen.ts          # TS → Kotlin data class generator
│   │   │   └── swift-gen.ts           # TS → Swift struct generator
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── tsup.config.ts
│   │   └── vitest.config.ts
│   │
│   ├── android-compose/               # Kotlin + Jetpack Compose AAR
│   │   ├── src/main/
│   │   │   ├── kotlin/org/digitalgreen/farmerchat/compose/
│   │   │   │   ├── FarmerChat.kt      # SDK singleton entry point
│   │   │   │   ├── FarmerChatConfig.kt
│   │   │   │   ├── FarmerChatFAB.kt   # Floating action button composable
│   │   │   │   ├── theme/FarmerChatTheme.kt
│   │   │   │   ├── screens/           # ChatScreen, OnboardingScreen
│   │   │   │   ├── components/        # InputBar, ResponseCard, ConnectivityBanner
│   │   │   │   ├── viewmodel/ChatViewModel.kt
│   │   │   │   ├── network/           # ApiClient, ConnectivityMonitor
│   │   │   │   └── crash/CrashBridge.kt
│   │   │   └── AndroidManifest.xml
│   │   ├── build.gradle.kts
│   │   ├── settings.gradle.kts
│   │   └── CLAUDE.md
│   │
│   ├── android-views/                 # Kotlin + XML Views AAR
│   │   ├── src/main/
│   │   │   ├── kotlin/org/digitalgreen/farmerchat/views/
│   │   │   │   ├── FarmerChat.kt
│   │   │   │   ├── FarmerChatConfig.kt
│   │   │   │   ├── FarmerChatActivity.kt
│   │   │   │   └── FarmerChatFAB.kt
│   │   │   └── AndroidManifest.xml
│   │   ├── build.gradle.kts
│   │   ├── settings.gradle.kts
│   │   └── CLAUDE.md
│   │
│   ├── ios-swiftui/                   # Swift + SwiftUI XCFramework (SPM)
│   │   ├── Sources/FarmerChatSwiftUI/
│   │   │   ├── FarmerChat.swift       # SDK singleton
│   │   │   ├── Config/FarmerChatConfig.swift
│   │   │   ├── FarmerChatFAB.swift
│   │   │   ├── Screens/              # ChatView, OnboardingView, HistoryView, ProfileView
│   │   │   ├── Components/           # InputBar, ResponseCard, ConnectivityBanner
│   │   │   ├── Network/              # ApiClient, SSEParser, ConnectivityMonitor
│   │   │   └── Crash/CrashBridge.swift
│   │   ├── Tests/FarmerChatSwiftUITests/
│   │   ├── Package.swift
│   │   ├── build-xcframework.sh
│   │   └── CLAUDE.md
│   │
│   ├── ios-uikit/                     # Swift + UIKit XCFramework (SPM + CocoaPods)
│   │   ├── Sources/FarmerChatUIKit/
│   │   │   ├── FarmerChat.swift
│   │   │   ├── Config/FarmerChatConfig.swift
│   │   │   ├── Views/ChatViewController.swift
│   │   │   └── ObjCBridge/FarmerChatObjC.swift
│   │   ├── Tests/FarmerChatUIKitTests/
│   │   ├── Package.swift
│   │   ├── FarmerChatUIKit.podspec
│   │   ├── build-xcframework.sh
│   │   └── CLAUDE.md
│   │
│   ├── react-native/                  # TypeScript + Expo Modules SDK
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── FarmerChat.tsx         # React context provider
│   │   │   ├── FarmerChatFAB.tsx
│   │   │   ├── screens/              # ChatScreen, OnboardingScreen
│   │   │   ├── components/           # InputBar, ResponseCard, ConnectivityBanner
│   │   │   └── hooks/                # useChat, useConnectivity, useVoice
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── expo-module.config.json
│   │   └── CLAUDE.md
│   │
│   ├── web/                           # Vanilla TypeScript Web SDK
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   └── FarmerChat.ts          # Shadow DOM widget class
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── tsup.config.ts
│   │   └── CLAUDE.md
│   │
│   └── docs/                          # Docusaurus documentation site
│       ├── docs/
│       │   ├── intro.md
│       │   ├── quickstart/
│       │   └── error-codes.md
│       ├── docusaurus.config.js
│       ├── sidebars.js
│       ├── package.json
│       └── CLAUDE.md
│
├── apps/
│   ├── demo-android/                  # Android demo app (Compose + Views)
│   │   ├── src/main/
│   │   ├── build.gradle.kts
│   │   └── settings.gradle.kts
│   │
│   ├── demo-ios/                      # iOS demo app (SwiftUI)
│   │   ├── Sources/
│   │   └── Package.swift
│   │
│   └── demo-rn/                       # React Native Expo demo app
│       ├── app/
│       ├── app.json
│       └── package.json
│
└── .github/
    └── workflows/                     # Per-package CI + release workflows
        ├── ci-core.yml
        ├── ci-android.yml
        ├── ci-ios.yml
        ├── ci-react-native.yml
        ├── ci-web.yml
        ├── ci-docs.yml
        └── release.yml
```

## Key Files Explained

### Root Configuration
- `package.json` — Defines pnpm version, Turborepo dev dep, and workspace-level scripts
- `pnpm-workspace.yaml` — Declares `packages/*` and `apps/*` as workspace members
- `turbo.json` — Defines build/test/lint/codegen task graph with caching and dependencies
- `tsconfig.base.json` — Shared TypeScript config extended by all TS packages

### Codegen Pipeline
- `packages/core/codegen/run.ts` — Entry point invoked by `pnpm turbo codegen`
- `packages/core/codegen/kotlin-gen.ts` — Reads core TS types → emits Kotlin data classes
- `packages/core/codegen/swift-gen.ts` — Reads core TS types → emits Swift structs

### Build Artifacts (gitignored)
- `packages/core/dist/` — Compiled JS + `.d.ts` type declarations
- `packages/android-compose/build/` — AAR output
- `packages/android-views/build/` — AAR output
- `packages/ios-swiftui/build/` — XCFramework zip
- `packages/ios-uikit/build/` — XCFramework zip
- `packages/web/dist/` — Bundled JS (IIFE + ESM)
- `packages/react-native/dist/` — Compiled TS output

## Naming Conventions

| Scope | Convention | Example |
|-------|-----------|---------|
| TS files | camelCase | `sseParser.ts` |
| TS types/interfaces | PascalCase | `FarmerChatConfig` |
| Kotlin files | PascalCase | `FarmerChat.kt` |
| Kotlin packages | reverse domain | `org.digitalgreen.farmerchat.compose` |
| Swift files | PascalCase | `FarmerChat.swift` |
| Swift modules | PascalCase | `FarmerChatSwiftUI` |
| React components | PascalCase | `FarmerChatFAB.tsx` |
| React hooks | camelCase with `use` prefix | `useChat.ts` |
| CSS classes | kebab-case with `fc-` prefix | `fc-chat-container` |
| Error codes | UPPER_SNAKE_CASE | `NETWORK_TIMEOUT` |
| API endpoints | kebab-case | `/api/v1/chat-sessions` |
