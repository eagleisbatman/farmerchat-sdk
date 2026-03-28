# FarmerChat SDK — Dependencies

**Date:** March 27, 2026

---

## Root / Build Tooling

| Package | Version | Purpose | Why This Package? |
|---------|---------|---------|-------------------|
| turbo | ^2.8.20 | Monorepo build orchestration | Incremental builds, task caching, parallel execution |
| pnpm | 10.33.0 | Package manager (via packageManager field) | Workspace protocol, strict hoisting, fast installs |
| typescript | ^5.9.0 | TypeScript compiler (root dev dep) | Shared TS config base; 5.9 for ecosystem stability |

## packages/core

| Package | Version | Purpose | Why This Package? |
|---------|---------|---------|-------------------|
| typescript | ^5.9.0 | Core library compilation | Type safety, codegen source |
| vitest | ^4.1.0 | Unit testing | Fastest TS test runner, native ESM |

### Dev Dependencies
| Package | Version | Purpose | Why This Package? |
|---------|---------|---------|-------------------|
| @types/node | ^24.0.0 | Node.js type definitions | SSE parser needs stream types |
| tsup | ^9.0.0 | Bundle/build tool | Zero-config TS library bundler |

## packages/android-compose

| Dependency | Version | Purpose | Why? |
|------------|---------|---------|------|
| androidx.compose:compose-bom | 2026.03.00 | Compose version alignment | Single BOM manages all Compose lib versions |
| androidx.compose.material3:material3 | (via BOM) | Material 3 UI components | SDK uses M3 theming |
| androidx.lifecycle:lifecycle-viewmodel-compose | 2.9.0 | ViewModel integration | MVVM state management |
| org.jetbrains.kotlinx:kotlinx-coroutines-android | 1.10.0 | Async/coroutines | SSE streaming, network ops |

### Build Plugins
| Plugin | Version | Purpose |
|--------|---------|---------|
| com.android.library | 9.1.0 (AGP) | Android library module build |
| _(Kotlin built-in via AGP 9.0+)_ | — | No separate Kotlin plugin needed |

## packages/android-views

Same networking/coroutine deps as compose. Additional:

| Dependency | Version | Purpose | Why? |
|------------|---------|---------|------|
| com.google.android.material:material | 1.14.0 | Material 3 XML components | Theme/component styles |
| androidx.constraintlayout:constraintlayout | 2.2.1 | Layout system | Complex chat layouts |
| androidx.navigation:navigation-fragment-ktx | 2.9.0 | Fragment navigation | Screen navigation |

## packages/ios-swiftui

**Zero external dependencies.** Uses only:
- Foundation, SwiftUI, Combine (Apple frameworks)
- URLSession + AsyncBytes (networking)
- NWPathMonitor (connectivity)
- SFSpeechRecognizer (voice)

## packages/ios-uikit

**Zero external dependencies.** Uses only:
- Foundation, UIKit (Apple frameworks)
- URLSession (networking)
- NWPathMonitor (connectivity)

## packages/react-native

| Package | Version | Purpose | Why? |
|---------|---------|---------|------|
| expo | ~55.0.0 | Expo SDK | Module API, managed workflow |
| react | 19.0.0 | UI framework | Peer dep via Expo SDK 55 |
| react-native | 0.83.0 | Native bridge | Via Expo SDK 55 |

### Peer Dependencies (not bundled)
| Package | Version | Purpose |
|---------|---------|---------|
| expo-image-picker | ~55.0.0 | Camera/gallery access |

## packages/web

| Package | Version | Purpose | Why? |
|---------|---------|---------|------|
| typescript | ^5.9.0 | Compilation | Type safety |
| tsup | ^9.0.0 | Bundler | Zero-config, tree-shakeable output |

## packages/docs

| Package | Version | Purpose | Why? |
|---------|---------|---------|------|
| @docusaurus/core | ^3.9.2 | Documentation site | Versioned docs, MDX, search |
| @docusaurus/preset-classic | ^3.9.2 | Default theme/plugins | Standard Docusaurus setup |

---

## Packages Considered but NOT Chosen

| Package | Reason for Rejection |
|---------|---------------------|
| OkHttp | PRD mandates no heavyweight HTTP deps; use HttpURLConnection |
| Retrofit | Same as OkHttp; SDK must use platform-native HTTP |
| Alamofire | PRD mandates URLSession only for iOS |
| Axios | PRD mandates fetch API for JS/RN |
| Coil/Glide | PRD mandates BitmapFactory for Android image loading |
| Room/CoreData/SQLite | PRD mandates no local database; all state in-memory |
| AsyncStorage/MMKV | PRD mandates no local persistence for RN |
| Hilt/Dagger | Overkill for SDK; manual DI with constructor injection |
| TypeScript 6.0 | Released 4 days ago; "stepping stone" release with deprecations |
| Bun (package manager) | User specified pnpm for this project |
| Jest | Vitest is faster, native ESM, same API |
