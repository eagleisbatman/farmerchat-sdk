export interface InitUserResponse {
  access_token:  string;
  refresh_token: string;
  user_id:       string;
  country_code?: string;
  state?:        string;
}

export interface SupportedLanguage {
  id:           number;
  code:         string;
  name:         string;
  display_name: string;
}

export interface SupportedLanguageGroup {
  displayName?: string;
  flag?:        string;
  languages:    SupportedLanguage[];
}

export interface NewConversationResponse {
  conversation_id: string;
}

export interface FollowUpOption {
  follow_up_question_id: string;
  question:              string;
  sequence:              number;
}

export interface TextPromptChunk {
  text?:                  string;
  message_id?:            string;
  section_message_id?:    string;
  follow_up_questions?:   FollowUpOption[];
  content_provider_logo?: string;
  error?:                 boolean;
  hide_follow_up_question?: boolean;
}

export interface ConversationListItem {
  conversation_id:     string;
  conversation_title?: string;
  created_on?:         string;
  grouping?:           string;
}

export interface HistoryQuestion {
  follow_up_question_id: string;
  question:              string;
  sequence:              number;
}

export interface HistoryMessageItem {
  message_type_id:       number;
  message_id:            string;
  query_text?:           string;
  heard_query_text?:     string;
  response_text?:        string;
  questions?:            HistoryQuestion[];
  content_provider_logo?: string;
}

export interface ChatHistoryResponse {
  conversation_id: string;
  data:            HistoryMessageItem[];
}
