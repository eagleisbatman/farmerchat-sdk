import type { EventCallback } from './events';

/**
 * Primary configuration for the FarmerChat SDK.
 * Passed to `FarmerChat.initialize()`.
 */
export interface FarmerChatConfig {
  /** Partner API key issued by Digital Green */
  apiKey: string;

  /** Base URL for the FarmerChat API. Defaults to production. */
  baseUrl?: string;

  /** Partner identifier used for analytics segmentation and content injection */
  partnerId?: string;

  /**
   * External session ID. If omitted, the SDK generates one internally.
   * Use this to correlate FarmerChat sessions with your own analytics.
   */
  sessionId?: string;

  /** User's location for geo-contextualized agricultural advice */
  location?: { lat: number; lng: number };

  /** UI theme customization */
  theme?: ThemeConfig;

  /** Crash reporting configuration */
  crash?: CrashConfig;

  /**
   * Global event callback. Invoked for every SDK lifecycle event
   * (chat opened/closed, queries, responses, errors, etc.).
   */
  onEvent?: EventCallback;

  /** Header title displayed in the chat screen */
  headerTitle?: string;

  /** Default language code (e.g., 'hi', 'en', 'sw'). Loaded from server if not set. */
  defaultLanguage?: string;

  /** Enable voice input. Defaults to true. */
  voiceInputEnabled?: boolean;

  /** Enable image input (camera/gallery). Defaults to true. */
  imageInputEnabled?: boolean;

  /** Enable chat history screen. Defaults to true. */
  historyEnabled?: boolean;

  /** Enable profile/settings screen. Defaults to true. */
  profileEnabled?: boolean;

  /** Show "Powered by FarmerChat" branding. Defaults to true. */
  showPoweredBy?: boolean;

  /** Maximum number of messages to keep in memory. Defaults to 50. */
  maxMessagesInMemory?: number;

  /** Request timeout in milliseconds. Defaults to 15000. */
  requestTimeoutMs?: number;

  /**
   * Number of SSE reconnect attempts before showing a connection error.
   * Defaults to 1.
   */
  sseReconnectAttempts?: number;

  /**
   * Maximum thumbnail dimension in dp/pt for image previews.
   * Images larger than this are down-scaled before display. Defaults to 300.
   */
  maxImageDimension?: number;

  /**
   * Image compression quality (0-100) applied before uploading.
   * Higher values produce better quality at the cost of larger payloads. Defaults to 80.
   */
  imageCompressionQuality?: number;
}

/**
 * Theme customization for the SDK UI.
 */
export interface ThemeConfig {
  /** Primary brand color as hex string (e.g., '#1B6B3A') */
  primaryColor?: string;

  /** Secondary/accent color as hex string */
  secondaryColor?: string;

  /** Font family name (must be available on the platform) */
  fontFamily?: string;

  /** Corner radius for cards and buttons in dp/pt */
  cornerRadius?: number;
}

/**
 * Configuration for crash reporting integration.
 */
export interface CrashConfig {
  /** Enable crash reporting. Defaults to true (uses built-in reporter). */
  enabled?: boolean;

  /** Custom crash reporter adapter (Firebase, Sentry, Bugsnag, or custom) */
  reporter?: CrashReporter;
}

/**
 * Interface for pluggable crash reporter adapters.
 * Partners implement this to forward SDK crashes to their crash tool.
 */
export interface CrashReporter {
  /** Report a crash with error details and SDK breadcrumbs */
  reportCrash(error: Error, breadcrumbs: string[]): void;

  /** Add a breadcrumb for crash context */
  addBreadcrumb(message: string): void;

  /** Set a custom key-value pair on crash reports */
  setCustomKey(key: string, value: string): void;
}
