/**
 * A parsed Server-Sent Event.
 */
export interface SSEEvent {
  /** Event type: 'token', 'followup', 'done', 'error' */
  event: string;

  /** Parsed JSON data payload */
  data: unknown;
}

/**
 * Incremental SSE text stream parser.
 * Feed chunks of text and receive parsed events.
 *
 * Follows the W3C Server-Sent Events specification:
 * - Handles \r\n, \r, and \n line endings
 * - Defaults event type to "message" when no event: field is present
 * - Concatenates multiple data: lines with \n
 * - Ignores comment lines (starting with :)
 */
export class SSEParser {
  private buffer = '';

  /**
   * Feed a chunk of text from the stream.
   * Returns an array of complete SSE events parsed from the chunk.
   */
  feed(chunk: string): SSEEvent[] {
    this.buffer += chunk;
    const events: SSEEvent[] = [];

    // Normalize line endings: \r\n → \n, standalone \r → \n
    const normalized = this.buffer.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    const lines = normalized.split('\n');

    // Keep the last incomplete line in the buffer
    this.buffer = lines.pop() ?? '';

    let currentEvent = '';
    let currentData: string[] = [];

    for (const line of lines) {
      // Ignore comment lines (SSE spec: lines starting with ':')
      if (line.startsWith(':')) {
        continue;
      }

      if (line.startsWith('event:')) {
        const val = line.slice(6);
        currentEvent = val.startsWith(' ') ? val.slice(1) : val;
      } else if (line.startsWith('data:')) {
        // SSE spec: strip only the first space after the colon, concatenate with \n
        const val = line.slice(5);
        currentData.push(val.startsWith(' ') ? val.slice(1) : val);
      } else if (line === '') {
        // Empty line = end of event
        if (currentData.length > 0) {
          // Default to "message" when no event: field (SSE spec)
          const eventType = currentEvent || 'message';
          const joined = currentData.join('\n');
          try {
            events.push({
              event: eventType,
              data: JSON.parse(joined),
            });
          } catch {
            events.push({
              event: eventType,
              data: joined,
            });
          }
        }
        currentEvent = '';
        currentData = [];
      }
    }

    return events;
  }

  /** Reset the parser state */
  reset(): void {
    this.buffer = '';
  }
}
