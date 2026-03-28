// Provider & FAB
export { FarmerChat, useFarmerChatConfig } from './FarmerChat';
export { FarmerChatFAB } from './FarmerChatFAB';

// Screens
export { ChatScreen } from './screens/ChatScreen';
export { OnboardingScreen } from './screens/OnboardingScreen';
export { HistoryScreen } from './screens/HistoryScreen';
export { ProfileScreen } from './screens/ProfileScreen';

// Components
export { InputBar } from './components/InputBar';
export { ResponseCard } from './components/ResponseCard';
export { ConnectivityBanner } from './components/ConnectivityBanner';
export { MarkdownContent } from './components/MarkdownContent';

// Hooks
export { useChat } from './hooks/useChat';
export { useConnectivity } from './hooks/useConnectivity';
export { useVoice } from './hooks/useVoice';

// Re-export core types for convenience
export type {
  FarmerChatConfig,
  ThemeConfig,
  CrashConfig,
  Message,
  Conversation,
  Query,
  FeedbackPayload,
  FollowUpQuestion,
  StarterQuestion,
  SDKEvent,
  MarkdownDocument,
} from '@digitalgreenorg/farmerchat-core';
