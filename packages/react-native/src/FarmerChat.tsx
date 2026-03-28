import React, { createContext, useContext, useMemo } from 'react';
import type { FarmerChatConfig } from '@digitalgreenorg/farmerchat-core';

interface FarmerChatContextValue {
  config: FarmerChatConfig;
}

const FarmerChatContext = createContext<FarmerChatContextValue | null>(null);

export function useFarmerChatConfig() {
  const ctx = useContext(FarmerChatContext);
  if (!ctx) throw new Error('FarmerChat: wrap your app with <FarmerChat>');
  return ctx.config;
}

interface FarmerChatProps {
  config: FarmerChatConfig;
  children: React.ReactNode;
}

/**
 * Provider component for the FarmerChat SDK.
 * Wrap your app or screen with this to provide SDK configuration.
 */
export function FarmerChat({ config, children }: FarmerChatProps) {
  const value = useMemo(() => ({ config }), [config]);
  return (
    <FarmerChatContext.Provider value={value}>
      {children}
    </FarmerChatContext.Provider>
  );
}
