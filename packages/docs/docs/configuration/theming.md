---
sidebar_position: 1
title: Theming
---

# Theming

Customize FarmerChat's appearance to match your app's brand. The SDK provides theming options for colors, fonts, and corner radii across all platforms.

## How Theming Works

Each platform accepts a theme configuration at initialization time. The SDK applies these values to all its internal UI components -- chat bubbles, buttons, headers, input bars, and the floating action button.

All theme properties are optional. Omit any property to use the SDK's defaults (Digital Green green with system fonts).

## Android (Compose)

On Android Compose, theming is done via `FarmerChatConfig` properties. The SDK wraps its composables in a `FarmerChatTheme` that maps these values to `MaterialTheme.colorScheme`.

```kotlin
FarmerChat.initialize(
    context = this,
    apiKey = "fc_pub_your_api_key",
    config = FarmerChatConfig(
        // Colors as ARGB Long values
        primaryColor = 0xFF2E7D32,    // Dark green
        secondaryColor = 0xFFE8F5E9,  // Light green background

        // Typography
        fontFamily = "System",         // Use "System" for platform default

        // Shape
        cornerRadius = 16,             // Corner radius in dp
    )
)
```

### Color Format (Android)

Android colors are specified as `Long` values in ARGB format. The alpha channel is required:

```kotlin
// Correct: includes alpha (0xFF = fully opaque)
primaryColor = 0xFF1B6B3A

// Hex color "#1B6B3A" converts to:
primaryColor = 0xFF1B6B3A
```

Common conversions:

| Hex | ARGB Long |
|---|---|
| `#1B6B3A` | `0xFF1B6B3A` |
| `#F0F7F2` | `0xFFF0F7F2` |
| `#2E7D32` | `0xFF2E7D32` |
| `#FFFFFF` | `0xFFFFFFFF` |

## Android (XML Views)

The XML Views SDK uses the same `FarmerChatConfig` as Compose:

```kotlin
FarmerChat.initialize(
    context = this,
    apiKey = "fc_pub_your_api_key",
    config = FarmerChatConfig(
        primaryColor = 0xFF2E7D32,
        secondaryColor = 0xFFE8F5E9,
        cornerRadius = 16,
        fontFamily = "System",
    )
)
```

The SDK internally maps these values to XML styles extending Material3 components.

## iOS (SwiftUI and UIKit)

On iOS, theming is done via the `ThemeConfig` struct passed inside `FarmerChatConfig`:

```swift
FarmerChat.shared.initialize(config: FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    theme: ThemeConfig(
        primaryColor: "#2E7D32",
        secondaryColor: "#E8F5E9",
        fontFamily: "Avenir Next",
        cornerRadius: 16
    )
))
```

### Color Format (iOS)

iOS colors are specified as hex strings. The SDK converts them internally to `Color` (SwiftUI) or `UIColor` (UIKit):

```swift
ThemeConfig(
    primaryColor: "#1B6B3A",      // 6-digit hex
    secondaryColor: "#F0F7F2"
)
```

### Custom Fonts (iOS)

To use a custom font, make sure it is included in your app bundle and listed in `Info.plist` under `UIAppFonts`. Then pass the font family name:

```swift
ThemeConfig(
    fontFamily: "Avenir Next"    // Must be installed in the app
)
```

If the specified font is not found, the SDK falls back to the system font.

## React Native

On React Native, pass a `theme` object in the config:

```tsx
<FarmerChat
  config={{
    apiKey: 'fc_pub_your_api_key',
    theme: {
      primaryColor: '#2E7D32',
      secondaryColor: '#E8F5E9',
      fontFamily: 'Avenir Next',
      cornerRadius: 16,
    },
  }}
>
  {/* ... */}
</FarmerChat>
```

All styles in the SDK are generated from the theme config via `StyleSheet.create`, so changes are reflected throughout the entire widget.

## Web

On the Web, pass a `theme` object when constructing the `FarmerChat` instance:

```typescript
const chat = new FarmerChat({
  apiKey: 'fc_pub_your_api_key',
  theme: {
    primaryColor: '#2E7D32',
    secondaryColor: '#E8F5E9',
    fontFamily: 'Inter, sans-serif',
    cornerRadius: 16,
  },
});
chat.mount();
```

The Web SDK renders inside a Shadow DOM, so your theme values will not leak into the host page and your page's CSS will not affect the widget.

## ThemeConfig Reference

| Property | Type | Default | Description |
|---|---|---|---|
| `primaryColor` | Hex string (iOS/RN/Web) or ARGB Long (Android) | `#1B6B3A` / `0xFF1B6B3A` | Primary brand color. Used for the FAB, buttons, headers, and links. |
| `secondaryColor` | Hex string or ARGB Long | `#F0F7F2` / `0xFFF0F7F2` | Secondary color. Used for message backgrounds, highlights, and subtle accents. |
| `fontFamily` | `String` | System font | Font family name. Must be available on the target platform. |
| `cornerRadius` | `Int` / `Double` / `number` | `12` | Corner radius applied to cards, buttons, and input fields. Measured in dp (Android), pt (iOS), or px (Web). |

## What Gets Themed

The theme affects the following UI elements:

- **Floating Action Button** -- background uses `primaryColor`
- **Chat header / toolbar** -- background uses `primaryColor`
- **Send button** -- uses `primaryColor`
- **AI response cards** -- background uses `secondaryColor`
- **User message bubbles** -- background uses `primaryColor`
- **Input bar** -- border accent uses `primaryColor`
- **Links and interactive elements** -- colored with `primaryColor`
- **All rounded corners** -- use the configured `cornerRadius`
- **All text** -- uses the configured `fontFamily` (or system default)

## Additional Branding Options

Beyond `ThemeConfig`, you can also customize:

```kotlin
// Android
FarmerChatConfig(
    headerTitle = "My Farm Advisor",   // Custom header text
    showPoweredBy = false,             // Hide "Powered by FarmerChat"
)
```

```swift
// iOS
FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    headerTitle: "My Farm Advisor",
    showPoweredBy: false
)
```

```typescript
// Web / React Native
{
  headerTitle: 'My Farm Advisor',
  showPoweredBy: false,
}
```
