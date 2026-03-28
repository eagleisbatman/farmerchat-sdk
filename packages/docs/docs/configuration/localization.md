---
sidebar_position: 2
title: Localization
---

# Localization

FarmerChat supports multiple languages. The language list is fetched from the server at initialization, with a bundled fallback for offline or slow-network scenarios.

## How Languages Work

1. **On SDK initialization**, the SDK fetches the current list of supported languages from the FarmerChat API.
2. **If the network request fails**, the SDK falls back to a bundled language list.
3. **The user selects their preferred language** during the onboarding flow (first launch) or later in the profile/settings screen.
4. **All AI responses are returned in the selected language** by the server.

The SDK itself does not perform any on-device translation. Language selection is sent to the server, which returns content in that language.

## Bundled Fallback Languages

When the server is unreachable, the SDK uses this built-in list:

| Code | Language | Native Name |
|---|---|---|
| `en` | English | English |
| `hi` | Hindi | हिन्दी |
| `mr` | Marathi | मराठी |
| `te` | Telugu | తెలుగు |
| `ta` | Tamil | தமிழ் |
| `kn` | Kannada | ಕನ್ನಡ |
| `sw` | Swahili | Kiswahili |
| `fr` | French | Français |
| `pt` | Portuguese | Português |
| `am` | Amharic | አማርኛ |

The server may return additional languages not in this list. The bundled list is a fallback only.

## Setting a Default Language

You can set a default language at initialization time. If set, the SDK skips the language selection step in onboarding and uses the specified language immediately.

### Android

```kotlin
FarmerChat.initialize(
    context = this,
    apiKey = "fc_pub_your_api_key",
    config = FarmerChatConfig(
        defaultLanguage = "hi"  // Hindi
    )
)
```

### iOS

```swift
FarmerChat.shared.initialize(config: FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    defaultLanguage: "hi"
))
```

### React Native

```tsx
<FarmerChat
  config={{
    apiKey: 'fc_pub_your_api_key',
    defaultLanguage: 'hi',
  }}
>
  {/* ... */}
</FarmerChat>
```

### Web

```typescript
const chat = new FarmerChat({
  apiKey: 'fc_pub_your_api_key',
  defaultLanguage: 'hi',
});
```

## Language Change Events

When the user changes their language (via the settings screen), the SDK emits a `language_changed` event:

### Android

Language change events are not yet available in the Android `FarmerChatEvent` sealed interface. This will be added in a future release. In the meantime, you can detect language changes by observing the config state or using the `onEvent` callback at the SDK level once it is supported.

### iOS

```swift
FarmerChat.shared.initialize(config: FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    onEvent: { event in
        if case .languageChanged(let from, let to, _) = event {
            print("Language changed from \(from) to \(to)")
        }
    }
))
```

### React Native / Web

```typescript
onEvent: (event) => {
  if (event.type === 'language_changed') {
    console.log(`Language changed from ${event.from} to ${event.to}`);
  }
}
```

## Behavior When `defaultLanguage` Is Not Set

If you do not set `defaultLanguage`:

1. The SDK fetches the language list from the server.
2. During onboarding, the user is presented with a language picker.
3. The user's selection is stored in-memory for the current session.
4. On subsequent sessions, the onboarding flow is shown again (since the SDK does not persist state locally -- all history is server-side).

## Right-to-Left (RTL) Support

The SDK respects the platform's RTL layout direction. If the user's selected language or device locale is RTL, the chat UI automatically mirrors its layout. No additional configuration is needed.

## UI Strings

All user-facing strings in the SDK UI (button labels, placeholder text, error messages) are served from the FarmerChat API alongside the language list. This allows Digital Green to update translations without requiring an SDK update.

The SDK ships with English-only fallback strings for its UI chrome (buttons, labels) in case the API is unreachable.
