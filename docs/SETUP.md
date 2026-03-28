# FarmerChat SDK — Setup Instructions

**Date:** March 27, 2026

---

## Prerequisites

| Tool | Version | Check Command |
|------|---------|---------------|
| Node.js | 24 LTS (Krypton) | `node -v` |
| pnpm | 10.33.0+ | `pnpm -v` |
| Xcode | 16.0+ | `xcodebuild -version` |
| Android Studio | Latest stable | — |
| JDK | 17+ | `java -version` |
| Swift | 5.9+ | `swift --version` |

### Install pnpm (if not installed)

```bash
corepack enable
corepack prepare pnpm@10.33.0 --activate
```

---

## Installation Steps

### 1. Clone and Install Dependencies

```bash
git clone <repo-url> farmerchat-sdk
cd farmerchat-sdk
pnpm install
```

### 2. Build Core Package

Core must be built first — all other packages depend on it.

```bash
pnpm --filter @digitalgreenorg/farmerchat-core build
```

### 3. Run Type Codegen

Generates Kotlin data classes and Swift structs from core TS types.

```bash
pnpm turbo codegen
```

### 4. Build All Packages

```bash
pnpm turbo build
```

This builds all packages in dependency order with caching enabled.

---

## Running Individual Packages

### Core (TypeScript)

```bash
# Build
pnpm --filter @digitalgreenorg/farmerchat-core build

# Test
pnpm --filter @digitalgreenorg/farmerchat-core test

# Test in watch mode
pnpm --filter @digitalgreenorg/farmerchat-core test:watch

# Lint
pnpm --filter @digitalgreenorg/farmerchat-core lint
```

### Android (Compose)

```bash
cd packages/android-compose

# Build AAR
./gradlew assembleRelease

# Run unit tests
./gradlew testReleaseUnitTest

# Lint
./gradlew lint
```

### Android (Views)

```bash
cd packages/android-views

# Build AAR
./gradlew assembleRelease

# Run unit tests
./gradlew testReleaseUnitTest
```

### iOS (SwiftUI)

```bash
cd packages/ios-swiftui

# Build
swift build

# Test
swift test

# Build XCFramework (for distribution)
./build-xcframework.sh
```

### iOS (UIKit)

```bash
cd packages/ios-uikit

# Build
swift build

# Test
swift test

# Build XCFramework
./build-xcframework.sh
```

### React Native

```bash
# Build
pnpm --filter @digitalgreenorg/farmerchat-react-native build

# Test
pnpm --filter @digitalgreenorg/farmerchat-react-native test

# Lint
pnpm --filter @digitalgreenorg/farmerchat-react-native lint
```

### Web

```bash
# Build
pnpm --filter @digitalgreenorg/farmerchat-web build

# Test
pnpm --filter @digitalgreenorg/farmerchat-web test
```

### Documentation Site

```bash
# Local dev server
pnpm --filter @digitalgreenorg/farmerchat-docs start

# Production build
pnpm --filter @digitalgreenorg/farmerchat-docs build
```

---

## Running Demo Apps

### Android Demo

Open `apps/demo-android/` in Android Studio. The `settings.gradle.kts` includes paths to both `android-compose` and `android-views` library packages.

### iOS Demo

```bash
cd apps/demo-ios
swift build
open Package.swift  # Opens in Xcode
```

### React Native Demo

```bash
cd apps/demo-rn
pnpm install
pnpm start
# Press 'i' for iOS simulator, 'a' for Android emulator
```

---

## Turborepo Commands

```bash
# Build everything
pnpm turbo build

# Test everything
pnpm turbo test

# Lint everything
pnpm turbo lint

# Run codegen (TS → Kotlin/Swift)
pnpm turbo codegen

# Build a specific package and its dependencies
pnpm turbo build --filter=@digitalgreenorg/farmerchat-core

# View task graph
pnpm turbo build --graph
```

---

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `FARMERCHAT_API_KEY` | API key for demo apps | Demo only | `demo-api-key` |
| `FARMERCHAT_BASE_URL` | API base URL for demo apps | Demo only | `https://api.farmerchat.example.com` |
| `NPM_TOKEN` | npm publish token | CI release only | — |
| `MAVEN_USERNAME` | Maven Central username | CI release only | — |
| `MAVEN_PASSWORD` | Maven Central password | CI release only | — |
| `GPG_SIGNING_KEY` | GPG key for Maven signing | CI release only | — |
| `GPG_SIGNING_PASSWORD` | GPG passphrase | CI release only | — |

---

## Troubleshooting

### `pnpm install` fails with lockfile mismatch
```bash
pnpm install --no-frozen-lockfile
```

### Turborepo cache stale
```bash
pnpm turbo build --force
```

### Android Gradle sync fails
Ensure JDK 17 is set in Android Studio:
- Settings → Build → Build Tools → Gradle → Gradle JDK → 17

### Swift build fails with module errors
```bash
cd packages/ios-swiftui
swift package resolve
swift build
```

### Expo start fails in demo-rn
```bash
cd apps/demo-rn
npx expo install --fix
pnpm start --clear
```
