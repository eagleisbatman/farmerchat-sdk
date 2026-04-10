import React, { createContext, useContext, useEffect, useMemo } from 'react';
import { FarmerChatSDK } from './config/SDKConfig';
import type { SDKConfiguration } from './config/SDKConfig';

interface FarmerChatContextValue {
  config: SDKConfiguration;
}

const FarmerChatContext = createContext<FarmerChatContextValue | null>(null);

export function useFarmerChatConfig(): SDKConfiguration {
  const ctx = useContext(FarmerChatContext);
  if (!ctx) throw new Error('FarmerChat: wrap your app with <FarmerChat>');
  return ctx.config;
}

interface FarmerChatProps {
  /** SDK configuration — must include a valid `sdkApiKey`. */
  config: SDKConfiguration;
  children: React.ReactNode;
}

/**
 * Provider component for the FarmerChat SDK.
 *
 * Wraps your app (or chat screen) with the SDK configuration context.
 * Automatically calls `FarmerChatSDK.configure()` on first render.
 *
 * ```tsx
 * <FarmerChat config={{ baseUrl: '...', sdkApiKey: 'fc_test_...' }}>
 *   <FarmerChatFAB />
 * </FarmerChat>
 * ```
 */
export function FarmerChat({ config, children }: FarmerChatProps) {
  useEffect(() => {
    if (!FarmerChatSDK.isConfigured()) {
      FarmerChatSDK.configure(config);
    }
  }, [config]);

  const value = useMemo(() => ({ config }), [config]);

  return (
    <FarmerChatContext.Provider value={value}>
      {children}
    </FarmerChatContext.Provider>
  );
}
