---
slug: /
sidebar_position: 1
title: Introduction
---

# FarmerChat SDK

AI-powered agricultural advisory chat widget for your mobile and web applications.

## Overview

FarmerChat SDK provides an embeddable chat interface that connects your users to Digital Green's agricultural AI advisory platform. Drop in a floating action button, and your users get access to expert farming advice powered by AI -- with real-time streaming responses, voice input, image support, and multi-language coverage.

### Supported Platforms

| Platform | Package | Min Version |
|---|---|---|
| **Android (Compose)** | `org.digitalgreen:farmerchat-compose` | API 26 (Android 8.0) |
| **Android (XML Views)** | `org.digitalgreen:farmerchat-views` | API 26 (Android 8.0) |
| **iOS (SwiftUI)** | `FarmerChatSwiftUI` (SPM) | iOS 16.0 |
| **iOS (UIKit)** | `FarmerChatUIKit` (SPM) | iOS 15.0 |
| **React Native** | `@digitalgreenorg/farmerchat-react-native` | Expo SDK 55+, RN 0.76+ |
| **Web** | `@digitalgreenorg/farmerchat-web` | Modern browsers |

## Features

- **Streaming AI responses** -- Answers appear in real-time via Server-Sent Events (SSE)
- **Voice input** -- Speech-to-text for hands-free querying
- **Image input** -- Snap a photo of a crop and ask about it
- **Multi-language support** -- Languages are fetched from the server; bundled list as fallback
- **Offline state handling** -- Clear "No connection" UI when the device is offline
- **Pluggable crash reporting** -- Automatically detects Firebase Crashlytics, Sentry, or Bugsnag
- **Customizable theming** -- Match the SDK to your app's brand colors and fonts
- **Chat history** -- Server-side conversation history, no local storage
- **Onboarding flow** -- Location and language selection on first launch

## Design Principles

FarmerChat SDK is built with these constraints:

- **Lightweight** -- SDK binary is under 3 MB per platform. No heavyweight dependencies.
- **Online-only** -- All data comes from the server. No local database, no offline queue.
- **Crash-safe** -- Every SDK code path runs inside try-catch boundaries. The SDK will never crash your host app.
- **Memory-efficient** -- Under 40 MB when the chat is active, under 5 MB when idle (FAB only).
- **Platform-native networking** -- Uses `HttpURLConnection` on Android, `URLSession` on iOS, and `fetch` on Web/React Native. No third-party HTTP libraries.

## Getting Started

Pick your platform and follow the quickstart guide:

- [Android (Jetpack Compose)](./quickstart/android-compose)
- [Android (XML Views)](./quickstart/android-views)
- [iOS (SwiftUI)](./quickstart/ios-swiftui)
- [iOS (UIKit)](./quickstart/ios-uikit)
- [React Native](./quickstart/react-native)
- [Web](./quickstart/web)

## Getting an API Key

Contact [Digital Green](https://www.digitalgreen.org) to obtain a partner API key (`fc_pub_xxx`). You will need this key to initialize the SDK on any platform.
