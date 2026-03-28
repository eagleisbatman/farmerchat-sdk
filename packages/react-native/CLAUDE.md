# CLAUDE.md — packages/react-native

## Purpose
React Native SDK for FarmerChat. Expo Modules API. Published to npm.

## Architecture
- React components with hooks (useChat, useConnectivity, useVoice)
- State via useState/useReducer. No AsyncStorage.
- Networking via fetch + EventSource polyfill.
- Peer deps: expo-image-picker, expo (>= SDK 55).

## Key Components
- `FarmerChat.tsx` — Provider component (wraps config context)
- `FarmerChatFAB.tsx` — Pressable overlay FAB
- `screens/ChatScreen.tsx` — Main chat with FlatList
- `screens/OnboardingScreen.tsx` — Location + language
- `screens/HistoryScreen.tsx` — Chat history (server-fetched)
- `screens/ProfileScreen.tsx` — Profile/settings
- `components/InputBar.tsx` — Text + voice + camera
- `components/ResponseCard.tsx` — AI response rendering
- `components/ConnectivityBanner.tsx` — Offline state
- `hooks/useChat.ts` — Chat state machine + SSE management
- `hooks/useConnectivity.ts` — Network state hook
- `hooks/useVoice.ts` — STT bridge

## Rules
- No class components. Functional + hooks only.
- No AsyncStorage, no MMKV, no local persistence.
- expo-image-picker is a peerDependency, not bundled.
- All styles via StyleSheet.create, themed from config context.
- Test on Android + iOS simulators before merging.

## Commands
```bash
pnpm build   # tsc
pnpm test    # jest
pnpm lint    # eslint
```
