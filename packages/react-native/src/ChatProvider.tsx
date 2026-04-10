import React, { createContext, useContext } from 'react';
import { useChat } from './hooks/useChat';
import type { UseChatReturn } from './hooks/useChat';

/**
 * React context that holds a single shared [UseChatReturn] instance.
 *
 * Wrap your chat UI hierarchy with [ChatProvider] so that every screen
 * (ChatScreen, HistoryScreen, OnboardingScreen, ProfileScreen) reads from
 * the same state and navigation works correctly.
 *
 * The [FarmerChatView] component does this automatically — you only need to
 * use [ChatProvider] directly if you compose screens yourself.
 */
const ChatContext = createContext<UseChatReturn | null>(null);

interface ChatProviderProps {
  children: React.ReactNode;
}

export function ChatProvider({ children }: ChatProviderProps) {
  const chat = useChat();
  return <ChatContext.Provider value={chat}>{children}</ChatContext.Provider>;
}

/**
 * Read the shared chat state created by the nearest [ChatProvider].
 *
 * @throws if called outside of a [ChatProvider] / [FarmerChatView].
 */
export function useChatContext(): UseChatReturn {
  const ctx = useContext(ChatContext);
  if (!ctx) {
    throw new Error(
      'useChatContext must be called inside <ChatProvider> or <FarmerChatView>. ' +
      'Wrap your screen with <FarmerChatView> to enable shared navigation state.',
    );
  }
  return ctx;
}
