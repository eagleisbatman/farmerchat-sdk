export type TriggeredInputType = 'text' | 'audio' | 'image' | 'follow_up' | 'pregenerated';

export type AudioEncodingFormat =
  | 'LINEAR16'
  | 'AMR'
  | 'AMR_WB'
  | 'OGG_OPUS'
  | 'SPEEX_WITH_HEADER_BYTE'
  | 'MP3'
  | 'AAC';

export interface NewConversationRequest {
  user_id: string;
  content_provider_id: string | null;
}

export interface TextPromptRequest {
  query: string;
  conversation_id: string;
  message_id: string;
  statement_id?: string;
  weather_cta_triggered: boolean;
  triggered_input_type: TriggeredInputType;
  use_entity_extraction: boolean;
  transcription_id?: string;
  retry: boolean;
}

export interface ImageAnalysisRequest {
  conversation_id: string;
  image: string;            // base64
  triggered_input_type: TriggeredInputType;
  query?: string;
  latitude?: number;
  longitude?: number;
  image_name: string;
  retry: boolean;
}

export interface SynthesiseAudioRequest {
  message_id: string;
  text: string;
  user_id: string;
}

export interface FollowUpQuestionClickRequest {
  follow_up_question: string;
}

export interface TranscribeAudioRequest {
  conversation_id: string;
  query: string;                          // base64 audio
  message_reference_id: string;
  input_audio_encoding_format: AudioEncodingFormat;
  triggered_input_type: TriggeredInputType;
  editable_transcription: boolean;
}

export interface RefreshTokenRequest {
  refresh_token: string;
}

export interface SendNewTokenRequest {
  device_id: string;
  user_id: string;
}
