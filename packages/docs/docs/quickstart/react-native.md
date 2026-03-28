---
sidebar_position: 5
title: React Native
---

# React Native

Integrate FarmerChat into your React Native app using Expo.

## Prerequisites

- Expo SDK 55 or later
- React Native 0.76+
- React 19+
- Node.js 18+

## Installation

Install the SDK and its peer dependencies:

```bash
npx expo install @digitalgreenorg/farmerchat-react-native expo-image-picker
```

Or with npm/yarn:

```bash
npm install @digitalgreenorg/farmerchat-react-native
npx expo install expo-image-picker
```

### Peer Dependencies

| Package | Version |
|---|---|
| `expo` | `>= 55` |
| `expo-image-picker` | Latest |
| `react` | `>= 19` |
| `react-native` | `>= 0.76` |

## Configuration

Wrap your app (or the relevant portion) with the `<FarmerChat>` provider:

```tsx
import { FarmerChat } from '@digitalgreenorg/farmerchat-react-native';

export default function App() {
  return (
    <FarmerChat
      config={{
        apiKey: 'fc_pub_your_api_key',
      }}
    >
      {/* Your app content */}
    </FarmerChat>
  );
}
```

You can pass a full configuration object:

```tsx
<FarmerChat
  config={{
    apiKey: 'fc_pub_your_api_key',
    theme: {
      primaryColor: '#1B6B3A',
      secondaryColor: '#F0F7F2',
      cornerRadius: 16,
    },
    headerTitle: 'Crop Advisor',
    defaultLanguage: 'hi',
    voiceInputEnabled: true,
    imageInputEnabled: true,
    onEvent: (event) => {
      console.log('FarmerChat event:', event);
    },
  }}
>
  {/* ... */}
</FarmerChat>
```

See [Configuration Options](#configuration-options) below for the full list.

## Basic Usage

Add the floating action button and navigate to the chat screen:

```tsx
import React, { useState } from 'react';
import { View, Text } from 'react-native';
import {
  FarmerChat,
  FarmerChatFAB,
  ChatScreen,
} from '@digitalgreenorg/farmerchat-react-native';

export default function App() {
  const [showChat, setShowChat] = useState(false);

  return (
    <FarmerChat config={{ apiKey: 'fc_pub_your_api_key' }}>
      <View style={{ flex: 1 }}>
        {showChat ? (
          <ChatScreen onClose={() => setShowChat(false)} />
        ) : (
          <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
            <Text>Welcome to my app</Text>
          </View>
        )}

        {!showChat && (
          <FarmerChatFAB onPress={() => setShowChat(true)} />
        )}
      </View>
    </FarmerChat>
  );
}
```

The `FarmerChatFAB` is absolutely positioned in the bottom-right corner by default.

## Available Components

The SDK exports the following components:

| Component | Description |
|---|---|
| `FarmerChat` | Provider component -- wraps your app to provide SDK config |
| `FarmerChatFAB` | Floating action button |
| `ChatScreen` | Full chat interface |
| `OnboardingScreen` | Location and language selection |
| `HistoryScreen` | Chat history (server-fetched) |
| `ProfileScreen` | User profile and settings |
| `InputBar` | Text, voice, and image input bar |
| `ResponseCard` | AI response card |
| `ConnectivityBanner` | Offline state banner |
| `MarkdownContent` | Markdown rendering component |

## Available Hooks

| Hook | Description |
|---|---|
| `useChat()` | Chat state machine and SSE streaming management |
| `useConnectivity()` | Network connectivity state |
| `useVoice()` | Speech-to-text bridge |
| `useFarmerChatConfig()` | Access the current SDK config from any child component |

### useChat Example

```tsx
import { useChat } from '@digitalgreenorg/farmerchat-react-native';

function MyChatComponent() {
  const { messages, sendMessage, isStreaming } = useChat();

  return (
    <View>
      {messages.map((msg) => (
        <Text key={msg.id}>{msg.text}</Text>
      ))}
      {isStreaming && <Text>Thinking...</Text>}
    </View>
  );
}
```

## Event Listening

Pass an `onEvent` callback in the config:

```tsx
<FarmerChat
  config={{
    apiKey: 'fc_pub_your_api_key',
    onEvent: (event) => {
      switch (event.type) {
        case 'chat_opened':
          analytics.track('farmerchat_opened', { sessionId: event.sessionId });
          break;
        case 'query_sent':
          analytics.track('farmerchat_query', { method: event.inputMethod });
          break;
        case 'error':
          console.error(`FarmerChat [${event.code}]: ${event.message}`);
          break;
      }
    },
  }}
>
  {/* ... */}
</FarmerChat>
```

## Full Example

```tsx
import React, { useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import {
  FarmerChat,
  FarmerChatFAB,
  ChatScreen,
} from '@digitalgreenorg/farmerchat-react-native';
import type { FarmerChatConfig } from '@digitalgreenorg/farmerchat-react-native';

const config: FarmerChatConfig = {
  apiKey: 'fc_pub_your_api_key',
  theme: {
    primaryColor: '#1B6B3A',
    secondaryColor: '#F0F7F2',
  },
  headerTitle: 'Farm Advisor',
  defaultLanguage: 'en',
  onEvent: (event) => {
    if (event.type === 'error') {
      console.error(`SDK error [${event.code}]: ${event.message}`);
    }
  },
};

export default function App() {
  const [showChat, setShowChat] = useState(false);

  return (
    <FarmerChat config={config}>
      <View style={styles.container}>
        {showChat ? (
          <ChatScreen onClose={() => setShowChat(false)} />
        ) : (
          <View style={styles.content}>
            <Text style={styles.title}>My Farming App</Text>
          </View>
        )}

        {!showChat && (
          <FarmerChatFAB onPress={() => setShowChat(true)} />
        )}
      </View>
    </FarmerChat>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  title: { fontSize: 24, fontWeight: 'bold' },
});
```

## Re-exported Types

For convenience, the SDK re-exports core types:

```tsx
import type {
  FarmerChatConfig,
  ThemeConfig,
  CrashConfig,
  Message,
  Conversation,
  SDKEvent,
} from '@digitalgreenorg/farmerchat-react-native';
```

## Configuration Options

| Parameter | Type | Default | Description |
|---|---|---|---|
| `apiKey` | `string` | (required) | Partner API key from Digital Green |
| `baseUrl` | `string` | Production URL | FarmerChat API base URL |
| `partnerId` | `string` | -- | Partner ID for analytics |
| `sessionId` | `string` | Auto-generated | External session ID for correlation |
| `location` | `{ lat: number; lng: number }` | -- | User's location |
| `theme` | `ThemeConfig` | -- | UI theme customization |
| `crash` | `CrashConfig` | -- | Crash reporting configuration |
| `headerTitle` | `string` | `"FarmerChat"` | Chat screen header title |
| `defaultLanguage` | `string` | Server-decided | Default language code |
| `voiceInputEnabled` | `boolean` | `true` | Enable voice input |
| `imageInputEnabled` | `boolean` | `true` | Enable camera/gallery input |
| `historyEnabled` | `boolean` | `true` | Enable chat history screen |
| `profileEnabled` | `boolean` | `true` | Enable profile/settings screen |
| `showPoweredBy` | `boolean` | `true` | Show "Powered by FarmerChat" |
| `maxMessagesInMemory` | `number` | `50` | Max messages kept in memory |
| `requestTimeoutMs` | `number` | `15000` | HTTP request timeout (ms) |
| `sseReconnectAttempts` | `number` | `1` | SSE reconnect attempts |
| `maxImageDimension` | `number` | `300` | Max image preview size (dp) |
| `imageCompressionQuality` | `number` | `80` | Image upload quality (0-100) |
| `onEvent` | `(event: SDKEvent) => void` | -- | Global event callback |

### ThemeConfig

| Parameter | Type | Default | Description |
|---|---|---|---|
| `primaryColor` | `string` | `"#1B6B3A"` | Primary brand color (hex) |
| `secondaryColor` | `string` | -- | Secondary/accent color (hex) |
| `fontFamily` | `string` | System font | Custom font family name |
| `cornerRadius` | `number` | -- | Corner radius for cards/buttons (dp) |
