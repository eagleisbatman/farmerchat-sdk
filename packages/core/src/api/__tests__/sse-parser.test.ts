import { describe, it, expect } from 'vitest';
import { SSEParser } from '../sse-parser';

describe('SSEParser', () => {
  it('parses a complete SSE event', () => {
    const parser = new SSEParser();
    const events = parser.feed('event: token\ndata: {"text":"Hello","index":0}\n\n');
    expect(events).toHaveLength(1);
    expect(events[0]).toEqual({
      event: 'token',
      data: { text: 'Hello', index: 0 },
    });
  });

  it('handles chunked input across multiple feeds', () => {
    const parser = new SSEParser();
    // First chunk: partial event line — no newline yet, stays in buffer
    expect(parser.feed('event: tok')).toHaveLength(0);
    // Second chunk: completes event line AND provides data line AND terminator
    // The parser only correlates event/data within the same feed's line processing,
    // but the buffer accumulates across feeds. So once all lines + blank line are
    // in the buffer and then split, they're processed together.
    const events = parser.feed('en\ndata: {"text":"Hi","index":0}\n\n');
    expect(events).toHaveLength(1);
    expect(events[0].data).toEqual({ text: 'Hi', index: 0 });
  });

  it('parses multiple events in one chunk', () => {
    const parser = new SSEParser();
    const chunk =
      'event: token\ndata: {"text":"A","index":0}\n\n' +
      'event: token\ndata: {"text":"B","index":1}\n\n';
    const events = parser.feed(chunk);
    expect(events).toHaveLength(2);
    expect((events[0].data as { text: string }).text).toBe('A');
    expect((events[1].data as { text: string }).text).toBe('B');
  });

  it('parses done event', () => {
    const parser = new SSEParser();
    const events = parser.feed(
      'event: done\ndata: {"response_id":"resp_123","latency_ms":2340}\n\n'
    );
    expect(events).toHaveLength(1);
    expect(events[0].event).toBe('done');
  });

  it('handles non-JSON data gracefully', () => {
    const parser = new SSEParser();
    const events = parser.feed('event: error\ndata: plain text error\n\n');
    expect(events).toHaveLength(1);
    expect(events[0].data).toBe('plain text error');
  });

  it('resets parser state', () => {
    const parser = new SSEParser();
    parser.feed('event: tok');
    parser.reset();
    const events = parser.feed('event: token\ndata: {"text":"X","index":0}\n\n');
    expect(events).toHaveLength(1);
  });

  it('skips events with no data field', () => {
    const parser = new SSEParser();
    // An event line followed by an empty line but no data
    const events = parser.feed('event: token\n\n');
    expect(events).toHaveLength(0);
  });

  it('defaults to "message" event when event field is empty (SSE spec)', () => {
    const parser = new SSEParser();
    // Per SSE spec, empty event: field defaults to "message"
    const events = parser.feed('event: \ndata: {"text":"X"}\n\n');
    expect(events).toHaveLength(1);
    expect(events[0].event).toBe('message');
    expect(events[0].data).toEqual({ text: 'X' });
  });

  it('defaults to "message" event when no event field is present (SSE spec)', () => {
    const parser = new SSEParser();
    // Per SSE spec, missing event: field defaults to "message"
    const events = parser.feed('data: {"text":"Y"}\n\n');
    expect(events).toHaveLength(1);
    expect(events[0].event).toBe('message');
    expect(events[0].data).toEqual({ text: 'Y' });
  });

  it('ignores SSE comment lines (starting with colon)', () => {
    const parser = new SSEParser();
    const events = parser.feed(
      ': this is a comment\nevent: token\ndata: {"text":"A","index":0}\n\n'
    );
    expect(events).toHaveLength(1);
    expect(events[0].event).toBe('token');
  });

  it('handles multiple comment lines interspersed with events', () => {
    const parser = new SSEParser();
    const events = parser.feed(
      ': keep-alive\n' +
        'event: token\n' +
        'data: {"text":"B","index":0}\n' +
        '\n' +
        ': another comment\n' +
        'event: done\n' +
        'data: {}\n' +
        '\n'
    );
    expect(events).toHaveLength(2);
    expect(events[0].event).toBe('token');
    expect(events[1].event).toBe('done');
  });

  it('concatenates multiple data: lines with newline (SSE spec)', () => {
    const parser = new SSEParser();
    // Per SSE spec, multiple data: lines are concatenated with \n
    const events = parser.feed(
      'event: token\ndata: {"text":"first"}\ndata: {"text":"second","index":1}\n\n'
    );
    expect(events).toHaveLength(1);
    // Concatenated data is not valid JSON, so it's returned as string
    expect(events[0].data).toBe('{"text":"first"}\n{"text":"second","index":1}');
  });

  it('handles \\r\\n line endings (SSE spec)', () => {
    const parser = new SSEParser();
    const events = parser.feed('event: token\r\ndata: {"text":"Hi"}\r\n\r\n');
    expect(events).toHaveLength(1);
    expect(events[0].event).toBe('token');
    expect(events[0].data).toEqual({ text: 'Hi' });
  });
});
