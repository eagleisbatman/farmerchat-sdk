/**
 * Default values for all SDK configuration options.
 */
export const DEFAULTS = {
  /** Production API base URL */
  baseUrl: 'https://api.farmerchat.digitalgreen.org',

  /** SDK version string */
  sdkVersion: '0.0.0',

  /** Default header title */
  headerTitle: 'FarmerChat',

  /** Default primary brand color */
  primaryColor: '#1B6B3A',

  /** Default secondary color */
  secondaryColor: '#F0F7F2',

  /** Default corner radius (dp/pt) */
  cornerRadius: 12,

  /** Request timeout in milliseconds */
  requestTimeoutMs: 15_000,

  /** Maximum messages kept in memory */
  maxMessagesInMemory: 50,

  /** Voice input enabled by default */
  voiceInputEnabled: true,

  /** Image input enabled by default */
  imageInputEnabled: true,

  /** History screen enabled by default */
  historyEnabled: true,

  /** Profile screen enabled by default */
  profileEnabled: true,

  /** Show powered-by branding by default */
  showPoweredBy: true,

  /** SSE reconnect attempts */
  sseReconnectAttempts: 1,

  /** Max image dimension for thumbnail (dp/pt) */
  maxImageDimension: 300,

  /** Image compression quality (0-100) */
  imageCompressionQuality: 80,

  /** Max retry attempts for non-SSE requests */
  retryMaxAttempts: 3,

  /** Base delay for exponential backoff (ms) */
  retryBaseDelayMs: 1_000,

  /** Max delay cap for exponential backoff (ms) */
  retryMaxDelayMs: 8_000,

  /** SSE stream timeout (ms) — longer than regular requestTimeoutMs */
  sseTimeoutMs: 30_000,

  /** Max image upload size in bytes (5 MB) */
  imageSizeLimitBytes: 5_242_880,

  /** Default font family (platform-native) */
  fontFamily: 'System',
} as const;
