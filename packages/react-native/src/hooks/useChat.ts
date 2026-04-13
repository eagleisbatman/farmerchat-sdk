import { useState, useRef, useCallback, useEffect } from 'react';
import { useFarmerChatConfig } from '../FarmerChat';
import { FarmerChatSDK } from '../config/SDKConfig';
import { ChatApiClient } from '../network/ChatApiClient';
import { TokenStorage } from '../network/TokenStorage';
import { GuestApiClient } from '../network/GuestApiClient';
import type {
  ConversationListItem,
  ConversationChatHistoryMessageItem,
  SupportedLanguageGroup,
} from '../models/responses';
import type { TriggeredInputType } from '../models/requests';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type ChatState = 'idle' | 'sending' | 'error';
type Screen = 'onboarding' | 'chat' | 'history' | 'profile';

export interface FollowUp {
  follow_up_question_id: string;
  question: string;
  sequence: number;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  timestamp: number;
  inputMethod?: TriggeredInputType;
  imageData?: string;
  followUps: FollowUp[];
  contentProviderLogo?: string;
  hideTtsSpeaker: boolean;
  serverMessageId?: string;
}

export interface UseChatReturn {
  // State
  chatState: ChatState;
  messages: ChatMessage[];
  currentScreen: Screen;
  isConnected: boolean;
  selectedLanguage: string;
  conversationList: ConversationListItem[];
  availableLanguageGroups: SupportedLanguageGroup[];
  errorMessage: string | null;

  // Actions
  sendQuery: (text: string, inputMethod?: TriggeredInputType, imageData?: string) => Promise<void>;
  sendFollowUp: (text: string, followUpQuestionId?: string) => Promise<void>;
  retryLastQuery: () => Promise<void>;
  startNewConversation: () => void;
  loadConversationList: () => Promise<void>;
  loadConversation: (item: ConversationListItem) => Promise<void>;
  loadLanguages: () => Promise<void>;
  synthesiseAudio: (serverMessageId: string, text: string) => Promise<string | null>;
  transcribeAudio: (base64Audio: string, format?: string) => Promise<string | null>;
  transcribeAndSendAudio: (base64Audio: string, format?: string) => Promise<void>;
  sendQueryWithImage: (caption: string, base64Image: string) => Promise<void>;
  setLanguage: (code: string) => void;
  navigateTo: (screen: Screen) => void;
  setIsConnected: (connected: boolean) => void;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function generateId(): string {
  const g = globalThis as { crypto?: { randomUUID?: () => string } };
  if (g.crypto?.randomUUID) return g.crypto.randomUUID();
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
 * Full chat state machine hook for FarmerChat.
 *
 * State flow: Idle → Sending → Idle | Error
 *
 * All networking uses `ChatApiClient` (fetch-based). All state is in React hooks.
 * No local persistence.
 */
export function useChat(): UseChatReturn {
  const config = useFarmerChatConfig();

  // --- Refs ---
  const apiClientRef = useRef<ChatApiClient | null>(null);
  const conversationIdRef = useRef<string | null>(null);
  const lastQueryRef = useRef<{ text: string; inputMethod: TriggeredInputType; imageData?: string } | null>(null);

  // --- State ---
  const [chatState, setChatState] = useState<ChatState>('idle');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [currentScreen, setCurrentScreen] = useState<Screen>('chat');
  const [isConnected, setIsConnected] = useState(true);
  const [selectedLanguage, setSelectedLanguage] = useState('en');
  const [conversationList, setConversationList] = useState<ConversationListItem[]>([]);
  const [availableLanguageGroups, setAvailableLanguageGroups] = useState<SupportedLanguageGroup[]>([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // --- Init API client + determine initial screen ---
  useEffect(() => {
    if (!FarmerChatSDK.isConfigured()) {
      FarmerChatSDK.configure(config);
    }
    apiClientRef.current = new ChatApiClient(FarmerChatSDK.getConfig());

    void FarmerChatSDK.ensureTokens().catch(() => {});

    // Restore persisted language preference
    void TokenStorage.getSelectedLanguage().then(saved => {
      if (saved) setSelectedLanguage(saved);
    });

    // Determine starting screen
    if (config.defaultLanguage) {
      // Host app configured a language — skip onboarding
      setSelectedLanguage(config.defaultLanguage);
      setCurrentScreen('chat');
    } else {
      void TokenStorage.isOnboardingDone().then(done => {
        setCurrentScreen(done ? 'chat' : 'onboarding');
      });
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // --- Append a message, capped at 50 ---
  const appendMessage = useCallback((msg: ChatMessage) => {
    setMessages(prev => {
      const next = [...prev, msg];
      return next.length > 50 ? next.slice(next.length - 50) : next;
    });
  }, []);

  // --- Ensure guest tokens before any API call ---
  const ensureTokens = useCallback(async () => {
    try {
      await GuestApiClient.ensureTokens(config.baseUrl);
    } catch {
      // Best-effort; will surface as a network error
    }
  }, [config.baseUrl]);

  // --- Ensure conversation ID exists ---
  const ensureConversation = useCallback(async (): Promise<string> => {
    if (conversationIdRef.current) return conversationIdRef.current;

    const client = apiClientRef.current;
    if (!client) throw new Error('Chat client not initialized');

    const userId = await TokenStorage.getUserId();
    const resp = await client.createNewConversation({
      user_id: userId,
      content_provider_id: config.contentProviderId ?? null,
    });
    conversationIdRef.current = resp.conversation_id;
    return resp.conversation_id;
  }, [config.contentProviderId]);

  // ---------------------------------------------------------------------------
  // sendQuery
  // ---------------------------------------------------------------------------

  const sendQuery = useCallback(async (
    text: string,
    inputMethod: TriggeredInputType = 'text',
    imageData?: string,
  ) => {
    const client = apiClientRef.current;
    if (!client) {
      setErrorMessage('SDK not initialized');
      setChatState('error');
      return;
    }

    lastQueryRef.current = { text, inputMethod, imageData };

    const userMessageId = generateId();
    appendMessage({
      id: userMessageId,
      role: 'user',
      text,
      timestamp: Date.now(),
      inputMethod,
      imageData,
      followUps: [],
      hideTtsSpeaker: false,
    });

    setChatState('sending');
    setErrorMessage(null);

    try {
      await ensureTokens();
      const conversationId = await ensureConversation();
      const clientMessageId = generateId();

      if (imageData) {
        const resp = await client.sendImageAnalysis({
          conversation_id: conversationId,
          image: imageData,
          triggered_input_type: 'image',
          image_name: `image_${generateId()}.jpg`,
          retry: false,
        });

        appendMessage({
          id: generateId(),
          role: 'assistant',
          text: resp.response,
          timestamp: Date.now(),
          followUps: resp.follow_up_questions?.map(f => ({
            follow_up_question_id: f.follow_up_question_id,
            question: f.question,
            sequence: f.sequence,
          })) ?? [],
          contentProviderLogo: resp.content_provider_logo,
          hideTtsSpeaker: resp.hide_tts_speaker ?? false,
          serverMessageId: resp.message_id,
        });
      } else {
        const resp = await client.sendTextPrompt({
          query: text,
          conversation_id: conversationId,
          message_id: clientMessageId,
          triggered_input_type: inputMethod,
          weather_cta_triggered: false,
          use_entity_extraction: true,
          retry: false,
        });

        const answerText = resp.response ?? resp.message ?? '';
        appendMessage({
          id: generateId(),
          role: 'assistant',
          text: answerText,
          timestamp: Date.now(),
          followUps: resp.follow_up_questions?.map(f => ({
            follow_up_question_id: f.follow_up_question_id,
            question: f.question,
            sequence: f.sequence,
          })) ?? [],
          contentProviderLogo: resp.content_provider_logo,
          hideTtsSpeaker: resp.hide_tts_speaker ?? false,
          serverMessageId: resp.message_id,
        });
      }

      setChatState('idle');
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setErrorMessage(msg);
      setChatState('error');
    }
  }, [appendMessage, ensureConversation, ensureTokens]);

  // ---------------------------------------------------------------------------
  // sendFollowUp
  // ---------------------------------------------------------------------------

  const sendFollowUp = useCallback(async (text: string, followUpQuestionId?: string) => {
    const client = apiClientRef.current;
    if (client && followUpQuestionId) {
      // API expects the question text in follow_up_question, not the id
      void client.trackFollowUpClick({ follow_up_question: text }).catch(() => {});
    }
    await sendQuery(text, 'follow_up');
  }, [sendQuery]);

  // ---------------------------------------------------------------------------
  // retryLastQuery
  // ---------------------------------------------------------------------------

  const retryLastQuery = useCallback(async () => {
    const q = lastQueryRef.current;
    if (!q) return;
    setChatState('idle');
    setErrorMessage(null);
    await sendQuery(q.text, q.inputMethod, q.imageData);
  }, [sendQuery]);

  // ---------------------------------------------------------------------------
  // startNewConversation
  // ---------------------------------------------------------------------------

  const startNewConversation = useCallback(() => {
    conversationIdRef.current = null;
    setMessages([]);
    setChatState('idle');
    setErrorMessage(null);
  }, []);

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  const loadConversationList = useCallback(async () => {
    const client = apiClientRef.current;
    if (!client) {
      console.warn('[FC.useChat] loadConversationList: SDK not configured');
      return;
    }
    console.log('[FC.useChat] loadConversationList: fetching…');
    try {
      await ensureTokens();
      const list = await client.getConversationList();
      console.log('[FC.useChat] loadConversationList: received', list.length, 'conversations');
      setConversationList(list);
    } catch (err) {
      console.error('[FC.useChat] loadConversationList FAILED:', err);
      throw err;
    }
  }, [ensureTokens]);

  const loadConversation = useCallback(async (item: ConversationListItem) => {
    const client = apiClientRef.current;
    if (!client) return;
    try {
      await ensureTokens();
      const history = await client.getChatHistory(item.conversation_id);
      conversationIdRef.current = item.conversation_id;

      const msgs: ChatMessage[] = history.data
        .map(historyItemToMessage)
        .filter((m): m is ChatMessage => m !== null);
      setMessages(msgs);
      setCurrentScreen('chat');
    } catch {
      // Silently fail
    }
  }, [ensureTokens]);

  // ---------------------------------------------------------------------------
  // TTS / STT
  // ---------------------------------------------------------------------------

  const synthesiseAudio = useCallback(async (serverMessageId: string, text: string): Promise<string | null> => {
    const client = apiClientRef.current;
    if (!client) return null;
    try {
      await ensureTokens();
      const userId = await TokenStorage.getUserId();
      const resp = await client.synthesiseAudio({ message_id: serverMessageId, text, user_id: userId });
      return resp.audio ?? null;
    } catch {
      return null;
    }
  }, [ensureTokens]);

  const transcribeAudio = useCallback(async (base64Audio: string, format = 'AMR'): Promise<string | null> => {
    const client = apiClientRef.current;
    const convId = conversationIdRef.current;
    if (!client || !convId) return null;
    try {
      await ensureTokens();
      const resp = await client.transcribeAudio({
        conversation_id: convId,
        query: base64Audio,
        message_reference_id: generateId(),
        input_audio_encoding_format: format as never,
        triggered_input_type: 'audio',
        editable_transcription: true,
      });
      return resp.error ? null : (resp.heard_input_query ?? null);
    } catch {
      return null;
    }
  }, [ensureTokens]);

  // ---------------------------------------------------------------------------
  // High-level voice + image flows
  // ---------------------------------------------------------------------------

  const transcribeAndSendAudio = useCallback(async (base64Audio: string, format = 'LINEAR16'): Promise<void> => {
    const client = apiClientRef.current;
    if (!client) return;
    const audioMsgId = generateId();
    setMessages(prev => [...prev, {
      id: audioMsgId, role: 'user', text: '🎤 …', timestamp: Date.now(), inputMethod: 'audio',
    }]);
    setChatState('sending');
    try {
      await ensureTokens();
      const convId = await ensureConversation();
      const transcribeResp = await client.transcribeAudio({
        conversation_id: convId,
        query: base64Audio,
        message_reference_id: generateId(),
        input_audio_encoding_format: format as never,
        triggered_input_type: 'audio',
        editable_transcription: true,
      });
      const transcript = transcribeResp.error ? null : (transcribeResp.heard_input_query ?? null);
      if (!transcript) {
        setMessages(prev => prev.map(m => m.id === audioMsgId
          ? { ...m, text: '⚠️ Could not understand audio' } : m));
        setChatState('idle');
        return;
      }
      setMessages(prev => prev.map(m => m.id === audioMsgId ? { ...m, text: transcript } : m));
      // Send the transcribed text via the standard text query flow
      await sendQuery(transcript, 'audio');
    } catch {
      setChatState('idle');
    }
  }, [ensureTokens, ensureConversation, sendQuery, setMessages, setChatState]);

  const sendQueryWithImage = useCallback(async (caption: string, base64Image: string): Promise<void> => {
    await sendQuery(caption || 'Analyze this image', 'image', base64Image);
  }, [sendQuery]);

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

  const setLanguage = useCallback((code: string) => {
    setSelectedLanguage(code);
    void TokenStorage.setSelectedLanguage(code).catch(() => {});
  }, []);

  const navigateTo = useCallback((screen: Screen) => {
    setCurrentScreen(prev => {
      if (prev === 'onboarding' && screen === 'chat') {
        void TokenStorage.setOnboardingDone().catch(() => {});
      }
      return screen;
    });
  }, []);

  const loadLanguages = useCallback(async () => {
    const client = apiClientRef.current;
    if (!client) {
      console.warn('[FC.useChat] loadLanguages: SDK not configured — call FarmerChatSDK.configure() first');
      return;
    }
    console.log('[FC.useChat] loadLanguages: ensuring tokens…');
    try {
      await ensureTokens();
      console.log('[FC.useChat] loadLanguages: fetching supported languages…');
      const groups = await client.getSupportedLanguages();
      console.log('[FC.useChat] loadLanguages: received', groups.flatMap(g => g.languages).length, 'languages');
      setAvailableLanguageGroups(groups);
    } catch (err) {
      console.error('[FC.useChat] loadLanguages FAILED:', err);
    }
  }, [ensureTokens]);

  return {
    chatState,
    messages,
    currentScreen,
    isConnected,
    selectedLanguage,
    conversationList,
    availableLanguageGroups,
    errorMessage,
    sendQuery,
    sendFollowUp,
    retryLastQuery,
    startNewConversation,
    loadConversationList,
    loadConversation,
    loadLanguages,
    synthesiseAudio,
    transcribeAudio,
    transcribeAndSendAudio,
    sendQueryWithImage,
    setLanguage,
    navigateTo,
    setIsConnected,
  };
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

function historyItemToMessage(item: ConversationChatHistoryMessageItem): ChatMessage | null {
  switch (item.message_type_id) {
    case 1:
      return {
        id: item.message_id,
        role: 'user',
        text: item.query_text ?? '',
        timestamp: Date.now(),
        inputMethod: 'text',
        followUps: [],
        hideTtsSpeaker: false,
        serverMessageId: item.message_id,
      };
    case 2:
      return {
        id: item.message_id,
        role: 'user',
        text: item.heard_query_text ?? item.query_text ?? '',
        timestamp: Date.now(),
        inputMethod: 'audio',
        followUps: [],
        hideTtsSpeaker: false,
        serverMessageId: item.message_id,
      };
    case 11:
      return {
        id: item.message_id,
        role: 'user',
        text: item.query_text ?? '',
        timestamp: Date.now(),
        inputMethod: 'image',
        followUps: [],
        hideTtsSpeaker: false,
        serverMessageId: item.message_id,
      };
    case 3:
      return {
        id: item.message_id,
        role: 'assistant',
        text: item.response_text ?? '',
        timestamp: Date.now(),
        followUps: item.questions?.map(q => ({
          follow_up_question_id: q.follow_up_question_id,
          question: q.question,
          sequence: q.sequence,
        })) ?? [],
        contentProviderLogo: item.content_provider_logo,
        hideTtsSpeaker: item.hide_tts_speaker ?? false,
        serverMessageId: item.message_id,
      };
    default:
      return null;
  }
}

// Polyfill Array.prototype.compactMap for use above
declare global {
  interface Array<T> {
    compactMap<U>(transform: (item: T) => U | null): U[];
  }
}
if (!Array.prototype.compactMap) {
  Array.prototype.compactMap = function <T, U>(transform: (item: T) => U | null): U[] {
    return this.reduce((acc: U[], item: T) => {
      const result = transform(item);
      if (result !== null && result !== undefined) acc.push(result);
      return acc;
    }, []);
  };
}
