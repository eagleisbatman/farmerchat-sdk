const K = {
  ACCESS:    'fc_access_token',
  REFRESH:   'fc_refresh_token',
  USER_ID:   'fc_user_id',
  DEVICE_ID: 'fc_device_id',
  COUNTRY:   'fc_country_code',
  STATE:     'fc_state',
  LANG:      'fc_selected_language',
  ONBOARDED: 'fc_onboarding_done',
} as const;

function uuid(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID();
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

function ls(): Storage | null {
  try { return localStorage; } catch { return null; }
}

export const TokenStore = {
  get accessToken(): string  { return ls()?.getItem(K.ACCESS) ?? ''; },
  get refreshToken(): string { return ls()?.getItem(K.REFRESH) ?? ''; },
  get userId(): string       { return ls()?.getItem(K.USER_ID) ?? ''; },
  get countryCode(): string  { return ls()?.getItem(K.COUNTRY) ?? ''; },
  get state(): string        { return ls()?.getItem(K.STATE) ?? ''; },
  get selectedLanguage(): string { return ls()?.getItem(K.LANG) ?? 'en'; },
  get isInitialized(): boolean { return !!ls()?.getItem(K.ACCESS); },
  get isOnboardingDone(): boolean { return ls()?.getItem(K.ONBOARDED) === 'true'; },

  get deviceId(): string {
    const store = ls();
    if (!store) return uuid();
    let id = store.getItem(K.DEVICE_ID);
    if (!id) { id = uuid(); store.setItem(K.DEVICE_ID, id); }
    return id;
  },

  saveTokens(access: string, refresh: string, userId: string, countryCode = '', state = ''): void {
    const store = ls();
    if (!store) return;
    store.setItem(K.ACCESS,   access);
    store.setItem(K.REFRESH,  refresh);
    store.setItem(K.USER_ID,  userId);
    if (countryCode) store.setItem(K.COUNTRY, countryCode);
    if (state)       store.setItem(K.STATE,   state);
  },

  saveAccessToken(access: string, refresh?: string): void {
    const store = ls();
    if (!store) return;
    store.setItem(K.ACCESS, access);
    if (refresh) store.setItem(K.REFRESH, refresh);
  },

  setLanguage(code: string): void { ls()?.setItem(K.LANG, code); },
  setOnboardingDone(): void       { ls()?.setItem(K.ONBOARDED, 'true'); },

  clear(): void {
    const store = ls();
    if (!store) return;
    [K.ACCESS, K.REFRESH, K.USER_ID, K.COUNTRY, K.STATE].forEach(k => store.removeItem(k));
  },
};
