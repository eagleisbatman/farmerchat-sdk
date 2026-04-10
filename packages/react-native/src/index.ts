// Provider & FAB
export { FarmerChat, useFarmerChatConfig } from './FarmerChat';
export { FarmerChatFAB } from './FarmerChatFAB';
export { FarmerChatView } from './FarmerChatView';
export { ChatProvider, useChatContext } from './ChatProvider';

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

// SDK singleton & config
export { FarmerChatSDK } from './config/SDKConfig';
export type { SDKConfiguration } from './config/SDKConfig';

// Network layer (for advanced usage)
export { ChatApiClient } from './network/ChatApiClient';
export { TokenStorage } from './network/TokenStorage';
export { GuestApiClient } from './network/GuestApiClient';

// Models
export type * from './models/requests';
export type * from './models/responses';
