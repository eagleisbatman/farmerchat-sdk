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
- `theme/FarmerChatTheme.kt` — Wraps MaterialTheme with SDK config
- `screens/ChatScreen.kt` — Main chat UI
- `screens/OnboardingScreen.kt` — Location + language selection
- `screens/HistoryScreen.kt` — Chat history (server-fetched)
- `screens/ProfileScreen.kt` — User profile/settings
- `components/InputBar.kt` — Text + voice + image input
- `components/ResponseCard.kt` — AI response rendering
- `components/ConnectivityBanner.kt` — Offline state UI
- `viewmodel/ChatViewModel.kt` — Chat state management

## Build Config
- compileSdk 36, minSdk 26
- AGP 9.1.0 (built-in Kotlin support, no separate Kotlin plugin)
- Compose BOM 2026.03.00, Material3
- No OkHttp, No Room, No Coil

## Rules
- Use Material3 components only.
- All colors from FarmerChatTheme, never hardcoded.
- No Coil/Glide — use platform BitmapFactory + Canvas for image loading.
- Keep Compose BOM version in gradle/libs.versions.toml, not hardcoded.
- consumer-rules.pro must be updated if you add any new classes with reflection.
- Test with API 26 emulator before merging.
- 16 KB page size compliance for all native code.

## Commands
```bash
./gradlew build
./gradlew test
./gradlew publishToMavenLocal  # Test publish locally
```
