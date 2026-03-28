---
sidebar_position: 10
title: Error Codes
---

# Error Codes

All errors emitted by the FarmerChat SDK include a machine-readable `code` string. Use these codes to handle errors programmatically or to triage issues in your crash reporting dashboard.

## Listening for Errors

### Android

```kotlin
FarmerChat.setEventCallback { event ->
    when (event) {
        is FarmerChatEvent.Error -> {
            Log.e("FarmerChat", "[${event.code}] ${event.message} (fatal: ${event.fatal})")
        }
        else -> {}
    }
}
```

### iOS

```swift
FarmerChat.shared.initialize(config: FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    onEvent: { event in
        if case .error(let code, let message, let fatal, _) = event {
            print("FarmerChat [\(code)] \(message) (fatal: \(fatal))")
        }
    }
))
```

### React Native / Web

```typescript
onEvent: (event) => {
  if (event.type === 'error') {
    console.error(`FarmerChat [${event.code}] ${event.message} (fatal: ${event.fatal})`);
  }
}
```

## Error Code Reference

### Network Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `NETWORK_ERROR` | Network request failed (no connectivity, DNS failure, etc.) | Yes | Check device connectivity. The SDK shows a "No connection" banner automatically. |
| `TIMEOUT` | HTTP request timed out (default: 15 seconds) | Yes | Retry automatically. If persistent, check network quality. Timeout is configurable via `requestTimeoutMs`. |
| `SSE_DISCONNECT` | Server-Sent Events stream was interrupted mid-response | Yes | The SDK auto-reconnects up to `sseReconnectAttempts` times, then shows an error. |

### Authentication Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `AUTH_INVALID` | The provided API key is invalid or malformed | No | Verify your API key. Make sure you are using the correct key for your environment. |
| `AUTH_EXPIRED` | The API key has expired | No | Contact Digital Green to renew your API key. |

### Server Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `SERVER_ERROR` | Server returned a 5xx error | Yes | The SDK auto-retries up to 3 times with exponential backoff. If all retries fail, an error is shown to the user. |
| `RATE_LIMITED` | Server returned 429 (Too Many Requests) | Yes | The SDK respects the `Retry-After` header and auto-recovers. No action needed. |

### SDK Lifecycle Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `NOT_INITIALIZED` | An SDK method was called before `initialize()` | No | Call `FarmerChat.initialize()` (or wrap with `<FarmerChat>` on RN) before using any SDK feature. |
| `INVALID_CONFIG` | The configuration object contains invalid values | No | Check the config parameters. Common issues: empty API key, invalid base URL, negative timeout values. |
| `FATAL_CRASH` | An unrecoverable internal SDK error occurred | No | The widget auto-dismisses and recovers on the next open. The SDK will never crash your host app. |

### Permission Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `CAMERA_PERMISSION_DENIED` | Camera permission was denied by the user | No | Prompt the user to grant camera permission in device settings. The SDK disables image input gracefully. |
| `MICROPHONE_PERMISSION_DENIED` | Microphone permission was denied by the user | No | Prompt the user to grant microphone permission in device settings. The SDK disables voice input gracefully. |
| `LOCATION_PERMISSION_DENIED` | Location permission was denied by the user | No | The onboarding flow allows manual location entry as a fallback. |

### Speech and TTS Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `STT_UNAVAILABLE` | Speech-to-text is not available on this device | No | Voice input is disabled automatically. Text input remains available. |
| `TTS_UNAVAILABLE` | Text-to-speech is not available on this device | No | Audio playback of responses is disabled. Text responses remain visible. |
| `TTS_FAILED` | Text-to-speech playback failed | Yes | Retry playback. If persistent, the device may lack the required language pack. |

### Image Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `IMAGE_TOO_LARGE` | The selected image exceeds the size limit (default: 5 MB) | No | The SDK shows an error message. The user can select a smaller image. The limit is configurable via `imageSizeLimitBytes` (Android) or `imageCompressionQuality`. |
| `IMAGE_UPLOAD_FAILED` | Image upload to the server failed | Yes | Retry the upload. Check network connectivity. |

### Data Loading Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `HISTORY_LOAD_FAILED` | Failed to load chat history from the server | Yes | Retry on next screen visit. The chat screen remains functional without history. |
| `LANGUAGES_LOAD_FAILED` | Failed to load the language list from the server | Yes | The SDK falls back to the bundled language list. Functionality is not affected. |

### Session Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `SESSION_EXPIRED` | The current session has expired on the server | No | The SDK creates a new session automatically. In-progress conversations are preserved server-side. |

### Onboarding Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `ONBOARDING_FAILED` | The onboarding flow encountered an error (e.g., failed to save preferences) | Yes | Retry the onboarding step. If persistent, check network connectivity. |

### Generic Errors

| Code | Description | Retryable | Recovery |
|---|---|---|---|
| `UNKNOWN` | An unexpected error occurred that does not match any known code | Yes | Check the error `message` for details. Report to Digital Green if persistent. |

## Error Object Structure

All SDK errors share a common structure:

### TypeScript / React Native / Web

```typescript
interface FarmerChatError {
  code: string;        // One of the codes above
  message: string;     // Human-readable description
  fatal: boolean;      // If true, the SDK widget auto-dismisses
  retryable: boolean;  // If true, the operation can be retried
  httpStatus?: number; // HTTP status code, if applicable
}
```

### Kotlin (Android)

```kotlin
sealed interface FarmerChatEvent {
    data class Error(
        val code: String,
        val message: String,
        val fatal: Boolean = false,
        val timestamp: Long = System.currentTimeMillis(),
    ) : FarmerChatEvent
}
```

### Swift (iOS)

```swift
public enum FarmerChatEvent {
    case error(
        code: String,
        message: String,
        fatal: Bool,
        timestamp: Date
    )
}
```
