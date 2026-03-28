/**
 * All SDK lifecycle event types.
 */
export type SDKEvent =
  | OnChatOpened
  | OnChatClosed
  | OnQuerySent
  | OnResponseReceived
  | OnError
  | OnStreamingStarted
  | OnStreamingToken
  | OnFeedbackSubmitted
  | OnLanguageChanged
  | OnOnboardingCompleted
  | OnConnectivityChanged;

/** Fired when the chat screen is opened */
export interface OnChatOpened {
  type: 'chat_opened';
  timestamp: number;
  sessionId: string;
}

/** Fired when the chat screen is closed */
export interface OnChatClosed {
  type: 'chat_closed';
  timestamp: number;
  sessionId: string;
  messageCount: number;
}

/** Fired when a user query is sent */
export interface OnQuerySent {
  type: 'query_sent';
  timestamp: number;
  sessionId: string;
  queryId: string;
  inputMethod: 'text' | 'voice' | 'image' | 'follow_up';
}

/** Fired when a complete response is received */
export interface OnResponseReceived {
  type: 'response_received';
  timestamp: number;
  sessionId: string;
  responseId: string;
  latencyMs: number;
}

/** Fired on any SDK error */
export interface OnError {
  type: 'error';
  timestamp: number;
  sessionId?: string;
  code: string;
  message: string;
  fatal: boolean;
}

/** Fired when the first SSE token arrives for a streaming response */
export interface OnStreamingStarted {
  type: 'streaming_started';
  timestamp: number;
  sessionId: string;
  queryId: string;
}

/** Fired on each individual SSE token during streaming */
export interface OnStreamingToken {
  type: 'streaming_token';
  timestamp: number;
  sessionId: string;
  /** The token text content */
  text: string;
  /** Zero-based index of this token in the stream */
  index: number;
}

/** Fired when the user submits feedback on a response */
export interface OnFeedbackSubmitted {
  type: 'feedback_submitted';
  timestamp: number;
  sessionId: string;
  responseId: string;
  rating: 'positive' | 'negative';
}

/** Fired when the user changes the active language */
export interface OnLanguageChanged {
  type: 'language_changed';
  timestamp: number;
  /** Previous language code */
  from: string;
  /** New language code */
  to: string;
}

/** Fired when the user completes the onboarding flow */
export interface OnOnboardingCompleted {
  type: 'onboarding_completed';
  timestamp: number;
  sessionId: string;
  /** Location selected during onboarding */
  location: { lat: number; lng: number };
  /** Language selected during onboarding */
  language: string;
}

/** Fired when network connectivity status changes */
export interface OnConnectivityChanged {
  type: 'connectivity_changed';
  timestamp: number;
  /** Whether the device currently has an active internet connection */
  isConnected: boolean;
}

/** Generic callback type for SDK events */
export type EventCallback<T extends SDKEvent = SDKEvent> = (event: T) => void;
