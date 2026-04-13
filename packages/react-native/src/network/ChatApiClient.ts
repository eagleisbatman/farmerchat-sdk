import {
  API_NEW_CONVERSATION,
  API_TEXT_PROMPT,
  API_IMAGE_ANALYSIS,
  API_FOLLOW_UP_QUESTIONS,
  API_FOLLOW_UP_CLICK,
  API_SYNTHESISE_AUDIO,
  API_TRANSCRIBE_AUDIO,
  API_CHAT_HISTORY,
  API_CONVERSATION_LIST,
  API_SUPPORTED_LANGUAGES,
} from '../config/constants';
import { addAuthHeaders } from './AuthInterceptor';
import { TokenRefreshHandler } from './TokenRefreshHandler';
import { TokenStorage } from './TokenStorage';
import { buildDeviceInfoHeader } from './deviceInfo';
import type {
  NewConversationRequest,
  TextPromptRequest,
  ImageAnalysisRequest,
  SynthesiseAudioRequest,
  TranscribeAudioRequest,
  FollowUpQuestionClickRequest,
} from '../models/requests';
import type {
  NewConversationResponse,
  TextPromptResponse,
  ImageAnalysisResponse,
  FollowUpQuestionsResponse,
  SynthesiseAudioResponse,
  GetVoiceResponse,
  ConversationChatHistoryResponse,
  ConversationListResponse,
  SupportedLanguageGroup,
} from '../models/responses';
import type { SDKConfiguration } from '../config/SDKConfig';

/**
 * HTTP client for all FarmerChat REST API calls.
 *
 * Uses the native `fetch` API. Handles 401 by refreshing tokens once and retrying.
 */
export class ChatApiClient {
  private baseUrl: string;
  private sdkApiKey: string;
  private contentProviderId?: string;
  private refreshHandler: TokenRefreshHandler;

  constructor(config: SDKConfiguration) {
    this.baseUrl = config.baseUrl.replace(/\/$/, '');
    this.sdkApiKey = config.sdkApiKey;
    this.contentProviderId = config.contentProviderId;
    this.refreshHandler = new TokenRefreshHandler(this.baseUrl, this.sdkApiKey);
  }

  // ── Core request helper ────────────────────────────────────────────────────

  private async request<T>(
    path: string,
    init: RequestInit,
    isRetry = false,
  ): Promise<T> {
    const [accessToken, deviceId] = await Promise.all([
      TokenStorage.getAccessToken(),
      TokenStorage.getDeviceId(),
    ]);
    const deviceInfo = buildDeviceInfoHeader(deviceId);
    const authInit = addAuthHeaders(init, accessToken, deviceInfo, this.sdkApiKey);

    const url = `${this.baseUrl}/${path}`;
    console.log(`[FC] → ${init.method ?? 'GET'} ${url}`);
    const response = await fetch(url, authInit);

    if (response.status === 401 && !isRetry) {
      const newToken = await this.refreshHandler.refreshIfNeeded();
      const retryInit = addAuthHeaders(init, newToken, deviceInfo, this.sdkApiKey);
      const retryResponse = await fetch(url, retryInit);
      if (!retryResponse.ok) {
        const body = await retryResponse.text().catch(() => '');
        throw new Error(`HTTP ${retryResponse.status}: ${body}`);
      }
      return retryResponse.json() as Promise<T>;
    }

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`HTTP ${response.status}: ${body}`);
    }

    return response.json() as Promise<T>;
  }

  private async get<T>(path: string, params: Record<string, string> = {}): Promise<T> {
    const qs = new URLSearchParams(params).toString();
    const fullPath = qs ? `${path}?${qs}` : path;
    return this.request<T>(fullPath, { method: 'GET' });
  }

  private async post<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>(path, {
      method: 'POST',
      body: JSON.stringify(body),
    });
  }

  // ── Conversation ───────────────────────────────────────────────────────────

  async createNewConversation(req: NewConversationRequest): Promise<NewConversationResponse> {
    return this.post(API_NEW_CONVERSATION, req);
  }

  // ── Text prompt ────────────────────────────────────────────────────────────

  async sendTextPrompt(req: TextPromptRequest): Promise<TextPromptResponse> {
    return this.post(API_TEXT_PROMPT, req);
  }

  // ── Image analysis ─────────────────────────────────────────────────────────

  async sendImageAnalysis(req: ImageAnalysisRequest): Promise<ImageAnalysisResponse> {
    return this.post(API_IMAGE_ANALYSIS, req);
  }

  // ── Follow-up questions ────────────────────────────────────────────────────

  async getFollowUpQuestions(
    messageId: string,
    useLatestPrompt = true,
  ): Promise<FollowUpQuestionsResponse> {
    return this.get(API_FOLLOW_UP_QUESTIONS, {
      message_id:        messageId,
      use_latest_prompt: String(useLatestPrompt),
    });
  }

  // ── Track follow-up click ──────────────────────────────────────────────────

  async trackFollowUpClick(req: FollowUpQuestionClickRequest): Promise<void> {
    await this.post(API_FOLLOW_UP_CLICK, req).catch(() => {
      // Fire-and-forget; ignore errors
    });
  }

  // ── TTS ────────────────────────────────────────────────────────────────────

  async synthesiseAudio(req: SynthesiseAudioRequest): Promise<SynthesiseAudioResponse> {
    return this.post(API_SYNTHESISE_AUDIO, req);
  }

  // ── STT (JSON, base64 audio in `query`) ───────────────────────────────────

  async transcribeAudio(req: TranscribeAudioRequest): Promise<GetVoiceResponse> {
    return this.post(API_TRANSCRIBE_AUDIO, req);
  }

  // ── History ────────────────────────────────────────────────────────────────

  async getConversationList(page = 1): Promise<ConversationListResponse> {
    const userId = await TokenStorage.getUserId();
    return this.get(API_CONVERSATION_LIST, { user_id: userId, page: String(page) });
  }

  async getChatHistory(conversationId: string, page = 1): Promise<ConversationChatHistoryResponse> {
    return this.get(API_CHAT_HISTORY, { conversation_id: conversationId, page: String(page) });
  }

  async getSupportedLanguages(countryCode?: string): Promise<SupportedLanguageGroup[]> {
    const params: Record<string, string> = {};
    if (countryCode) params.country_code = countryCode;
    return this.get(API_SUPPORTED_LANGUAGES, params);
  }
}
