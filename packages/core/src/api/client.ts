import type { FarmerChatConfig } from '../types/config';
import type { Query, FeedbackPayload, Conversation, StarterQuestion, Language, OnboardingPayload } from '../types/messages';
import { FarmerChatError } from '../types/errors';
import { ErrorCodes } from '../constants/error-codes';
import { DEFAULTS } from '../constants/defaults';
import { Endpoints } from './endpoints';
import { withRetry } from './retry';
import { SSEParser, type SSEEvent } from './sse-parser';

/**
 * HTTP client abstraction for the FarmerChat API.
 * Uses the injected fetch function for platform compatibility.
 */
export class FarmerChatApiClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly timeoutMs: number;
  private readonly sseTimeoutMs: number;
  private readonly fetchFn: typeof fetch;
  private activeController: AbortController | null = null;

  constructor(config: FarmerChatConfig, fetchFn: typeof fetch = globalThis.fetch) {
    if (!config.apiKey) {
      throw new FarmerChatError(ErrorCodes.INVALID_CONFIG, 'apiKey must not be empty');
    }
    const baseUrl = config.baseUrl ?? DEFAULTS.baseUrl;
    if (!/^https?:\/\//i.test(baseUrl)) {
      throw new FarmerChatError(ErrorCodes.INVALID_CONFIG, 'baseUrl must use http:// or https://');
    }
    this.baseUrl = baseUrl;
    this.apiKey = config.apiKey;
    this.timeoutMs = config.requestTimeoutMs ?? DEFAULTS.requestTimeoutMs;
    this.sseTimeoutMs = DEFAULTS.sseTimeoutMs;
    this.fetchFn = fetchFn;
  }

  /**
   * Send a query and receive a response.
   * Automatically detects whether the server returns an SSE stream or a plain JSON response
   * based on the Content-Type header, and yields SSEEvent objects in both cases.
   */
  async *sendQuery(query: Query): AsyncGenerator<SSEEvent> {
    const url = `${this.baseUrl}${Endpoints.CHAT_SEND}`;
    const controller = new AbortController();
    this.activeController = controller;
    const timeout = setTimeout(() => controller.abort(), this.sseTimeoutMs);

    try {
      let response: globalThis.Response;
      try {
        response = await this.fetchFn(url, {
          method: 'POST',
          headers: this.headers(),
          body: JSON.stringify(query),
          signal: controller.signal,
        });
      } catch (error) {
        if (error instanceof DOMException && error.name === 'AbortError') {
          throw new FarmerChatError(ErrorCodes.TIMEOUT, 'SSE request timed out', { retryable: true });
        }
        throw new FarmerChatError(ErrorCodes.NETWORK_ERROR, 'Network request failed', {
          retryable: true,
          cause: error instanceof Error ? error : undefined,
        });
      }

      if (!response.ok) {
        throw this.handleHttpError(response.status);
      }

      const contentType = response.headers.get('Content-Type') ?? '';

      if (contentType.includes('text/event-stream')) {
        // SSE streaming path
        if (!response.body) {
          throw new FarmerChatError(ErrorCodes.NETWORK_ERROR, 'No response body');
        }

        const parser = new SSEParser();
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let receivedDone = false;

        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            const events = parser.feed(decoder.decode(value, { stream: true }));
            for (const event of events) {
              if (event.event === 'done') {
                receivedDone = true;
              }
              yield event;
            }
          }
        } catch (error) {
          if (error instanceof FarmerChatError) throw error;
          if (error instanceof DOMException && error.name === 'AbortError') {
            throw new FarmerChatError(ErrorCodes.TIMEOUT, 'SSE stream timed out', { retryable: true });
          }
          throw new FarmerChatError(ErrorCodes.SSE_DISCONNECT, 'Stream disconnected', {
            retryable: true,
            cause: error instanceof Error ? error : undefined,
          });
        }

        // Fallback done event if the stream ended without one
        if (!receivedDone) {
          yield { event: 'done', data: {} };
        }
      } else if (contentType.includes('application/json')) {
        // Non-streaming JSON path (canned answers, error messages, streaming disabled)
        let body: unknown;
        try {
          body = await response.json();
        } catch {
          throw new FarmerChatError(ErrorCodes.SERVER_ERROR, 'Invalid JSON response');
        }
        yield { event: 'message', data: body };
        yield { event: 'done', data: {} };
      } else {
        throw new FarmerChatError(
          ErrorCodes.UNKNOWN,
          `Unexpected Content-Type: ${contentType}`
        );
      }
    } finally {
      clearTimeout(timeout);
      this.activeController = null;
    }
  }

  /**
   * Abort the currently active streaming request.
   * No-op if no stream is in progress.
   */
  stopStream(): void {
    this.activeController?.abort();
    this.activeController = null;
  }

  /** Submit feedback for a response */
  async submitFeedback(feedback: FeedbackPayload): Promise<void> {
    const url = `${this.baseUrl}${Endpoints.FEEDBACK}`;
    const response = await withRetry(() =>
      this.fetchFn(url, {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify(feedback),
        signal: AbortSignal.timeout(this.timeoutMs),
      })
    );
    if (!response.ok) {
      throw this.handleHttpError(response.status);
    }
  }

  /** Fetch conversation history from the server */
  async getHistory(): Promise<Conversation[]> {
    const url = `${this.baseUrl}${Endpoints.HISTORY}`;
    const response = await withRetry(() =>
      this.fetchFn(url, {
        method: 'GET',
        headers: this.headers(),
        signal: AbortSignal.timeout(this.timeoutMs),
      })
    );
    if (!response.ok) {
      throw this.handleHttpError(response.status);
    }
    return response.json() as Promise<Conversation[]>;
  }

  /** Fetch starter questions for the empty chat state */
  async getStarters(language: string): Promise<StarterQuestion[]> {
    const url = `${this.baseUrl}${Endpoints.STARTERS}?lang=${encodeURIComponent(language)}`;
    const response = await withRetry(() =>
      this.fetchFn(url, {
        method: 'GET',
        headers: this.headers(),
        signal: AbortSignal.timeout(this.timeoutMs),
      })
    );
    if (!response.ok) {
      throw this.handleHttpError(response.status);
    }
    return response.json() as Promise<StarterQuestion[]>;
  }

  /** Submit onboarding data (location + language) */
  async submitOnboarding(data: OnboardingPayload): Promise<void> {
    const url = `${this.baseUrl}${Endpoints.ONBOARDING}`;
    const response = await withRetry(() =>
      this.fetchFn(url, {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify(data),
        signal: AbortSignal.timeout(this.timeoutMs),
      })
    );
    if (!response.ok) {
      throw this.handleHttpError(response.status);
    }
  }

  /** Convert text to speech audio */
  async textToSpeech(text: string, language: string): Promise<ArrayBuffer> {
    const url = `${this.baseUrl}${Endpoints.TTS}`;
    const response = await withRetry(() =>
      this.fetchFn(url, {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({ text, language }),
        signal: AbortSignal.timeout(this.timeoutMs),
      })
    );
    if (!response.ok) {
      throw this.handleHttpError(response.status);
    }
    return response.arrayBuffer();
  }

  /** Fetch available languages from the server */
  async getLanguages(): Promise<Language[]> {
    const url = `${this.baseUrl}${Endpoints.LANGUAGES}`;
    const response = await withRetry(() =>
      this.fetchFn(url, {
        method: 'GET',
        headers: this.headers(),
        signal: AbortSignal.timeout(this.timeoutMs),
      })
    );
    if (!response.ok) {
      throw this.handleHttpError(response.status);
    }
    return response.json() as Promise<Language[]>;
  }

  private headers(): Record<string, string> {
    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${this.apiKey}`,
      'X-SDK-Version': DEFAULTS.sdkVersion,
    };
  }

  private handleHttpError(status: number): FarmerChatError {
    switch (status) {
      case 401:
        return new FarmerChatError(ErrorCodes.AUTH_INVALID, 'Invalid or expired API key', {
          fatal: true,
          httpStatus: 401,
        });
      case 429:
        return new FarmerChatError(ErrorCodes.RATE_LIMITED, 'Too many requests', {
          httpStatus: 429,
          retryable: true,
        });
      case 500:
      case 503:
        return new FarmerChatError(ErrorCodes.SERVER_ERROR, 'Server error', {
          httpStatus: status,
          retryable: true,
        });
      default:
        return new FarmerChatError(ErrorCodes.UNKNOWN, `HTTP ${status}`, {
          httpStatus: status,
        });
    }
  }
}
