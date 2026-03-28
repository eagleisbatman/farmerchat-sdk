/**
 * A user query sent to the FarmerChat API.
 */
export interface Query {
  /** Unique query identifier */
  id: string;

  /** Text content of the query */
  text: string;

  /** Input method used (follow_up when user taps a suggested follow-up chip) */
  inputMethod: 'text' | 'voice' | 'image' | 'follow_up';

  /** Base64 image data if input includes a photo */
  imageData?: string;

  /** User's location (latitude, longitude) */
  location?: { lat: number; lng: number };

  /** Language code for the query */
  language: string;

  /** Timestamp of the query */
  timestamp: number;
}

/**
 * A complete AI response from the server.
 */
export interface Response {
  /** Unique response identifier */
  id: string;

  /** Full response text (accumulated from stream tokens) */
  text: string;

  /** Language code the response was delivered in (e.g., 'hi', 'en') */
  language: string;

  /** Optional image URL included by the server (e.g., pest identification photo) */
  imageUrl?: string;

  /** Follow-up question suggestions */
  followUps: FollowUpQuestion[];

  /** Citation sources referenced in the response */
  sources?: ResponseSource[];

  /** Server-side latency in milliseconds */
  latencyMs: number;

  /** Timestamp of the response */
  timestamp: number;
}

/**
 * A single token in the SSE stream.
 */
export interface StreamToken {
  /** Token text content */
  text: string;

  /** Token index in the stream */
  index: number;
}

/**
 * A citation source referenced in a response.
 */
export interface ResponseSource {
  /** Display title of the source */
  title: string;

  /** Optional URL linking to the source material */
  url?: string;
}

/**
 * A follow-up question suggestion.
 */
export interface FollowUpQuestion {
  /** Display text for the follow-up */
  text: string;
}

/**
 * A starter question shown in the empty chat state to guide new users.
 */
export interface StarterQuestion {
  /** Display text for the starter question */
  text: string;

  /** Optional category grouping (e.g., 'crop_health', 'weather', 'market') */
  category?: string;
}

/**
 * User feedback on a response (thumbs up/down).
 */
export interface FeedbackPayload {
  /** Response ID being rated */
  responseId: string;

  /** Rating: positive or negative */
  rating: 'positive' | 'negative';

  /** Optional free-text comment */
  comment?: string;
}

/**
 * A chat message (either user query or AI response).
 */
export interface Message {
  /** Unique message ID */
  id: string;

  /** Message role */
  role: 'user' | 'assistant';

  /** Message text content */
  text: string;

  /** Timestamp */
  timestamp: number;

  /** Follow-up suggestions (assistant messages only) */
  followUps?: FollowUpQuestion[];

  /** User feedback (assistant messages only) */
  feedback?: FeedbackPayload;

  /** Image data (user messages only) */
  imageData?: string;
}

/**
 * A supported language returned by the server.
 */
export interface Language {
  /** ISO language code (e.g., 'en', 'hi', 'te') */
  code: string;

  /** English name of the language */
  name: string;

  /** Native script name of the language */
  nativeName: string;
}

/**
 * Onboarding payload submitted after initial setup.
 */
export interface OnboardingPayload {
  /** User's location */
  location: { lat: number; lng: number };

  /** Selected language code */
  language: string;
}

/**
 * A conversation (list of messages with metadata).
 */
export interface Conversation {
  /** Conversation/session ID */
  id: string;

  /** Conversation title (auto-generated from first query) */
  title: string;

  /** Messages in the conversation */
  messages: Message[];

  /** When the conversation was started */
  createdAt: number;

  /** When the conversation was last active */
  updatedAt: number;
}
