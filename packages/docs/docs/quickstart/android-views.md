---
sidebar_position: 2
title: Android (XML Views)
---

# Android (XML Views)

Integrate FarmerChat into your Android app using traditional XML Views and Fragments.

## Prerequisites

- Android Studio Ladybug (2024.2) or later
- AGP 9.1.0+ with built-in Kotlin support
- `compileSdk 36`, `minSdk 26`
- AppCompat and Material3 dependencies

## Installation

Add the dependency to your module-level `build.gradle.kts`:

```kotlin
dependencies {
    implementation("org.digitalgreen:farmerchat-views:1.0.0")
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

## Basic Usage

### Add the FAB to Your Layout

Include `FarmerChatFAB` in your activity or fragment layout XML:

```xml
<!-- activity_main.xml -->
<androidx.coordinatorlayout.widget.CoordinatorLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <!-- Your existing content -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="vertical">

        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="Welcome to my app" />
    </LinearLayout>

    <!-- FarmerChat FAB -->
    <org.digitalgreen.farmerchat.views.FarmerChatFAB
        android:id="@+id/fabFarmerChat"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom|end"
        android:layout_margin="16dp" />

</androidx.coordinatorlayout.widget.CoordinatorLayout>
```

### Launch the Chat

Wire up the FAB click to launch the chat activity:

```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val fab = findViewById<FarmerChatFAB>(R.id.fabFarmerChat)
        fab.setOnClickListener {
            val intent = Intent(this, FarmerChatActivity::class.java)
            startActivity(intent)
        }
    }
}
```

The `FarmerChatActivity` is a transparent-themed Activity that hosts all SDK fragments via the Navigation Component. It manages its own backstack, so it does not interfere with your app's navigation.

## Event Listening

Listen to SDK lifecycle events:

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
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val fab = findViewById<FarmerChatFAB>(R.id.fabFarmerChat)
        fab.setOnClickListener {
            startActivity(Intent(this, FarmerChatActivity::class.java))
        }
    }
}
```

```xml
<!-- activity_main.xml -->
<androidx.coordinatorlayout.widget.CoordinatorLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="center"
        android:text="My Farming App" />

    <org.digitalgreen.farmerchat.views.FarmerChatFAB
        android:id="@+id/fabFarmerChat"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom|end"
        android:layout_margin="16dp" />

</androidx.coordinatorlayout.widget.CoordinatorLayout>
```

## Cleanup

When your app is shutting down or you need to release SDK resources:

```kotlin
FarmerChat.destroy()
```

After calling `destroy()`, you can re-initialize the SDK by calling `FarmerChat.initialize()` again.

## Configuration Options

The `FarmerChatConfig` for the Views SDK is identical to the Compose SDK. See the [Android Compose configuration table](./android-compose#configuration-options) for the full list.

## 16 KB Page Size

FarmerChat SDK is fully compliant with Android's 16 KB page size requirement. No additional configuration is needed.
