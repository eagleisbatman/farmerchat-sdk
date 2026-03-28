import { FarmerChatError } from '../types/errors';
import { ErrorCodes } from '../constants/error-codes';

/**
 * Configuration for retry behavior.
 */
export interface RetryConfig {
  /** Maximum number of retry attempts. Defaults to 3. */
  maxRetries?: number;

  /** Base delay in milliseconds. Defaults to 1000. */
  baseDelayMs?: number;

  /** Maximum delay in milliseconds. Defaults to 8000. */
  maxDelayMs?: number;
}

/**
 * Execute a fetch operation with exponential backoff retry.
 * Only retries on 5xx errors. Does NOT retry 4xx or network errors.
 */
export async function withRetry(
  fn: () => Promise<globalThis.Response>,
  config?: RetryConfig
): Promise<globalThis.Response> {
  const maxRetries = config?.maxRetries ?? 3;
  const baseDelay = config?.baseDelayMs ?? 1000;
  const maxDelay = config?.maxDelayMs ?? 8000;

  let lastError: Error | undefined;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const response = await fn();

      // Only retry on 5xx server errors
      if (response.status >= 500 && attempt < maxRetries) {
        lastError = new FarmerChatError(
          ErrorCodes.SERVER_ERROR,
          `Server error: ${response.status}`,
          { httpStatus: response.status }
        );
        const delay = Math.min(baseDelay * Math.pow(2, attempt), maxDelay);
        const jitteredDelay = delay * (0.5 + Math.random() * 0.5);
        await sleep(jitteredDelay);
        continue;
      }

      return response;
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') {
        throw new FarmerChatError(ErrorCodes.TIMEOUT, 'Request timed out', { retryable: true });
      }
      throw new FarmerChatError(ErrorCodes.NETWORK_ERROR, 'Network request failed', {
        retryable: true,
        cause: error instanceof Error ? error : undefined,
      });
    }
  }

  throw lastError ?? new FarmerChatError(ErrorCodes.SERVER_ERROR, 'Max retries exceeded');
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
