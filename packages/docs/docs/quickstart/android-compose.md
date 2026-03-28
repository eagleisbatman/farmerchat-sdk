---
sidebar_position: 1
title: Android (Jetpack Compose)
---

# Android (Jetpack Compose)

Integrate FarmerChat into your Android app using Jetpack Compose.

## Prerequisites

- Android Studio Ladybug (2024.2) or later
- AGP 9.1.0+ with built-in Kotlin support
- `compileSdk 36`, `minSdk 26`
- Jetpack Compose BOM 2026.03.00 or later

## Installation

Add the dependency to your module-level `build.gradle.kts`:

```kotlin
dependencies {
    implementation("org.digitalgreen:farmerchat-compose:1.0.0")
}
```

The library is hosted on Maven Central. Make sure your project-level `settings.gradle.kts` includes:

```kotlin
dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}
```

## Configuration

Initialize the SDK once in your `Application.onCreate()`:

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        FarmerChat.initialize(
            context = this,
            apiKey = "fc_pub_your_api_key",
        )
    }
}
```

You can customize appearance and behavior via `FarmerChatConfig`:

```kotlin
FarmerChat.initialize(
    context = this,
    apiKey = "fc_pub_your_api_key",
    config = FarmerChatConfig(
        primaryColor = 0xFF1B6B3A,
        secondaryColor = 0xFFF0F7F2,
        headerTitle = "Crop Advisor",
        defaultLanguage = "hi",
        voiceInputEnabled = true,
        imageInputEnabled = true,
        cornerRadius = 16,
    )
)
```

See [Configuration Options](#configuration-options) below for the full list.

## Basic Usage

Add the floating action button to any screen:

```kotlin
@Composable
fun HomeScreen() {
    Box(modifier = Modifier.fillMaxSize()) {
        // Your existing content
        Text("Welcome to my app")

        // FarmerChat FAB in the bottom-right corner
        FarmerChatFAB(
            modifier = Modifier.align(Alignment.BottomEnd),
            onClick = {
                // Launch FarmerChat (navigation handled by SDK)
            }
        )
    }
}
```

The `FarmerChatFAB` composable renders a branded circular button with a chat icon. It automatically applies the SDK theme colors regardless of where you place it in your view hierarchy.

## Event Listening

Listen to SDK lifecycle events for analytics or custom behavior:

```kotlin
FarmerChat.setEventCallback { event ->
    when (event) {
        is FarmerChatEvent.ChatOpened -> {
            analytics.track("farmerchat_opened", event.sessionId)
        }
        is FarmerChatEvent.QuerySent -> {
            analytics.track("farmerchat_query", event.inputMethod)
        }
        is FarmerChatEvent.Error -> {
            Log.e("FarmerChat", "Error ${event.code}: ${event.message}")
        }
        else -> { /* handle other events as needed */ }
    }
}
```

## Full Example

```kotlin
// MyApp.kt
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        FarmerChat.initialize(
            context = this,
            apiKey = "fc_pub_your_api_key",
            config = FarmerChatConfig(
                primaryColor = 0xFF1B6B3A,
                headerTitle = "Farm Advisor",
                defaultLanguage = "en",
            )
        )

        FarmerChat.setEventCallback { event ->
            when (event) {
                is FarmerChatEvent.Error -> {
                    Log.w("App", "SDK error: ${event.code}")
                }
                else -> {}
            }
        }
    }
}

// MainActivity.kt
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MyAppTheme {
                Box(modifier = Modifier.fillMaxSize()) {
                    Scaffold { padding ->
                        Column(modifier = Modifier.padding(padding)) {
                            Text("My Farming App")
                        }
                    }

                    FarmerChatFAB(
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .padding(16.dp),
                    )
                }
            }
        }
    }
}
```

## Cleanup

When your app is shutting down or you need to release SDK resources:

```kotlin
FarmerChat.destroy()
```

After calling `destroy()`, you can re-initialize the SDK by calling `FarmerChat.initialize()` again.

## Configuration Options

| Parameter | Type | Default | Description |
|---|---|---|---|
| `baseUrl` | `String` | Production URL | FarmerChat API base URL |
| `primaryColor` | `Long` (ARGB) | `0xFF1B6B3A` | Primary brand color |
| `secondaryColor` | `Long` (ARGB) | `0xFFF0F7F2` | Secondary/accent color |
| `headerTitle` | `String` | `"FarmerChat"` | Chat screen toolbar title |
| `defaultLanguage` | `String?` | `null` (server-decided) | Default language code |
| `voiceInputEnabled` | `Boolean` | `true` | Enable voice input |
| `imageInputEnabled` | `Boolean` | `true` | Enable camera/gallery input |
| `historyEnabled` | `Boolean` | `true` | Enable chat history screen |
| `profileEnabled` | `Boolean` | `true` | Enable profile/settings screen |
| `showPoweredBy` | `Boolean` | `true` | Show "Powered by FarmerChat" |
| `cornerRadius` | `Int` | `12` | Corner radius for cards (dp) |
| `fontFamily` | `String` | `"System"` | Font family name |
| `partnerId` | `String?` | `null` | Partner ID for analytics |
| `maxMessagesInMemory` | `Int` | `50` | Max messages kept in memory |
| `requestTimeoutMs` | `Int` | `15000` | HTTP request timeout (ms) |
| `sseTimeoutMs` | `Int` | `30000` | SSE stream timeout (ms) |
| `sseReconnectAttempts` | `Int` | `1` | SSE reconnect attempts |
| `maxImageDimension` | `Int` | `300` | Max image preview size (dp) |
| `imageCompressionQuality` | `Int` | `80` | Image upload quality (0-100) |
| `imageSizeLimitBytes` | `Long` | `5242880` (5 MB) | Max image upload size |

## 16 KB Page Size

FarmerChat SDK is fully compliant with Android's 16 KB page size requirement. No additional configuration is needed.
