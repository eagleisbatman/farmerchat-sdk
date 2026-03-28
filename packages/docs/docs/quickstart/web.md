---
sidebar_position: 6
title: Web
---

# Web

Integrate FarmerChat into any web application using vanilla JavaScript or TypeScript.

## Prerequisites

- Any modern browser (Chrome, Firefox, Safari, Edge)
- No framework dependency required -- works with React, Vue, Angular, or plain HTML

## Installation

### npm / yarn / pnpm

```bash
npm install @digitalgreenorg/farmerchat-web
```

### CDN Script Tag

```html
<script src="https://cdn.jsdelivr.net/npm/@digitalgreenorg/farmerchat-web@1/dist/farmerchat.min.js"></script>
```

## Configuration

### ES Module Import

```typescript
import { FarmerChat } from '@digitalgreenorg/farmerchat-web';

const chat = new FarmerChat({
  apiKey: 'fc_pub_your_api_key',
});

chat.mount();
```

### Script Tag

```html
<script src="https://cdn.jsdelivr.net/npm/@digitalgreenorg/farmerchat-web@1/dist/farmerchat.min.js"></script>
<script>
  const chat = new FarmerChat({
    apiKey: 'fc_pub_your_api_key',
  });
  chat.mount();
</script>
```

You can pass a full configuration object:

```typescript
const chat = new FarmerChat({
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
});
```

See [Configuration Options](#configuration-options) below for the full list.

## Basic Usage

### Mount to Document Body (Default)

The simplest integration mounts the widget to `document.body`. A FAB appears in the bottom-right corner.

```typescript
import { FarmerChat } from '@digitalgreenorg/farmerchat-web';

const chat = new FarmerChat({
  apiKey: 'fc_pub_your_api_key',
});

// Mount widget to document.body
chat.mount();
```

### Mount to a Specific Element

You can mount the widget inside a specific container:

```typescript
const container = document.getElementById('chat-container');
chat.mount(container);
```

### Programmatic Control

Open and close the chat programmatically:

```typescript
// Open the chat
chat.open();

// Close the chat
chat.close();

// Destroy and unmount
chat.destroy();
```

## Style Isolation

The Web SDK uses [Shadow DOM](https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_shadow_DOM) to isolate its styles from your page. This means:

- FarmerChat styles will not leak into your page
- Your page styles will not affect FarmerChat's appearance
- No CSS class name conflicts

## Event Listening

Pass an `onEvent` callback in the config:

```typescript
const chat = new FarmerChat({
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
});
```

## Full Example

### Vanilla HTML

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>My Farm App</title>
</head>
<body>
  <h1>My Farming Application</h1>
  <p>Welcome! Click the chat button in the bottom-right corner to get farming advice.</p>

  <script src="https://cdn.jsdelivr.net/npm/@digitalgreenorg/farmerchat-web@1/dist/farmerchat.min.js"></script>
  <script>
    const chat = new FarmerChat({
      apiKey: 'fc_pub_your_api_key',
      theme: {
        primaryColor: '#1B6B3A',
      },
      headerTitle: 'Farm Advisor',
      defaultLanguage: 'en',
      onEvent: function (event) {
        if (event.type === 'error') {
          console.error('SDK error [' + event.code + ']: ' + event.message);
        }
      },
    });
    chat.mount();
  </script>
</body>
</html>
```

### React Integration

```tsx
import { useEffect, useRef } from 'react';
import { FarmerChat } from '@digitalgreenorg/farmerchat-web';

function FarmerChatWidget() {
  const chatRef = useRef<FarmerChat | null>(null);

  useEffect(() => {
    chatRef.current = new FarmerChat({
      apiKey: 'fc_pub_your_api_key',
      theme: { primaryColor: '#1B6B3A' },
    });
    chatRef.current.mount();

    return () => {
      chatRef.current?.destroy();
    };
  }, []);

  return null; // Widget mounts itself to document.body
}

export default function App() {
  return (
    <div>
      <h1>My Farming App</h1>
      <FarmerChatWidget />
    </div>
  );
}
```

### Vue Integration

```vue
<template>
  <div>
    <h1>My Farming App</h1>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted } from 'vue';
import { FarmerChat } from '@digitalgreenorg/farmerchat-web';

let chat;

onMounted(() => {
  chat = new FarmerChat({
    apiKey: 'fc_pub_your_api_key',
    theme: { primaryColor: '#1B6B3A' },
  });
  chat.mount();
});

onUnmounted(() => {
  chat?.destroy();
});
</script>
```

## Cleanup

Always call `destroy()` when the widget is no longer needed (for example, when the user navigates away from the page in a SPA):

```typescript
chat.destroy();
```

After calling `destroy()`, you can create a new `FarmerChat` instance and call `mount()` again.

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
| `maxImageDimension` | `number` | `300` | Max image preview size (px) |
| `imageCompressionQuality` | `number` | `80` | Image upload quality (0-100) |
| `onEvent` | `(event: SDKEvent) => void` | -- | Global event callback |

### ThemeConfig

| Parameter | Type | Default | Description |
|---|---|---|---|
| `primaryColor` | `string` | `"#1B6B3A"` | Primary brand color (hex) |
| `secondaryColor` | `string` | -- | Secondary/accent color (hex) |
| `fontFamily` | `string` | System font | Custom font family name |
| `cornerRadius` | `number` | -- | Corner radius for cards/buttons (px) |

## Browser Support

| Browser | Minimum Version |
|---|---|
| Chrome | 63+ |
| Firefox | 67+ |
| Safari | 13.1+ |
| Edge | 79+ |
