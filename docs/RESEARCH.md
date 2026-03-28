# FarmerChat SDK — Research Findings

**Date:** March 27, 2026

---

## Sources Consulted

- [Turborepo Releases](https://github.com/vercel/turborepo/releases) — v2.8.20 latest stable
- [pnpm npm](https://www.npmjs.com/package/pnpm) — v10.33.0 latest stable
- [Compose BOM](https://developer.android.com/develop/ui/compose/bom) — 2026.03.00 date-based versioning
- [AGP 9.1.0 Release Notes](https://developer.android.com/build/releases/agp-9-1-0-release-notes) — built-in Kotlin support
- [Kotlin 2.3.20 Released](https://blog.jetbrains.com/kotlin/2026/03/kotlin-2-3-20-released/) — Gradle 9.3 compat
- [Expo SDK 55](https://expo.dev/changelog/sdk-55) — React Native 0.83, legacy arch dropped
- [Docusaurus Versions](https://docusaurus.io/versions) — v3.9.2 stable
- [Vitest 4.0](https://vitest.dev/blog/vitest-4) — browser mode stable
- [TypeScript 5.9](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html) — chosen over 6.0 for ecosystem stability
- [Node.js Releases](https://nodejs.org/en/about/previous-releases) — v24 LTS (Krypton)
- [Android API Levels](https://apilevels.com/) — compileSdk 36

---

## Current Best Practices (March 2026)

### Monorepo Tooling
- **Turborepo 2.8** uses `tasks` key (not `pipeline`) in turbo.json
- Composable configuration landed in 2.7 — allows turbo.json inheritance in packages
- pnpm 10.x is the standard workspace manager; npm workspaces still viable but pnpm is faster and has better hoisting control

### Android SDK Development
- **AGP 9.0+ has built-in Kotlin support** — the `org.jetbrains.kotlin.android` plugin is no longer needed. AGP enables Kotlin compilation by default.
- Compose BOM switched to date-based versioning (`2026.03.00` instead of `2024.06.00`)
- `compileSdk 36` (API level 36) is the latest; Google Play requires targetSdk 36 for new apps
- 16 KB page size compliance is mandatory for Google Play (Android 15+)
- Gradle Version Catalogs (`libs.versions.toml`) are the standard for dependency management

### iOS SDK Development
- Swift 5.9+ is stable; Swift 6 concurrency features available but opt-in
- XCFramework is mandatory for binary distribution (fat frameworks deprecated)
- `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` required for module stability
- SPM is preferred over CocoaPods for new projects

### React Native / Expo
- Expo SDK 55 ships with **React Native 0.83** and drops Legacy Architecture support
- All Expo SDK packages now use the same major version as the SDK (e.g., expo-camera@55.x for SDK 55)
- Expo Modules API is the standard for native bridge modules
- TurboModule support is stable for New Architecture

### TypeScript
- TypeScript 6.0 released March 23, 2026 but is a "stepping stone" to Go-based 7.0 with deprecations
- **Using TypeScript 5.9** for this project — better ecosystem compatibility, well-established
- TypeScript 6.0 can be adopted later once tooling ecosystem catches up

### Testing
- Vitest 4.x has stable browser mode and visual regression testing
- JUnit5 is standard for Android/Kotlin
- XCTest is standard for Swift

---

## Decisions Made

| Decision | Reasoning |
|----------|-----------|
| **TypeScript 5.9** over 6.0 | TS 6.0 released 4 days ago with deprecations; 5.9 has better tooling compat |
| **compileSdk 36** over 35 | Latest API level; AGP 9.1.0 supports it; Google Play requires it for new apps |
| **AGP 9.1.0** | Latest stable; built-in Kotlin support eliminates a plugin |
| **Kotlin 2.3.20** | Latest stable; compatible with Gradle 9.3 and AGP 9.1 |
| **Compose BOM 2026.03.00** | Latest stable; date-based versioning |
| **Expo SDK 55** | Latest with RN 0.83; drops legacy arch (aligns with our modern-only stance) |
| **pnpm 10.x** | User-specified; better hoisting control than npm for multi-platform monorepo |
| **Turborepo 2.8** | `tasks` syntax; composable config; devtools |
| **Node.js 24 LTS** | Current LTS; required by latest Turborepo |
| **Vitest 4.x** | Fastest TS test runner; stable browser mode |

---

## Competitor SDK Analysis (from PRD)

| SDK | Size | Notes |
|-----|------|-------|
| Zendesk Messaging | ~2.3 MB (APK) | Our target benchmark |
| Freshchat | ~2.5 MB | Similar feature set |
| Intercom | ~5-6 MB | Includes push infra (heavier) |

Our target: Zendesk-class size (< 3 MB) with richer AI chat capabilities.
