import { GUEST_API_KEY, BUILD_VERSION } from '../config/constants';

/**
 * Adds all required auth headers to a `RequestInit`.
 * Called on every authenticated request.
 */
export function addAuthHeaders(
  init: RequestInit,
  accessToken: string,
  deviceInfo: string,
  sdkApiKey: string,
): RequestInit {
  return {
    ...init,
    headers: {
      ...(init.headers as Record<string, string>),
      'Content-Type':   'application/json',
      'Accept':         'application/json',
      'Authorization':  `Bearer ${accessToken}`,
      'X-SDK-Key':      sdkApiKey,
      'Build-Version':  BUILD_VERSION,
      'Device-Info':    deviceInfo,
    },
  };
}

/**
 * Adds the guest `API-Key` header (used only for `initialize_user` and `send_tokens`).
 */
export function addGuestApiKeyHeader(init: RequestInit): RequestInit {
  return {
    ...init,
    headers: {
      ...(init.headers as Record<string, string>),
      'Content-Type': 'application/json',
      'Accept':       'application/json',
      'Authorization': `Api-Key ${GUEST_API_KEY}`,
    },
  };
}
