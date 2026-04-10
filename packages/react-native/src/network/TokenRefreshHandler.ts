import { API_GET_NEW_ACCESS_TOKEN, API_SEND_TOKENS, GUEST_API_KEY } from '../config/constants';
import { TokenStorage } from './TokenStorage';

/**
 * Handles JWT token refresh with a 2-step fallback.
 *
 * A promise mutex ensures only **one** refresh runs at a time.
 * All concurrent callers await the same in-flight promise.
 *
 * Step 1: POST /api/user/get_new_access_token/ with `refresh_token`
 * Step 2 (fallback): POST /api/user/send_tokens/ with `device_id` + `user_id`
 */
export class TokenRefreshHandler {
  private baseUrl: string;
  private sdkApiKey: string;
  private refreshPromise: Promise<string> | null = null;

  constructor(baseUrl: string, sdkApiKey: string) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.sdkApiKey = sdkApiKey;
  }

  /**
   * Refresh tokens. Returns the new access token.
   * If a refresh is already in-flight, returns the same promise.
   */
  async refreshIfNeeded(): Promise<string> {
    if (this.refreshPromise) return this.refreshPromise;

    this.refreshPromise = this.performRefresh().finally(() => {
      this.refreshPromise = null;
    });

    return this.refreshPromise;
  }

  private async performRefresh(): Promise<string> {
    const token = await this.tryPrimaryRefresh();
    if (token) return token;

    const fallback = await this.tryFallbackRefresh();
    if (fallback) return fallback;

    throw new Error('Token refresh failed after both steps');
  }

  private async tryPrimaryRefresh(): Promise<string | null> {
    try {
      const refreshToken = await TokenStorage.getRefreshToken();
      const response = await fetch(`${this.baseUrl}/${API_GET_NEW_ACCESS_TOKEN}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-SDK-Key':    this.sdkApiKey,
        },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });

      if (!response.ok) return null;

      const data: { access_token?: string; refresh_token?: string } = await response.json();
      if (!data.access_token) return null;

      await TokenStorage.saveAccessToken(data.access_token, data.refresh_token);
      return data.access_token;
    } catch {
      return null;
    }
  }

  private async tryFallbackRefresh(): Promise<string | null> {
    try {
      const deviceId = await TokenStorage.getDeviceId();
      const userId   = await TokenStorage.getUserId();

      const response = await fetch(`${this.baseUrl}/${API_SEND_TOKENS}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'API-Key':      GUEST_API_KEY,
        },
        body: JSON.stringify({ device_id: deviceId, user_id: userId }),
      });

      if (!response.ok) return null;

      const data: { access_token?: string; refresh_token?: string } = await response.json();
      if (!data.access_token) return null;

      await TokenStorage.saveAccessToken(data.access_token, data.refresh_token);
      return data.access_token;
    } catch {
      return null;
    }
  }
}
