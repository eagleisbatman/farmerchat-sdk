# CLAUDE.md — FarmerChat SDK Monorepo

## Project Overview
FarmerChat SDK is an embeddable AI-powered agricultural advisory chat widget.
It ships as native libraries for 6 platform targets, all built from this monorepo.
The SDK is online-only (no offline/local storage) and designed to be < 3 MB per platform.

## Repository Structure
- `packages/core/` — Shared TypeScript: API client, types, SSE parser, codegen
- `packages/android-views/` — Kotlin + XML Views AAR
- `packages/android-compose/` — Kotlin + Jetpack Compose AAR
- `packages/ios-swiftui/` — Swift + SwiftUI XCFramework
- `packages/ios-uikit/` — Swift + UIKit XCFramework
- `packages/react-native/` — TypeScript + Expo Modules SDK
- `packages/web/` — TypeScript Web SDK
- `packages/docs/` — Docusaurus documentation site
- `apps/demo-android/` — Android demo/playground app
- `apps/demo-ios/` — iOS demo/playground app
- `apps/demo-rn/` — React Native demo app
- `docs/` — Project documentation (.md files only, not code docs)

## Tech Stack
- **Package manager:** pnpm 10.x (workspace)
- **Build orchestration:** Turborepo 2.8.x
- **Android:** Kotlin 2.3.x, Gradle (KTS), AGP 9.1+, Compose BOM 2026.03+
- **iOS:** Swift 5.9+, Xcode 16+, SPM
- **React Native:** TypeScript, Expo SDK 55+, Expo Modules API
- **Web:** TypeScript, tsup bundler
- **Core:** TypeScript 5.9+, Vitest for tests
- **CI:** GitHub Actions (per-package path-filtered workflows)

## Critical Design Rules
1. **NO heavyweight dependencies.** Use platform-native HTTP (HttpURLConnection, URLSession, fetch). No OkHttp, Retrofit, Alamofire, Axios.
2. **NO local database.** No Room, CoreData, SQLite, AsyncStorage, MMKV. All state is in-memory.
3. **NO bundled crash library.** Detect host app's crash tool at runtime via reflection/NSClassFromString.
4. **NO offline queue.** SDK requires active internet. Show clear "No connection" UI.
5. **SDK binary < 3 MB** per platform target. Monitor in CI.
6. **Memory < 40 MB** when chat is active, < 5 MB when idle (FAB only).
7. **16 KB page size compliance** for all Android native code.
8. **All conversation history is server-side.** SDK never caches messages locally.
9. **Languages and strings are loaded from the server.** Bundled list is fallback only.
10. **SDK crashes must NEVER crash the host app.** All SDK code runs inside try-catch boundaries.

## Common Commands
```bash
pnpm install                    # Install all dependencies
pnpm turbo codegen              # Generate Kotlin/Swift types from core TS
pnpm turbo build                # Build all packages
pnpm turbo build --filter=@digitalgreenorg/farmerchat-android-compose  # Build single package
pnpm turbo test                 # Run all tests
pnpm turbo lint                 # Lint all packages
```

## Build Targets
- Android AARs: `packages/android-*/build/outputs/aar/`
- iOS XCFrameworks: `packages/ios-*/build/*.xcframework`
- npm packages: `packages/react-native/dist/`, `packages/web/dist/`

## Type Codegen (core → platform)
When you modify types in `packages/core/src/types/`, run:
```bash
pnpm turbo codegen
```
This generates:
- `packages/android-views/**/generated/` (Kotlin data classes)
- `packages/android-compose/**/generated/` (Kotlin data classes)
- `packages/ios-swiftui/Sources/**/Generated/` (Swift structs)
- `packages/ios-uikit/Sources/**/Generated/` (Swift structs)
- React Native and Web consume core types directly via workspace dependency.

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

## Documentation
- All project documentation lives in `docs/` as `.md` files.
- Code documentation (API reference) lives in `packages/docs/` (Docusaurus).
- Do not create documentation files in the root directory.

## Deferred Items
- Crash report device model/OS info — will be added later.
- Pricing model — open, not relevant to SDK code.
- Web/JS SDK — scaffolded, will be built alongside other SDKs.
