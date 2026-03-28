# CLAUDE.md — packages/android-views

## Purpose
XML Views SDK for FarmerChat. Ships as AAR to Maven Central.
For partner apps not using Jetpack Compose.

## Architecture
- MVVM: Fragments + ViewBinding → ViewModel → ApiClient
- All state in ViewModel (StateFlow). No persistence.
- Theme via XML styles extending Material3.
- Network via HttpURLConnection (no OkHttp).
- Shares network, crash, and config modules with android-compose via Gradle.

## Key Components
- `FarmerChat.kt` — Public API (initialize)
- `FarmerChatActivity.kt` — Single transparent-theme activity hosting fragments
- `FarmerChatFAB.kt` — Custom FAB view
- `ui/fragments/` — ChatFragment, OnboardingFragment, HistoryFragment, ProfileFragment
- `ui/adapters/` — RecyclerView adapters for chat messages
- `network/` — ApiClient, SseReader, ConnectivityMonitor
- `crash/` — CrashBridge, CrashProviderDetector
- `media/` — VoiceRecorder, ImagePicker

## Build Config
- compileSdk 36, minSdk 26
- AGP 9.1.0, Material3 XML components
- AppCompat for backwards compatibility
- No OkHttp, No Room, No Glide

## Rules
- Use ViewBinding (not findViewById).
- XML layouts use ConstraintLayout for complex screens.
- All dimensions from dimens.xml, all colors from colors.xml.
- consumer-rules.pro must be updated for reflection usage.
- Uses a single Activity (transparent theme) to avoid consuming host's backstack.

## Commands
```bash
./gradlew build
./gradlew test
./gradlew publishToMavenLocal
```
