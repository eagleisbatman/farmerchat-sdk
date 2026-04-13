import { TokenStorage } from '../network/TokenStorage';
import { GuestApiClient } from '../network/GuestApiClient';

export interface SDKConfiguration {
  /** API key for the FarmerChat SDK (format: fc_live_... or fc_test_...). */
  sdkApiKey: string;
  /** Alias for sdkApiKey — accepted for convenience. */
  apiKey?: string;
  /** Base URL of the FarmerChat API server. */
  baseUrl: string;
  /** Optional content-provider ID scoped to your deployment. */
  contentProviderId?: string;
  /** Pre-selected language code (BCP-47). If set, onboarding is skipped. */
  defaultLanguage?: string;
  /** Chat widget header title shown in the top bar. */
  headerTitle?: string;
  /** Visual theme overrides. */
  theme?: {
    primaryColor?: string;
    secondaryColor?: string;
    cornerRadius?: number;
  };

  // ── Weather Widget ────────────────────────────────────────────────────
  /** Primary weather text (e.g. "28°C ☀️"). When undefined the widget is hidden. */
  weatherTemp?: string;
  /** Location label below the temperature (e.g. "Coorg, Karnataka"). */
  weatherLocation?: string;
  /** Crop chip text on the weather card (e.g. "Rice"). */
  cropName?: string;
}

/** Validates the SDK API key format. Warns (does not throw) for non-production keys. */
function validateApiKey(key: string): void {
  if (!key || key === 'demo-key') return; // Allow placeholder keys in development
  if (!key.match(/^fc_(live|test)_[A-Za-z0-9]{16,}$/)) {
    console.warn(
      `[FarmerChat] Unexpected sdkApiKey format. Expected fc_live_<16+ chars> or fc_test_<16+ chars>, got: "${key}"`,
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
      // Accept both sdkApiKey and the legacy apiKey alias
      const resolvedKey = config.sdkApiKey || config.apiKey || '';
      validateApiKey(resolvedKey);
      _config = {
        ...config,
        sdkApiKey: resolvedKey,
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
