import {
  EP_INITIALIZE_USER, EP_REFRESH_TOKEN, EP_SEND_TOKENS,
  EP_NEW_CONVERSATION, EP_TEXT_PROMPT, EP_FOLLOW_UP_CLICK,
  EP_CONVERSATION_LIST, EP_CHAT_HISTORY,
  EP_SUPPORTED_LANGUAGES, EP_SET_LANGUAGE,
  GUEST_API_KEY, BUILD_VERSION,
} from './constants';
import { TokenStore } from './tokenStore';
import type {
  InitUserResponse, SupportedLanguageGroup, NewConversationResponse,
  TextPromptChunk, ConversationListItem, ChatHistoryResponse,
} from './models';

export class ApiClient {
  private base: string;
  private sdkApiKey: string;
  private refreshInFlight: Promise<string> | null = null;

  constructor(baseUrl: string, sdkApiKey: string) {
    this.base = baseUrl.replace(/\/$/, '');
    this.sdkApiKey = sdkApiKey;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  private authHeaders(token: string): Record<string, string> {
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': `Bearer ${token}`,
      'X-SDK-Key':     this.sdkApiKey,
      'Build-Version': BUILD_VERSION,
      'Device-Info':   JSON.stringify({ device_id: TokenStore.deviceId, platform: 'web', os: 'web' }),
    };
  }

  private async request<T>(path: string, init: RequestInit, retry = false): Promise<T> {
    const url = `${this.base}/${path}`;
    const res = await fetch(url, {
      ...init,
      headers: { ...this.authHeaders(TokenStore.accessToken), ...(init.headers as object ?? {}) },
    });

    if (res.status === 401 && !retry) {
      const fresh = await this.ensureRefresh();
      const r2 = await fetch(url, {
        ...init,
        headers: { ...this.authHeaders(fresh), ...(init.headers as object ?? {}) },
      });
      if (!r2.ok) throw new Error(`HTTP ${r2.status}`);
      return r2.json() as Promise<T>;
    }
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`HTTP ${res.status}: ${body}`);
    }
    return res.json() as Promise<T>;
  }

  private async get<T>(path: string, params: Record<string, string> = {}): Promise<T> {
    const qs = new URLSearchParams(params).toString();
    return this.request<T>(qs ? `${path}?${qs}` : path, { method: 'GET' });
  }

  private async post<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>(path, { method: 'POST', body: JSON.stringify(body) });
  }

  private async ensureRefresh(): Promise<string> {
    if (this.refreshInFlight) return this.refreshInFlight;
    this.refreshInFlight = this.doRefresh().finally(() => { this.refreshInFlight = null; });
    return this.refreshInFlight;
  }

  private async doRefresh(): Promise<string> {
    // Step 1: refresh token
    try {
      const res = await fetch(`${this.base}/${EP_REFRESH_TOKEN}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'X-SDK-Key': this.sdkApiKey },
        body: JSON.stringify({ refresh_token: TokenStore.refreshToken }),
      });
      if (res.ok) {
        const d: { access_token?: string; refresh_token?: string } = await res.json();
        if (d.access_token) { TokenStore.saveAccessToken(d.access_token, d.refresh_token); return d.access_token; }
      }
    } catch { /* fall through */ }

    // Step 2: fallback with device+user
    const res2 = await fetch(`${this.base}/${EP_SEND_TOKENS}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'API-Key': GUEST_API_KEY },
      body: JSON.stringify({ device_id: TokenStore.deviceId, user_id: TokenStore.userId }),
    });
    if (!res2.ok) throw new Error('Token refresh failed');
    const d2: { access_token?: string; refresh_token?: string } = await res2.json();
    if (!d2.access_token) throw new Error('No token in refresh response');
    TokenStore.saveAccessToken(d2.access_token, d2.refresh_token);
    return d2.access_token;
  }

  // ── Guest init ─────────────────────────────────────────────────────────────

  async initializeUser(): Promise<InitUserResponse> {
    const url = `${this.base}/${EP_INITIALIZE_USER}`;
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': `Api-Key ${GUEST_API_KEY}` },
      body: JSON.stringify({ device_id: TokenStore.deviceId }),
    });
    if (!res.ok) throw new Error(`initializeUser HTTP ${res.status}`);
    return res.json() as Promise<InitUserResponse>;
  }

  async ensureTokens(): Promise<void> {
    if (TokenStore.isInitialized) return;
    const d = await this.initializeUser();
    TokenStore.saveTokens(d.access_token, d.refresh_token, d.user_id, d.country_code, d.state);
  }

  // ── Languages ──────────────────────────────────────────────────────────────

  async getSupportedLanguages(): Promise<SupportedLanguageGroup[]> {
    await this.ensureTokens();
    const params: Record<string, string> = {};
    if (TokenStore.countryCode) params.country_code = TokenStore.countryCode;
    if (TokenStore.state)       params.state        = TokenStore.state;
    return this.get<SupportedLanguageGroup[]>(EP_SUPPORTED_LANGUAGES, params);
  }

  async setPreferredLanguage(languageId: string): Promise<void> {
    await this.ensureTokens();
    await this.post(EP_SET_LANGUAGE, { user_id: TokenStore.userId, language_id: languageId });
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  async newConversation(): Promise<NewConversationResponse> {
    await this.ensureTokens();
    return this.post<NewConversationResponse>(EP_NEW_CONVERSATION, {
      user_id: TokenStore.userId,
      language: TokenStore.selectedLanguage,
    });
  }

  /**
   * SSE streaming text prompt.
   * Returns a cleanup function (aborts the request).
   */
  streamTextPrompt(
    conversationId: string,
    text: string,
    messageReferenceId: string,
    onChunk: (chunk: TextPromptChunk) => void,
    onDone: () => void,
    onError: (err: Error) => void,
  ): () => void {
    const controller = new AbortController();
    const url = `${this.base}/${EP_TEXT_PROMPT}`;
    const body = JSON.stringify({
      conversation_id:      conversationId,
      query:                text,
      language:             TokenStore.selectedLanguage,
      message_reference_id: messageReferenceId,
      triggered_input_type: 'text',
      editable_transcription: true,
    });

    (async () => {
      try {
        await this.ensureTokens();
        const res = await fetch(url, {
          method: 'POST',
          signal: controller.signal,
          headers: this.authHeaders(TokenStore.accessToken),
          body,
        });
        if (!res.ok || !res.body) { onError(new Error(`HTTP ${res.status}`)); return; }

        const reader = res.body.getReader();
        const decoder = new TextDecoder();
        let buf = '';

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buf += decoder.decode(value, { stream: true });

          // Parse SSE lines
          const lines = buf.split('\n');
          buf = lines.pop() ?? '';
          let event = '';
          for (const line of lines) {
            if (line.startsWith('event:')) { event = line.slice(6).trim(); }
            else if (line.startsWith('data:')) {
              const data = line.slice(5).trim();
              if (data === '[DONE]') { onDone(); return; }
              try {
                const chunk: TextPromptChunk = JSON.parse(data);
                if (event === 'message' || !event) onChunk(chunk);
              } catch { /* skip malformed */ }
              event = '';
            }
          }
        }
        onDone();
      } catch (e) {
        if ((e as Error).name !== 'AbortError') onError(e as Error);
      }
    })();

    return () => controller.abort();
  }

  async trackFollowUpClick(conversationId: string, followUpId: string, text: string): Promise<void> {
    await this.post(EP_FOLLOW_UP_CLICK, {
      conversation_id:       conversationId,
      follow_up_question_id: followUpId,
      follow_up_text:        text,
      user_id:               TokenStore.userId,
    }).catch(() => { /* fire and forget */ });
  }

  // ── History ────────────────────────────────────────────────────────────────

  async getConversationList(): Promise<ConversationListItem[]> {
    await this.ensureTokens();
    return this.get<ConversationListItem[]>(EP_CONVERSATION_LIST, { user_id: TokenStore.userId, page: '1' });
  }

  async getChatHistory(conversationId: string): Promise<ChatHistoryResponse> {
    await this.ensureTokens();
    return this.get<ChatHistoryResponse>(EP_CHAT_HISTORY, { conversation_id: conversationId, page: '1' });
  }
}
