export interface InitializeGuestUserResponse {
  access_token: string;
  refresh_token: string;
  user_id?: string;
  created_now?: boolean;
  country_code?: string;
  country?: string;
  state?: string;
}

export interface RefreshTokenResponse {
  access_token?: string;
  refresh_token?: string;
}

export interface NewConversationResponse {
  conversation_id: string;
  message: string;
  show_popup: boolean;
}

export interface FollowUpQuestionOption {
  follow_up_question_id: string;
  sequence: number;
  question: string;
}

export interface IntentClassificationOutput {
  intent?: string;
  confidence?: string;
  asset_type?: string;
  asset_name?: string;
  asset_status?: string;
  concern?: string;
  stage?: string;
  likely_activity?: string;
  rephrased_query?: string;
  seasonal_relevance?: string;
}

export interface TextPromptResponse {
  error: boolean;
  message?: string;
  message_id?: string;
  response?: string;
  translated_response?: string;
  follow_up_questions?: FollowUpQuestionOption[];
  section_message_id?: string;
  content_provider_logo?: string;
  hide_feedback_icons?: boolean;
  hide_follow_up_question?: boolean;
  hide_share_icon?: boolean;
  hide_tts_speaker?: boolean;
  points?: number;
  intent_classification_output?: IntentClassificationOutput;
}

export interface ImageAnalysisResponse {
  error: boolean;
  message: string;
  message_id: string;
  response: string;
  follow_up_questions?: FollowUpQuestionOption[];
  content_provider_logo?: string;
  hide_tts_speaker?: boolean;
  points?: number;
}

export interface Question {
  follow_up_question_id: string;
  question: string;
  sequence: number;
}

export interface FollowUpQuestionsResponse {
  message_id: string;
  section_message_id: string;
  questions?: Question[];
}

export interface SynthesiseAudioResponse {
  audio?: string;   // base64-encoded audio
  text?: string;
  error: boolean;
}

export interface GetVoiceResponse {
  message?: string;
  heard_input_query?: string;
  confidence_score?: number;
  error: boolean;
  message_id: string;
  transcription_id?: string;
}

export interface ConversationChatHistoryQuestion {
  follow_up_question_id: string;
  question: string;
  sequence: number;
}

export interface ConversationChatHistoryMessageItem {
  message_type_id: number;
  message_type: string;
  message_id: string;
  query_text?: string;
  heard_query_text?: string;
  response_text?: string;
  questions?: ConversationChatHistoryQuestion[];
  query_media_file_url?: string;
  response_media_file_url?: string;
  content_provider_logo?: string;
  hide_tts_speaker?: boolean;
}

export interface ConversationChatHistoryResponse {
  conversation_id: string;
  data: ConversationChatHistoryMessageItem[];
}

export interface ConversationListItem {
  conversation_id: string;
  conversation_title?: string;
  created_on: string;
  message_type?: string;
  grouping?: string;
  content_provider_logo?: string;
}

export type ConversationListResponse = ConversationListItem[];

export interface SupportedLanguage {
  id: number;
  name: string;
  code: string;
  display_name: string;
}

export interface SupportedLanguageGroup {
  country_name?: string;
  country_code?: string;
  languages: SupportedLanguage[];
}
