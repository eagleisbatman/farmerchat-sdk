import AsyncStorage from '@react-native-async-storage/async-storage';

const KEYS = {
  ACCESS_TOKEN:  '@fc_access_token',
  REFRESH_TOKEN: '@fc_refresh_token',
  USER_ID:       '@fc_user_id',
  DEVICE_ID:     '@fc_device_id',
} as const;

/**
 * AsyncStorage-backed token store.
 *
 * `device_id` is generated on first launch and never cleared.
 * `access_token`, `refresh_token`, `user_id` are cleared on `clearTokens()`.
 */
export const TokenStorage = {
  // ── Getters ───────────────────────────────────────────────────────────────

  async getAccessToken(): Promise<string> {
    return (await AsyncStorage.getItem(KEYS.ACCESS_TOKEN)) ?? '';
  },

  async getRefreshToken(): Promise<string> {
    return (await AsyncStorage.getItem(KEYS.REFRESH_TOKEN)) ?? '';
  },

  async getUserId(): Promise<string> {
    return (await AsyncStorage.getItem(KEYS.USER_ID)) ?? '';
  },

  async getDeviceId(): Promise<string> {
    let id = await AsyncStorage.getItem(KEYS.DEVICE_ID);
    if (!id) {
      id = generateUUID();
      await AsyncStorage.setItem(KEYS.DEVICE_ID, id);
    }
    return id;
  },

  async isInitialized(): Promise<boolean> {
    const token = await AsyncStorage.getItem(KEYS.ACCESS_TOKEN);
    return !!token && token.length > 0;
  },

  // ── Setters ───────────────────────────────────────────────────────────────

  async saveTokens(accessToken: string, refreshToken: string, userId: string): Promise<void> {
    await AsyncStorage.multiSet([
      [KEYS.ACCESS_TOKEN,  accessToken],
      [KEYS.REFRESH_TOKEN, refreshToken],
      [KEYS.USER_ID,       userId],
    ]);
  },

  async saveAccessToken(accessToken: string, refreshToken?: string): Promise<void> {
    const pairs: [string, string][] = [[KEYS.ACCESS_TOKEN, accessToken]];
    if (refreshToken) pairs.push([KEYS.REFRESH_TOKEN, refreshToken]);
    await AsyncStorage.multiSet(pairs);
  },

  async clearTokens(): Promise<void> {
    await AsyncStorage.multiRemove([KEYS.ACCESS_TOKEN, KEYS.REFRESH_TOKEN, KEYS.USER_ID]);
  },
};

function generateUUID(): string {
  const g = globalThis as { crypto?: { randomUUID?: () => string } };
  if (g.crypto?.randomUUID) return g.crypto.randomUUID();
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}
