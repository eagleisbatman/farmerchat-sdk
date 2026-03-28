---
sidebar_position: 3
title: Crash Reporting
---

# Crash Reporting

FarmerChat SDK automatically detects your app's crash reporting tool and forwards SDK errors through it. No configuration is needed in most cases.

## Zero-Config Detection

On SDK initialization, FarmerChat checks at runtime whether your app includes one of the supported crash reporting libraries. If found, the SDK uses it to report non-fatal errors, attach breadcrumbs, and set custom diagnostic keys.

### Supported Providers

| Provider | Android Detection | iOS Detection |
|---|---|---|
| **Firebase Crashlytics** | `Class.forName("com.google.firebase.crashlytics.FirebaseCrashlytics")` | `NSClassFromString("FIRCrashlytics")` |
| **Sentry** | `Class.forName("io.sentry.Sentry")` | `NSClassFromString("SentrySDK")` |
| **Bugsnag** | `Class.forName("com.bugsnag.android.Bugsnag")` | `NSClassFromString("Bugsnag")` |

Detection is performed in priority order: Firebase Crashlytics first, then Sentry, then Bugsnag. The first match wins.

If none of these libraries are present in your app, the SDK logs errors locally and continues operating normally. No crash reports are sent.

### What Gets Reported

The SDK reports the following to your crash provider:

- **Non-fatal errors** -- Network failures, SSE disconnects, parsing errors, and other recoverable issues
- **Breadcrumbs** -- SDK lifecycle events (chat opened, query sent, response received) are attached as breadcrumbs for context
- **Custom keys** -- The SDK sets diagnostic keys like `sdk_version` and `partner_id` on crash reports

The SDK never reports fatal crashes caused by the host app. It only reports errors that originate within the SDK itself.

## How It Works

### Android

On Android, the SDK uses Java reflection to check for crash provider classes on the classpath at runtime:

```
com.google.firebase.crashlytics.FirebaseCrashlytics  -> Firebase
io.sentry.Sentry                                      -> Sentry
com.bugsnag.android.Bugsnag                            -> Bugsnag
```

All reflection calls are wrapped in try-catch blocks. If a class is found but the method signatures have changed (due to a version update), the SDK gracefully falls back to no-op.

### iOS

On iOS, the SDK uses `NSClassFromString` to check for crash provider classes at runtime:

```
FIRCrashlytics  -> Firebase Crashlytics
SentrySDK       -> Sentry
Bugsnag         -> Bugsnag
```

All Objective-C runtime calls use `responds(to:)` checks before invoking selectors. If a class is found but the expected selectors are missing, the SDK gracefully falls back to no-op.

### React Native and Web

On React Native and Web, crash reporting is handled differently:

- **React Native**: The JavaScript layer catches all SDK errors via try-catch boundaries. If you have a global error handler (e.g., Sentry for React Native), it will capture unhandled errors as usual.
- **Web**: The SDK catches all errors internally. You can receive them via the `onEvent` callback and forward them to your own error tracking service.

## Custom Crash Reporter

If you use a crash reporting tool that is not automatically detected, or if you want full control over error reporting, you can provide a custom crash reporter.

### iOS

Implement the `CrashReporter` protocol:

```swift
class MyCustomCrashReporter: CrashReporter {
    func reportCrash(_ error: Error, breadcrumbs: [String]) {
        // Forward to your crash tool
        MyTool.report(error, context: breadcrumbs)
    }

    func addBreadcrumb(_ message: String) {
        MyTool.log(message)
    }

    func setCustomKey(_ key: String, value: String) {
        MyTool.setTag(key, value: value)
    }
}

// Pass it in the config
FarmerChat.shared.initialize(config: FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    crash: CrashConfig(
        enabled: true,
        reporter: MyCustomCrashReporter()
    )
))
```

### React Native / Web

Implement the `CrashReporter` interface:

```typescript
import type { CrashReporter } from '@digitalgreenorg/farmerchat-core';

const myReporter: CrashReporter = {
  reportCrash(error: Error, breadcrumbs: string[]) {
    MyTool.captureException(error, { breadcrumbs });
  },
  addBreadcrumb(message: string) {
    MyTool.addBreadcrumb({ message });
  },
  setCustomKey(key: string, value: string) {
    MyTool.setTag(key, value);
  },
};

// Pass it in the config
const config = {
  apiKey: 'fc_pub_your_api_key',
  crash: {
    enabled: true,
    reporter: myReporter,
  },
};
```

## Disabling Crash Reporting

If you want to disable crash reporting entirely:

### iOS

```swift
FarmerChat.shared.initialize(config: FarmerChatConfig(
    apiKey: "fc_pub_your_api_key",
    crash: CrashConfig(enabled: false)
))
```

### React Native / Web

```typescript
{
  apiKey: 'fc_pub_your_api_key',
  crash: {
    enabled: false,
  },
}
```

### Android

On Android, crash reporting is always enabled when a provider is detected. The overhead is negligible since all operations are non-blocking and wrapped in try-catch.

## Crash Safety Guarantee

Regardless of the crash reporting configuration, the SDK guarantees that it will never crash your host app. Every public API method and every internal code path is wrapped in try-catch (Kotlin/Swift) or error boundaries (React Native/Web).

If the SDK encounters a truly unrecoverable error (a `FATAL_CRASH`), it will:

1. Emit a `FATAL_CRASH` error event via the event callback
2. Auto-dismiss the chat widget
3. Recover gracefully on the next `open` call

Your app continues running normally throughout this process.

## Diagnostic Keys

When a crash provider is detected, the SDK sets these custom keys on all crash reports:

| Key | Value | Description |
|---|---|---|
| `sdk_version` | e.g., `"1.0.0"` | FarmerChat SDK version |
| `partner_id` | e.g., `"my_partner"` | Your partner ID (if set in config) |

These keys help you filter and triage SDK-related crash reports in your dashboard.
