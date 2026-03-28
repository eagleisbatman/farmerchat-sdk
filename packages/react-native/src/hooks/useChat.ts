import { useState, useRef, useCallback, useEffect } from 'react';
import { FarmerChatApiClient } from '@digitalgreenorg/farmerchat-core';
import type {
  Message,
  Query,
  FeedbackPayload,
  FollowUpQuestion,
  StarterQuestion,
  Conversation,
} from '@digitalgreenorg/farmerchat-core';
import {
  DEFAULTS,
  ErrorCodes,
  FarmerChatError,
  StreamingMarkdownParser,
  type MarkdownDocument,
} from '@digitalgreenorg/farmerchat-core';
import type { SDKEvent } from '@digitalgreenorg/farmerchat-core';
import { useFarmerChatConfig } from '../FarmerChat';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type ChatState = 'idle' | 'sending' | 'streaming' | 'error';
type Screen = 'onboarding' | 'chat' | 'history' | 'profile';

export interface UseChatReturn {
  // State
  chatState: ChatState;
  messages: Message[];
  starterQuestions: StarterQuestion[];
  currentScreen: Screen;
  isConnected: boolean;
  selectedLanguage: string;
  availableLanguages: Array<{ code: string; name: string; nativeName: string }>;
  errorMessage: string | null;
  streamingMarkdown: MarkdownDocument | null;

  // Actions
  sendQuery: (text: string, imageData?: string) => Promise<void>;
  sendFollowUp: (text: string) => Promise<void>;
  stopStream: () => void;
  retryLastQuery: () => Promise<void>;
  submitFeedback: (responseId: string, rating: 'positive' | 'negative') => Promise<void>;
  loadHistory: () => Promise<Conversation[]>;
  loadLanguages: () => Promise<void>;
  setLanguage: (code: string) => void;
  loadStarters: () => Promise<void>;
  completeOnboarding: (location: { lat: number; lng: number }, language: string) => Promise<void>;
  navigateTo: (screen: Screen) => void;
  setIsConnected: (connected: boolean) => void;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function generateId(): string {
  // Use globalThis.crypto when available (modern Hermes), otherwise fallback
  const g = globalThis as { crypto?: { randomUUID?: () => string } };
  if (g.crypto?.randomUUID) {
    return g.crypto.randomUUID();
  }
  return (
    Math.random().toString(36).slice(2) +
    Date.now().toString(36) +
    Math.random().toString(36).slice(2)
  );
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

/**
 * Full chat state machine hook.
 *
 * State flow: Idle -> Sending -> Streaming -> Idle | Error
 *
 * All networking uses the core FarmerChatApiClient (fetch-based).
 * All state is held in React hooks — no local persistence.
 */
export function useChat(): UseChatReturn {
  const config = useFarmerChatConfig();

  // --- Refs (stable across renders, no re-render on mutation) ---
  const apiClientRef = useRef<FarmerChatApiClient | null>(null);
  const sessionIdRef = useRef<string>(config.sessionId ?? generateId());
  const streamingParserRef = useRef<StreamingMarkdownParser | null>(null);
  const isMountedRef = useRef(true);
  const lastQueryRef = useRef<{ text: string; imageData?: string } | null>(null);

  // --- State ---
  const [chatState, setChatState] = useState<ChatState>('idle');
  const [messages, setMessages] = useState<Message[]>([]);
  const [starterQuestions, setStarterQuestions] = useState<StarterQuestion[]>([]);
  const [currentScreen, setCurrentScreen] = useState<Screen>('onboarding');
  const [isConnected, setIsConnected] = useState(true);
  const [selectedLanguage, setSelectedLanguage] = useState(config.defaultLanguage ?? 'en');
  const [availableLanguages, setAvailableLanguages] = useState<
    Array<{ code: string; name: string; nativeName: string }>
  >([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [streamingMarkdown, setStreamingMarkdown] = useState<MarkdownDocument | null>(null);

  // Max messages to keep in memory
  const maxMessages = config.maxMessagesInMemory ?? DEFAULTS.maxMessagesInMemory;

  // --- Initialize API client ---
  useEffect(() => {
    apiClientRef.current = new FarmerChatApiClient(config);
  }, [config]);

  // --- Cleanup on unmount ---
  useEffect(() => {
    return () => {
      isMountedRef.current = false;
      apiClientRef.current?.stopStream();
    };
  }, []);

  // --- Event emission helper ---
  const emitEvent = useCallback(
    (event: SDKEvent) => {
      try {
        config.onEvent?.(event);
      } catch {
        // SDK events must never crash the host app
      }
    },
    [config]
  );

  // --- Safe state setters (guard against updates after unmount) ---
  // NoInfer forces T to be inferred from the setter, not the value literal.
  const safeSetState = useCallback(
    <T,>(setter: React.Dispatch<React.SetStateAction<T>>, value: NoInfer<React.SetStateAction<T>>) => {
      if (isMountedRef.current) {
        setter(value);
      }
    },
    []
  );

  // --- Append message with cap ---
  const appendMessage = useCallback(
    (msg: Message) => {
      safeSetState(setMessages, (prev) => {
        const next = [...prev, msg];
        // Trim from the front to stay within the memory cap
        if (next.length > maxMessages) {
          return next.slice(next.length - maxMessages);
        }
        return next;
      });
    },
    [maxMessages, safeSetState]
  );

  // --- Upsert assistant message (update in place if id exists, else append) ---
  const upsertAssistantMessage = useCallback(
    (msg: Message) => {
      safeSetState(setMessages, (prev) => {
        const idx = prev.findIndex((m) => m.id === msg.id);
        if (idx !== -1) {
          const next = [...prev];
          next[idx] = msg;
          return next;
        }
        const next = [...prev, msg];
        if (next.length > maxMessages) {
          return next.slice(next.length - maxMessages);
        }
        return next;
      });
    },
    [maxMessages, safeSetState]
  );

  // ---------------------------------------------------------------------------
  // sendQuery
  // ---------------------------------------------------------------------------
  const sendQuery = useCallback(
    async (text: string, imageData?: string) => {
      const client = apiClientRef.current;
      if (!client) return;

      // Track for retry
      lastQueryRef.current = { text, imageData };

      // Clear previous error
      safeSetState(setErrorMessage, null);
      safeSetState(setChatState, 'sending');
      safeSetState(setStreamingMarkdown, null);

      // Build query
      const queryId = generateId();
      const inputMethod = imageData ? 'image' : 'text';
      const query: Query = {
        id: queryId,
        text,
        inputMethod,
        imageData,
        location: config.location,
        language: selectedLanguage,
        timestamp: Date.now(),
      };

      // Add user message
      const userMessage: Message = {
        id: queryId,
        role: 'user',
        text,
        timestamp: query.timestamp,
        imageData,
      };
      appendMessage(userMessage);

      // Emit query_sent event
      emitEvent({
        type: 'query_sent',
        timestamp: Date.now(),
        sessionId: sessionIdRef.current,
        queryId,
        inputMethod,
      });

      // Prepare streaming state
      const responseId = generateId();
      let accumulatedText = '';
      let followUps: FollowUpQuestion[] = [];
      let tokenIndex = 0;
      let firstTokenReceived = false;
      const streamParser = new StreamingMarkdownParser();
      streamingParserRef.current = streamParser;
      const streamStartTime = Date.now();

      try {
        const stream = client.sendQuery(query);

        for await (const event of stream) {
          if (!isMountedRef.current) break;

          switch (event.event) {
            case 'token': {
              const tokenData = event.data as { text?: string; index?: number };
              const tokenText = tokenData.text ?? '';

              if (!firstTokenReceived) {
                firstTokenReceived = true;
                safeSetState(setChatState, 'streaming');
                emitEvent({
                  type: 'streaming_started',
                  timestamp: Date.now(),
                  sessionId: sessionIdRef.current,
                  queryId,
                });
              }

              accumulatedText += tokenText;

              // Parse markdown incrementally
              const doc = streamParser.append(tokenText);
              safeSetState(setStreamingMarkdown, doc);

              // Upsert the in-progress assistant message
              upsertAssistantMessage({
                id: responseId,
                role: 'assistant',
                text: accumulatedText,
                timestamp: Date.now(),
                followUps: [],
              });

              // Emit streaming_token event
              emitEvent({
                type: 'streaming_token',
                timestamp: Date.now(),
                sessionId: sessionIdRef.current,
                text: tokenText,
                index: tokenData.index ?? tokenIndex,
              });

              tokenIndex++;
              break;
            }

            case 'followup': {
              const followUpData = event.data as
                | FollowUpQuestion[]
                | { questions?: FollowUpQuestion[] };
              if (Array.isArray(followUpData)) {
                followUps = followUpData;
              } else if (Array.isArray(followUpData.questions)) {
                followUps = followUpData.questions;
              }
              break;
            }

            case 'message': {
              // Non-streaming fallback (canned answer / JSON response)
              const msgData = event.data as {
                text?: string;
                followUps?: FollowUpQuestion[];
                follow_ups?: FollowUpQuestion[];
              };
              accumulatedText = msgData.text ?? '';
              followUps = msgData.followUps ?? msgData.follow_ups ?? [];

              // Parse the full text at once
              const fullDoc = streamParser.append(accumulatedText);
              safeSetState(setStreamingMarkdown, fullDoc);

              upsertAssistantMessage({
                id: responseId,
                role: 'assistant',
                text: accumulatedText,
                timestamp: Date.now(),
                followUps,
              });
              break;
            }

            case 'error': {
              const errData = event.data as { message?: string; code?: string };
              const errMsg = errData.message ?? 'An error occurred';
              safeSetState(setChatState, 'error');
              safeSetState(setErrorMessage, errMsg);
              emitEvent({
                type: 'error',
                timestamp: Date.now(),
                sessionId: sessionIdRef.current,
                code: errData.code ?? ErrorCodes.UNKNOWN,
                message: errMsg,
                fatal: false,
              });
              break;
            }

            case 'done': {
              // Finalize the assistant message
              upsertAssistantMessage({
                id: responseId,
                role: 'assistant',
                text: accumulatedText,
                timestamp: Date.now(),
                followUps,
              });

              safeSetState(setChatState, 'idle');
              safeSetState(setStreamingMarkdown, null);
              streamingParserRef.current = null;

              emitEvent({
                type: 'response_received',
                timestamp: Date.now(),
                sessionId: sessionIdRef.current,
                responseId,
                latencyMs: Date.now() - streamStartTime,
              });
              break;
            }

            default:
              // Unknown event types are silently ignored
              break;
          }
        }
      } catch (error: unknown) {
        if (!isMountedRef.current) return;

        const message =
          error instanceof FarmerChatError
            ? error.message
            : error instanceof Error
              ? error.message
              : 'An unexpected error occurred';

        const code =
          error instanceof FarmerChatError ? error.code : ErrorCodes.UNKNOWN;

        safeSetState(setChatState, 'error');
        safeSetState(setErrorMessage, message);
        safeSetState(setStreamingMarkdown, null);
        streamingParserRef.current = null;

        emitEvent({
          type: 'error',
          timestamp: Date.now(),
          sessionId: sessionIdRef.current,
          code,
          message,
          fatal: error instanceof FarmerChatError ? error.fatal : false,
        });
      }
    },
    [
      config.location,
      selectedLanguage,
      appendMessage,
      upsertAssistantMessage,
      emitEvent,
      safeSetState,
    ]
  );

  // ---------------------------------------------------------------------------
  // sendFollowUp
  // ---------------------------------------------------------------------------
  const sendFollowUp = useCallback(
    async (text: string) => {
      const client = apiClientRef.current;
      if (!client) return;

      // Follow-up uses the same flow as sendQuery but with inputMethod 'follow_up'
      lastQueryRef.current = { text };

      safeSetState(setErrorMessage, null);
      safeSetState(setChatState, 'sending');
      safeSetState(setStreamingMarkdown, null);

      const queryId = generateId();
      const query: Query = {
        id: queryId,
        text,
        inputMethod: 'follow_up',
        location: config.location,
        language: selectedLanguage,
        timestamp: Date.now(),
      };

      const userMessage: Message = {
        id: queryId,
        role: 'user',
        text,
        timestamp: query.timestamp,
      };
      appendMessage(userMessage);

      emitEvent({
        type: 'query_sent',
        timestamp: Date.now(),
        sessionId: sessionIdRef.current,
        queryId,
        inputMethod: 'follow_up',
      });

      const responseId = generateId();
      let accumulatedText = '';
      let followUps: FollowUpQuestion[] = [];
      let tokenIndex = 0;
      let firstTokenReceived = false;
      const streamParser = new StreamingMarkdownParser();
      streamingParserRef.current = streamParser;
      const streamStartTime = Date.now();

      try {
        const stream = client.sendQuery(query);

        for await (const event of stream) {
          if (!isMountedRef.current) break;

          switch (event.event) {
            case 'token': {
              const tokenData = event.data as { text?: string; index?: number };
              const tokenText = tokenData.text ?? '';

              if (!firstTokenReceived) {
                firstTokenReceived = true;
                safeSetState(setChatState, 'streaming');
                emitEvent({
                  type: 'streaming_started',
                  timestamp: Date.now(),
                  sessionId: sessionIdRef.current,
                  queryId,
                });
              }

              accumulatedText += tokenText;
              const doc = streamParser.append(tokenText);
              safeSetState(setStreamingMarkdown, doc);

              upsertAssistantMessage({
                id: responseId,
                role: 'assistant',
                text: accumulatedText,
                timestamp: Date.now(),
                followUps: [],
              });

              emitEvent({
                type: 'streaming_token',
                timestamp: Date.now(),
                sessionId: sessionIdRef.current,
                text: tokenText,
                index: tokenData.index ?? tokenIndex,
              });

              tokenIndex++;
              break;
            }

            case 'followup': {
              const followUpData = event.data as
                | FollowUpQuestion[]
                | { questions?: FollowUpQuestion[] };
              if (Array.isArray(followUpData)) {
                followUps = followUpData;
              } else if (Array.isArray(followUpData.questions)) {
                followUps = followUpData.questions;
              }
              break;
            }

            case 'message': {
              const msgData = event.data as {
                text?: string;
                followUps?: FollowUpQuestion[];
                follow_ups?: FollowUpQuestion[];
              };
              accumulatedText = msgData.text ?? '';
              followUps = msgData.followUps ?? msgData.follow_ups ?? [];

              const fullDoc = streamParser.append(accumulatedText);
              safeSetState(setStreamingMarkdown, fullDoc);

              upsertAssistantMessage({
                id: responseId,
                role: 'assistant',
                text: accumulatedText,
                timestamp: Date.now(),
                followUps,
              });
              break;
            }

            case 'error': {
              const errData = event.data as { message?: string; code?: string };
              const errMsg = errData.message ?? 'An error occurred';
              safeSetState(setChatState, 'error');
              safeSetState(setErrorMessage, errMsg);
              emitEvent({
                type: 'error',
                timestamp: Date.now(),
                sessionId: sessionIdRef.current,
                code: errData.code ?? ErrorCodes.UNKNOWN,
                message: errMsg,
                fatal: false,
              });
              break;
            }

            case 'done': {
              upsertAssistantMessage({
                id: responseId,
                role: 'assistant',
                text: accumulatedText,
                timestamp: Date.now(),
                followUps,
              });

              safeSetState(setChatState, 'idle');
              safeSetState(setStreamingMarkdown, null);
              streamingParserRef.current = null;

              emitEvent({
                type: 'response_received',
                timestamp: Date.now(),
                sessionId: sessionIdRef.current,
                responseId,
                latencyMs: Date.now() - streamStartTime,
              });
              break;
            }

            default:
              break;
          }
        }
      } catch (error: unknown) {
        if (!isMountedRef.current) return;

        const message =
          error instanceof FarmerChatError
            ? error.message
            : error instanceof Error
              ? error.message
              : 'An unexpected error occurred';

        const code =
          error instanceof FarmerChatError ? error.code : ErrorCodes.UNKNOWN;

        safeSetState(setChatState, 'error');
        safeSetState(setErrorMessage, message);
        safeSetState(setStreamingMarkdown, null);
        streamingParserRef.current = null;

        emitEvent({
          type: 'error',
          timestamp: Date.now(),
          sessionId: sessionIdRef.current,
          code,
          message,
          fatal: error instanceof FarmerChatError ? error.fatal : false,
        });
      }
    },
    [
      config.location,
      selectedLanguage,
      appendMessage,
      upsertAssistantMessage,
      emitEvent,
      safeSetState,
    ]
  );

  // ---------------------------------------------------------------------------
  // stopStream
  // ---------------------------------------------------------------------------
  const stopStream = useCallback(() => {
    try {
      apiClientRef.current?.stopStream();
      safeSetState(setChatState, 'idle');
      safeSetState(setStreamingMarkdown, null);
      streamingParserRef.current = null;
    } catch {
      // Never crash the host app
    }
  }, [safeSetState]);

  // ---------------------------------------------------------------------------
  // retryLastQuery
  // ---------------------------------------------------------------------------
  const retryLastQuery = useCallback(async () => {
    const lastQuery = lastQueryRef.current;
    if (!lastQuery) return;
    await sendQuery(lastQuery.text, lastQuery.imageData);
  }, [sendQuery]);

  // ---------------------------------------------------------------------------
  // submitFeedback
  // ---------------------------------------------------------------------------
  const submitFeedback = useCallback(
    async (responseId: string, rating: 'positive' | 'negative') => {
      const client = apiClientRef.current;
      if (!client) return;

      const feedback: FeedbackPayload = { responseId, rating };

      try {
        await client.submitFeedback(feedback);

        // Update the message's feedback field in state
        safeSetState(setMessages, (prev) =>
          prev.map((msg) =>
            msg.id === responseId ? { ...msg, feedback } : msg
          )
        );

        emitEvent({
          type: 'feedback_submitted',
          timestamp: Date.now(),
          sessionId: sessionIdRef.current,
          responseId,
          rating,
        });
      } catch (error: unknown) {
        const message =
          error instanceof Error ? error.message : 'Failed to submit feedback';

        emitEvent({
          type: 'error',
          timestamp: Date.now(),
          sessionId: sessionIdRef.current,
          code: ErrorCodes.UNKNOWN,
          message,
          fatal: false,
        });
      }
    },
    [emitEvent, safeSetState]
  );

  // ---------------------------------------------------------------------------
  // loadHistory
  // ---------------------------------------------------------------------------
  const loadHistory = useCallback(async (): Promise<Conversation[]> => {
    const client = apiClientRef.current;
    if (!client) return [];

    try {
      return await client.getHistory();
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : 'Failed to load history';

      emitEvent({
        type: 'error',
        timestamp: Date.now(),
        sessionId: sessionIdRef.current,
        code: ErrorCodes.HISTORY_LOAD_FAILED,
        message,
        fatal: false,
      });
      return [];
    }
  }, [emitEvent]);

  // ---------------------------------------------------------------------------
  // loadLanguages
  // ---------------------------------------------------------------------------
  const loadLanguages = useCallback(async () => {
    const client = apiClientRef.current;
    if (!client) return;

    try {
      const languages = await client.getLanguages();
      safeSetState(setAvailableLanguages, languages);
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : 'Failed to load languages';

      emitEvent({
        type: 'error',
        timestamp: Date.now(),
        sessionId: sessionIdRef.current,
        code: ErrorCodes.LANGUAGES_LOAD_FAILED,
        message,
        fatal: false,
      });
    }
  }, [emitEvent, safeSetState]);

  // ---------------------------------------------------------------------------
  // setLanguage
  // ---------------------------------------------------------------------------
  const setLanguage = useCallback(
    (code: string) => {
      const previousLanguage = selectedLanguage;
      safeSetState(setSelectedLanguage, code);

      emitEvent({
        type: 'language_changed',
        timestamp: Date.now(),
        from: previousLanguage,
        to: code,
      });
    },
    [selectedLanguage, emitEvent, safeSetState]
  );

  // ---------------------------------------------------------------------------
  // loadStarters
  // ---------------------------------------------------------------------------
  const loadStarters = useCallback(async () => {
    const client = apiClientRef.current;
    if (!client) return;

    try {
      const starters = await client.getStarters(selectedLanguage);
      safeSetState(setStarterQuestions, starters);
    } catch (error: unknown) {
      // Starter questions are non-critical; fail silently
      const message =
        error instanceof Error ? error.message : 'Failed to load starter questions';

      emitEvent({
        type: 'error',
        timestamp: Date.now(),
        sessionId: sessionIdRef.current,
        code: ErrorCodes.UNKNOWN,
        message,
        fatal: false,
      });
    }
  }, [selectedLanguage, emitEvent, safeSetState]);

  // ---------------------------------------------------------------------------
  // completeOnboarding
  // ---------------------------------------------------------------------------
  const completeOnboarding = useCallback(
    async (location: { lat: number; lng: number }, language: string) => {
      const client = apiClientRef.current;
      if (!client) return;

      try {
        await client.submitOnboarding({ location, language });

        safeSetState(setSelectedLanguage, language);
        safeSetState(setCurrentScreen, 'chat');

        emitEvent({
          type: 'onboarding_completed',
          timestamp: Date.now(),
          sessionId: sessionIdRef.current,
          location,
          language,
        });
      } catch (error: unknown) {
        const message =
          error instanceof Error ? error.message : 'Onboarding failed';

        safeSetState(setErrorMessage, message);

        emitEvent({
          type: 'error',
          timestamp: Date.now(),
          sessionId: sessionIdRef.current,
          code: ErrorCodes.ONBOARDING_FAILED,
          message,
          fatal: false,
        });
      }
    },
    [emitEvent, safeSetState]
  );

  // ---------------------------------------------------------------------------
  // navigateTo
  // ---------------------------------------------------------------------------
  const navigateTo = useCallback(
    (screen: Screen) => {
      safeSetState(setCurrentScreen, screen);
    },
    [safeSetState]
  );

  // ---------------------------------------------------------------------------
  // setIsConnected (public setter)
  // ---------------------------------------------------------------------------
  const setIsConnectedPublic = useCallback(
    (connected: boolean) => {
      safeSetState(setIsConnected, connected);
    },
    [safeSetState]
  );

  // ---------------------------------------------------------------------------
  // Return
  // ---------------------------------------------------------------------------
  return {
    // State
    chatState,
    messages,
    starterQuestions,
    currentScreen,
    isConnected,
    selectedLanguage,
    availableLanguages,
    errorMessage,
    streamingMarkdown,

    // Actions
    sendQuery,
    sendFollowUp,
    stopStream,
    retryLastQuery,
    submitFeedback,
    loadHistory,
    loadLanguages,
    setLanguage,
    loadStarters,
    completeOnboarding,
    navigateTo,
    setIsConnected: setIsConnectedPublic,
  };
}
