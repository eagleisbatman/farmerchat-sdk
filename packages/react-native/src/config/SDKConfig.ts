import { TokenStorage } from '../network/TokenStorage';
import { GuestApiClient } from '../network/GuestApiClient';

export interface SDKConfiguration {
  sdkApiKey: string;
  baseUrl: string;
  contentProviderId?: string;
}

/** Validates the SDK API key format. */
function validateApiKey(key: string): void {
  if (!key.match(/^fc_(live|test)_[A-Za-z0-9]{16,}$/)) {
    throw new Error(
      `Invalid sdkApiKey format. Expected fc_live_<16+ chars> or fc_test_<16+ chars>, got: "${key}"`
    );
  }
}

/**
 * FarmerChatSDK singleton.
 *
 * Call `configure()` once before using any components:
 * ```typescript
 * FarmerChatSDK.configure({
 *   baseUrl:   'https://farmerchat.farmstack.co/mobile-app-dev',
 *   sdkApiKey: 'fc_test_<your_key>',
 * });
 * ```
 */
export const FarmerChatSDK = (() => {
  let _config: SDKConfiguration | null = null;
  let _initPromise: Promise<void> | null = null;

  return {
    /**
     * Initialize the SDK. Must be called once before using any API client or components.
     * Starts background token initialization.
     */
    configure(config: SDKConfiguration): void {
      validateApiKey(config.sdkApiKey);
      _config = {
        ...config,
        baseUrl: config.baseUrl.replace(/\/$/, ''),
      };

      // Background: ensure guest tokens are ready
      _initPromise = (async () => {
        try {
          await GuestApiClient.ensureTokens(_config!.baseUrl);
        } catch {
          // Will retry on first API call
        }
      })();
    },

    /** Returns the current configuration. Throws if not configured. */
    getConfig(): SDKConfiguration {
      if (!_config) throw new Error('FarmerChatSDK.configure() must be called first');
      return _config;
    },

    /** Returns true if configure() has been called. */
    isConfigured(): boolean {
      return _config !== null;
    },

    /**
     * Awaited before every API call.
     * Ensures tokens exist — fetches guest tokens if not stored.
     */
    async ensureTokens(): Promise<void> {
      if (_initPromise) {
        await _initPromise;
        _initPromise = null;
      }
      if (!_config) throw new Error('FarmerChatSDK.configure() must be called first');
      await GuestApiClient.ensureTokens(_config.baseUrl);
    },

    /** Clear access/refresh tokens. Device ID is preserved. */
    async clearSession(): Promise<void> {
      await TokenStorage.clearTokens();
    },
  };
})();
