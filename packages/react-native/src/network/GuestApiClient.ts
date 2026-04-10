import { API_INITIALIZE_USER, GUEST_API_KEY } from '../config/constants';
import { TokenStorage } from './TokenStorage';
import type { InitializeGuestUserResponse } from '../models/responses';

/**
 * Standalone client for guest user initialisation.
 *
 * Uses `Authorization: Api-Key <key>` header — the only endpoint that does not
 * require a prior JWT token.
 *
 * Endpoint: `POST /api/user/initialize_user/`
 */
export const GuestApiClient = {
  /**
   * Initialize a guest user by device ID. Stores tokens in `TokenStorage`.
   */
  async initializeUser(baseUrl: string, deviceId: string): Promise<InitializeGuestUserResponse> {
    const url = `${baseUrl}/${API_INITIALIZE_USER}`;
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type':  'application/json',
        'Accept':        'application/json',
        'Authorization': `Api-Key ${GUEST_API_KEY}`,
      },
      body: JSON.stringify({ device_id: deviceId }),
    });

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`initialize_user failed: HTTP ${response.status} ${body}`);
    }

    const data: InitializeGuestUserResponse = await response.json();

    await TokenStorage.saveTokens(
      data.access_token,
      data.refresh_token,
      data.user_id ?? '',
    );

    return data;
  },

  /**
   * Ensure tokens exist. If not, call `initializeUser`.
   * Called by `FarmerChatSDK.ensureTokens()` and before every API call.
   */
  async ensureTokens(baseUrl: string): Promise<void> {
    const initialized = await TokenStorage.isInitialized();
    if (!initialized) {
      const deviceId = await TokenStorage.getDeviceId();
      await GuestApiClient.initializeUser(baseUrl, deviceId);
    }
  },
};
