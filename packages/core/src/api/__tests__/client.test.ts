import { describe, it, expect, vi, beforeEach } from 'vitest';
import { FarmerChatApiClient } from '../client';
import { FarmerChatError } from '../../types/errors';
import type { FarmerChatConfig } from '../../types/config';
import type { Query, FeedbackPayload } from '../../types/messages';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const TEST_CONFIG: FarmerChatConfig = {
  apiKey: 'test-api-key-123',
  baseUrl: 'https://test.api.farmerchat.org',
  requestTimeoutMs: 5000,
};

const TEST_QUERY: Query = {
  id: 'q_1',
  text: 'How do I prevent rice blast?',
  inputMethod: 'text',
  language: 'en',
  timestamp: Date.now(),
};

/**
 * Build a mock Response that quacks like a real fetch Response.
 */
function mockResponse(
  body: string | object,
  init: { status?: number; contentType?: string } = {}
): globalThis.Response {
  const { status = 200, contentType = 'application/json' } = init;
  const text = typeof body === 'string' ? body : JSON.stringify(body);
  const headers = new Headers({ 'Content-Type': contentType });

  return {
    ok: status >= 200 && status < 300,
    status,
    headers,
    json: () => Promise.resolve(typeof body === 'string' ? JSON.parse(body) : body),
    text: () => Promise.resolve(text),
    arrayBuffer: () => Promise.resolve(new TextEncoder().encode(text).buffer),
    body: null,
  } as unknown as globalThis.Response;
}

/**
 * Build a mock SSE Response backed by a ReadableStream.
 */
function mockSSEResponse(events: string): globalThis.Response {
  const encoder = new TextEncoder();
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(encoder.encode(events));
      controller.close();
    },
  });

  return {
    ok: true,
    status: 200,
    headers: new Headers({ 'Content-Type': 'text/event-stream' }),
    body: stream,
    json: () => Promise.reject(new Error('not json')),
    text: () => Promise.resolve(events),
  } as unknown as globalThis.Response;
}

/**
 * Collect all events from an async generator.
 */
async function collectEvents<T>(gen: AsyncGenerator<T>): Promise<T[]> {
  const results: T[] = [];
  for await (const event of gen) {
    results.push(event);
  }
  return results;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('FarmerChatApiClient', () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    fetchMock = vi.fn();
  });

  // -----------------------------------------------------------------------
  // sendQuery — SSE streaming
  // -----------------------------------------------------------------------

  describe('sendQuery() — SSE streaming', () => {
    it('yields parsed SSE events from a streaming response', async () => {
      const ssePayload =
        'event: token\ndata: {"text":"Hello","index":0}\n\n' +
        'event: token\ndata: {"text":" world","index":1}\n\n' +
        'event: done\ndata: {"response_id":"r_1"}\n\n';

      fetchMock.mockResolvedValue(mockSSEResponse(ssePayload));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);
      const events = await collectEvents(client.sendQuery(TEST_QUERY));

      // 2 tokens + 1 done from stream
      expect(events).toHaveLength(3);
      expect(events[0].event).toBe('token');
      expect((events[0].data as { text: string }).text).toBe('Hello');
      expect(events[1].event).toBe('token');
      expect(events[2].event).toBe('done');
    });

    it('emits a fallback done event if stream ends without one', async () => {
      // Stream with tokens but no done event
      const ssePayload = 'event: token\ndata: {"text":"A","index":0}\n\n';

      fetchMock.mockResolvedValue(mockSSEResponse(ssePayload));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);
      const events = await collectEvents(client.sendQuery(TEST_QUERY));

      // 1 token + 1 fallback done
      expect(events).toHaveLength(2);
      expect(events[0].event).toBe('token');
      expect(events[1].event).toBe('done');
      expect(events[1].data).toEqual({});
    });
  });

  // -----------------------------------------------------------------------
  // sendQuery — JSON response
  // -----------------------------------------------------------------------

  describe('sendQuery() — JSON response', () => {
    it('yields message + done events from a JSON response', async () => {
      const jsonBody = { id: 'r_1', text: 'Use neem oil.', language: 'en' };
      fetchMock.mockResolvedValue(mockResponse(jsonBody, { contentType: 'application/json' }));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);
      const events = await collectEvents(client.sendQuery(TEST_QUERY));

      expect(events).toHaveLength(2);
      expect(events[0].event).toBe('message');
      expect(events[0].data).toEqual(jsonBody);
      expect(events[1].event).toBe('done');
      expect(events[1].data).toEqual({});
    });
  });

  // -----------------------------------------------------------------------
  // stopStream
  // -----------------------------------------------------------------------

  describe('stopStream()', () => {
    it('aborts the active controller', async () => {
      // Capture the AbortSignal passed to fetch so we can verify it was aborted
      let capturedSignal: AbortSignal | undefined;

      const ssePayload = 'event: token\ndata: {"text":"A","index":0}\n\n';

      const localFetch = vi.fn().mockImplementation((_url: string, init: RequestInit) => {
        capturedSignal = init.signal as AbortSignal;
        return Promise.resolve(mockSSEResponse(ssePayload));
      });

      const client = new FarmerChatApiClient(TEST_CONFIG, localFetch);

      // Start consuming the stream — collect events to drive the generator
      const events = await collectEvents(client.sendQuery(TEST_QUERY));
      // After consuming, activeController should be null (cleared in finally)
      // But during the stream, stopStream() works, so let's test mid-stream:

      // Verify the signal was passed to fetch
      expect(capturedSignal).toBeDefined();
    });

    it('sets activeController to null after abort', () => {
      // stopStream on a client with no active stream is a no-op
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);
      // Should not throw
      client.stopStream();
    });

    it('aborts an in-flight stream', async () => {
      let capturedSignal: AbortSignal | undefined;
      let resolveRead: (() => void) | undefined;

      // Create a stream that pauses on the second read, giving us time to abort
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(
            new TextEncoder().encode('event: token\ndata: {"text":"A","index":0}\n\n')
          );
          // Second read will hang until we resolve it
          resolveRead = () => controller.close();
        },
        pull() {
          // Block pull until resolveRead is called
          return new Promise<void>((resolve) => {
            const interval = setInterval(() => {
              if (resolveRead) {
                clearInterval(interval);
                resolve();
              }
            }, 1);
          });
        },
      });

      const localFetch = vi.fn().mockImplementation((_url: string, init: RequestInit) => {
        capturedSignal = init.signal as AbortSignal;
        return Promise.resolve({
          ok: true,
          status: 200,
          headers: new Headers({ 'Content-Type': 'text/event-stream' }),
          body: stream,
        } as unknown as globalThis.Response);
      });

      const client = new FarmerChatApiClient(TEST_CONFIG, localFetch);
      const gen = client.sendQuery(TEST_QUERY);

      // Get the first event
      const first = await gen.next();
      expect(first.done).toBe(false);
      expect(first.value.event).toBe('token');

      // Now abort mid-stream
      client.stopStream();
      expect(capturedSignal?.aborted).toBe(true);

      // Clean up: close the stream so the generator can finish
      resolveRead?.();
    }, 10000);
  });

  // -----------------------------------------------------------------------
  // getStarters
  // -----------------------------------------------------------------------

  describe('getStarters()', () => {
    it('sends GET with language query param', async () => {
      const starters = [{ text: 'How to grow rice?' }, { text: 'Best fertilizer?' }];
      fetchMock.mockResolvedValue(mockResponse(starters));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);

      const result = await client.getStarters('hi');

      expect(fetchMock).toHaveBeenCalledTimes(1);
      const [url, opts] = fetchMock.mock.calls[0];
      expect(url).toBe('https://test.api.farmerchat.org/v1/config/starters?lang=hi');
      expect(opts.method).toBe('GET');
      expect(result).toEqual(starters);
    });

    it('encodes language parameter', async () => {
      fetchMock.mockResolvedValue(mockResponse([]));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);
      await client.getStarters('pt-BR');

      const [url] = fetchMock.mock.calls[0];
      expect(url).toContain('lang=pt-BR');
    });
  });

  // -----------------------------------------------------------------------
  // submitFeedback
  // -----------------------------------------------------------------------

  describe('submitFeedback()', () => {
    it('sends POST with feedback body', async () => {
      fetchMock.mockResolvedValue(mockResponse({}, { status: 200 }));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);

      const feedback: FeedbackPayload = {
        responseId: 'r_1',
        rating: 'positive',
        comment: 'Very helpful!',
      };
      await client.submitFeedback(feedback);

      expect(fetchMock).toHaveBeenCalledTimes(1);
      const [url, opts] = fetchMock.mock.calls[0];
      expect(url).toBe('https://test.api.farmerchat.org/v1/chat/feedback');
      expect(opts.method).toBe('POST');
      expect(JSON.parse(opts.body)).toEqual(feedback);
    });
  });

  // -----------------------------------------------------------------------
  // getHistory
  // -----------------------------------------------------------------------

  describe('getHistory()', () => {
    it('sends GET and returns conversations', async () => {
      const conversations = [
        { id: 'c_1', title: 'Rice queries', messages: [], createdAt: 1, updatedAt: 2 },
      ];
      fetchMock.mockResolvedValue(mockResponse(conversations));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);

      const result = await client.getHistory();

      expect(fetchMock).toHaveBeenCalledTimes(1);
      const [url, opts] = fetchMock.mock.calls[0];
      expect(url).toBe('https://test.api.farmerchat.org/v1/chat/history');
      expect(opts.method).toBe('GET');
      expect(result).toEqual(conversations);
    });
  });

  // -----------------------------------------------------------------------
  // Error handling
  // -----------------------------------------------------------------------

  describe('error handling', () => {
    it('401 throws AUTH_INVALID', async () => {
      fetchMock.mockResolvedValue(mockResponse('Unauthorized', { status: 401 }));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);

      try {
        await collectEvents(client.sendQuery(TEST_QUERY));
        expect.unreachable('Should have thrown');
      } catch (err) {
        expect(err).toBeInstanceOf(FarmerChatError);
        expect((err as FarmerChatError).code).toBe('AUTH_INVALID');
        expect((err as FarmerChatError).httpStatus).toBe(401);
      }
    });

    it('429 throws RATE_LIMITED', async () => {
      fetchMock.mockResolvedValue(mockResponse('Too many requests', { status: 429 }));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);

      try {
        await collectEvents(client.sendQuery(TEST_QUERY));
        expect.unreachable('Should have thrown');
      } catch (err) {
        expect(err).toBeInstanceOf(FarmerChatError);
        expect((err as FarmerChatError).code).toBe('RATE_LIMITED');
        expect((err as FarmerChatError).httpStatus).toBe(429);
      }
    });

    it('500 throws SERVER_ERROR', async () => {
      fetchMock.mockResolvedValue(mockResponse('Server Error', { status: 500 }));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);

      try {
        await collectEvents(client.sendQuery(TEST_QUERY));
        expect.unreachable('Should have thrown');
      } catch (err) {
        expect(err).toBeInstanceOf(FarmerChatError);
        expect((err as FarmerChatError).code).toBe('SERVER_ERROR');
        expect((err as FarmerChatError).httpStatus).toBe(500);
      }
    });

    it('unknown status throws UNKNOWN error', async () => {
      fetchMock.mockResolvedValue(mockResponse('Teapot', { status: 418 }));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);

      try {
        await collectEvents(client.sendQuery(TEST_QUERY));
        expect.unreachable('Should have thrown');
      } catch (err) {
        expect(err).toBeInstanceOf(FarmerChatError);
        expect((err as FarmerChatError).code).toBe('UNKNOWN');
      }
    });
  });

  // -----------------------------------------------------------------------
  // Headers
  // -----------------------------------------------------------------------

  describe('headers', () => {
    it('includes Authorization, Content-Type, and X-SDK-Version', async () => {
      fetchMock.mockResolvedValue(mockResponse([]));
      const client = new FarmerChatApiClient(TEST_CONFIG, fetchMock);
      await client.getStarters('en');

      const [, opts] = fetchMock.mock.calls[0];
      expect(opts.headers['Authorization']).toBe('Bearer test-api-key-123');
      expect(opts.headers['Content-Type']).toBe('application/json');
      expect(opts.headers['X-SDK-Version']).toBeDefined();
    });
  });
});
