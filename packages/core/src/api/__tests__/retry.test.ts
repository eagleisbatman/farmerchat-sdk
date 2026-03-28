import { describe, it, expect, vi } from 'vitest';
import { withRetry } from '../retry';

describe('withRetry', () => {
  it('returns immediately on success', async () => {
    const mockFetch = vi.fn().mockResolvedValue(new Response('ok', { status: 200 }));
    const result = await withRetry(mockFetch);
    expect(result.status).toBe(200);
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  it('retries on 500 errors', async () => {
    const mockFetch = vi
      .fn()
      .mockResolvedValueOnce(new Response('error', { status: 500 }))
      .mockResolvedValueOnce(new Response('ok', { status: 200 }));

    const result = await withRetry(mockFetch, { baseDelayMs: 1, maxRetries: 3 });
    expect(result.status).toBe(200);
    expect(mockFetch).toHaveBeenCalledTimes(2);
  });

  it('does not retry on 4xx errors', async () => {
    const mockFetch = vi.fn().mockResolvedValue(new Response('bad', { status: 400 }));
    const result = await withRetry(mockFetch);
    expect(result.status).toBe(400);
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  it('returns the 500 response after max retries exhausted', async () => {
    const mockFetch = vi.fn().mockResolvedValue(new Response('error', { status: 500 }));
    const result = await withRetry(mockFetch, { maxRetries: 2, baseDelayMs: 1 });
    // After exhausting retries, the final 500 response is returned to the caller
    expect(result.status).toBe(500);
    expect(mockFetch).toHaveBeenCalledTimes(3); // initial + 2 retries
  });

  it('respects custom retry config (maxRetries: 1, baseDelayMs: 100)', async () => {
    const mockFetch = vi
      .fn()
      .mockResolvedValueOnce(new Response('error', { status: 500 }))
      .mockResolvedValueOnce(new Response('ok', { status: 200 }));

    const start = Date.now();
    const result = await withRetry(mockFetch, { maxRetries: 1, baseDelayMs: 100 });
    const elapsed = Date.now() - start;

    expect(result.status).toBe(200);
    expect(mockFetch).toHaveBeenCalledTimes(2);
    // Should have waited at least ~100ms for the single retry
    expect(elapsed).toBeGreaterThanOrEqual(80); // allow small timer variance
  });

  it('does not retry on 429 (4xx status)', async () => {
    const mockFetch = vi.fn().mockResolvedValue(new Response('rate limited', { status: 429 }));
    const result = await withRetry(mockFetch, { maxRetries: 3, baseDelayMs: 1 });
    // 4xx errors are returned directly, not retried
    expect(result.status).toBe(429);
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  it('throws NETWORK_ERROR immediately when fetch throws (no retry)', async () => {
    const mockFetch = vi.fn().mockRejectedValue(new TypeError('Failed to fetch'));

    await expect(
      withRetry(mockFetch, { maxRetries: 3, baseDelayMs: 1 })
    ).rejects.toMatchObject({
      code: 'NETWORK_ERROR',
    });
    // Network errors are NOT retried — thrown immediately on first attempt
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  it('throws TIMEOUT when fetch is aborted', async () => {
    const abortError = new DOMException('The operation was aborted', 'AbortError');
    const mockFetch = vi.fn().mockRejectedValue(abortError);

    await expect(
      withRetry(mockFetch, { maxRetries: 3, baseDelayMs: 1 })
    ).rejects.toMatchObject({
      code: 'TIMEOUT',
    });
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });
});
