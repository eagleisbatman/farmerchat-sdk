import Foundation

/// Line-by-line parser for Server-Sent Events.
///
/// Feed one line at a time via `feed(line:)`. When a complete event is ready
/// (blank line encountered after `event:` + `data:`), the method returns an `SseEvent`.
/// Otherwise it returns `nil` while accumulating state.
///
/// Usage:
/// ```swift
/// let parser = SSEParser()
/// for line in lines {
///     if let event = parser.feed(line: line) {
///         // handle event
///     }
/// }
/// ```
internal final class SSEParser {

    /// Accumulated event type from the most recent `event:` line.
    private var currentEvent: String = ""

    /// Accumulated data lines (SSE spec: multiple data: lines concatenated with \n).
    private var currentDataLines: [String] = []

    /// Process a single line from the SSE stream.
    ///
    /// - Parameter line: One line of text (without the trailing newline).
    /// - Returns: A complete `SseEvent` if a blank line terminates a fully populated event,
    ///   or `nil` if the parser is still accumulating.
    func feed(line: String) -> SseEvent? {
        if line.hasPrefix("event:") {
            let val = String(line.dropFirst(6))
            currentEvent = val.hasPrefix(" ") ? String(val.dropFirst()) : val
            return nil
        }

        if line.hasPrefix("data:") {
            // SSE spec: strip only the first space after the colon, accumulate with \n
            let val = String(line.dropFirst(5))
            currentDataLines.append(val.hasPrefix(" ") ? String(val.dropFirst()) : val)
            return nil
        }

        // SSE spec: a blank line signals the end of an event block.
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard !currentEvent.isEmpty, !currentDataLines.isEmpty else {
                // Incomplete event — reset and skip.
                reset()
                return nil
            }

            let data = currentDataLines.joined(separator: "\n")
            let event = SseEvent(event: currentEvent, data: data)
            reset()
            return event
        }

        // Ignore comment lines (starting with ':') and unknown prefixes.
        return nil
    }

    /// Clear all accumulated parser state.
    func reset() {
        currentEvent = ""
        currentDataLines = []
    }

    /// Flush any trailing event that was not terminated by a blank line.
    ///
    /// Call this after the stream ends to emit the last event if the server
    /// closed the connection without sending a trailing blank line.
    ///
    /// - Returns: An `SseEvent` if there is a pending complete event, or `nil`.
    func flush() -> SseEvent? {
        guard !currentEvent.isEmpty, !currentDataLines.isEmpty else {
            reset()
            return nil
        }
        let data = currentDataLines.joined(separator: "\n")
        let event = SseEvent(event: currentEvent, data: data)
        reset()
        return event
    }
}
