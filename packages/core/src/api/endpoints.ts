/**
 * FarmerChat API endpoint paths.
 */
export const Endpoints = {
  /** Send a chat query (POST, returns SSE stream) */
  CHAT_SEND: '/v1/chat/send',

  /** Submit feedback on a response (POST) */
  FEEDBACK: '/v1/chat/feedback',

  /** Get conversation history (GET) */
  HISTORY: '/v1/chat/history',

  /** Get available languages (GET) */
  LANGUAGES: '/v1/config/languages',

  /** Get starter questions (GET) */
  STARTERS: '/v1/config/starters',

  /** Text-to-speech (POST) */
  TTS: '/v1/chat/tts',

  /** Submit onboarding data — location + language (POST) */
  ONBOARDING: '/v1/user/onboarding',
} as const;
