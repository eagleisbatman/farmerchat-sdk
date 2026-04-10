import React from 'react';
import { ChatProvider, useChatContext } from './ChatProvider';
import { ChatScreen } from './screens/ChatScreen';
import { HistoryScreen } from './screens/HistoryScreen';
import { OnboardingScreen } from './screens/OnboardingScreen';
import { ProfileScreen } from './screens/ProfileScreen';

/**
 * Root FarmerChat UI component.
 *
 * Manages a single shared chat-state instance (via [ChatProvider]) and routes
 * to the correct screen based on `currentScreen`:
 *
 *   onboarding → [OnboardingScreen]  (first launch — language selection)
 *   chat        → [ChatScreen]       (main chat)
 *   history     → [HistoryScreen]    (past conversations)
 *   profile     → [ProfileScreen]    (settings / language change)
 *
 * **Usage in your navigation:**
 * ```tsx
 * // chat.tsx (expo-router) or equivalent
 * import { FarmerChatView } from '@digitalgreenorg/farmerchat-react-native';
 *
 * export default function ChatRoute() {
 *   return <FarmerChatView />;
 * }
 * ```
 *
 * The [FarmerChat] provider (SDK config context) must be an ancestor.
 */
export function FarmerChatView() {
  return (
    <ChatProvider>
      <ChatScreenRouter />
    </ChatProvider>
  );
}

function ChatScreenRouter() {
  const { currentScreen } = useChatContext();

  switch (currentScreen) {
    case 'onboarding':
      return <OnboardingScreen />;
    case 'history':
      return <HistoryScreen />;
    case 'profile':
      return <ProfileScreen />;
    default:
      return <ChatScreen />;
  }
}
