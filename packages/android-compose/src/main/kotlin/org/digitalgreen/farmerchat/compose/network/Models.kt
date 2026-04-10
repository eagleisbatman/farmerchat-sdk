package org.digitalgreen.farmerchat.compose.network

import org.json.JSONArray
import org.json.JSONObject

// ── Helpers ──────────────────────────────────────────────────────────────────

internal inline fun <T> JSONArray.mapObjects(transform: (JSONObject) -> T): List<T> =
    (0 until length()).map { transform(getJSONObject(it)) }

internal fun JSONObject.optStringOrNull(key: String): String? =
    if (isNull(key)) null else optString(key, null)

// ── Auth / Guest ──────────────────────────────────────────────────────────────

internal data class InitializeGuestUserResponse(
    val accessToken: String,
    val refreshToken: String,
    val userId: String,
    val createdNow: Boolean,
    val showCropsLivestocks: Boolean,
    val countryCode: String?,
    val country: String?,
    val state: String?,
)

internal data class RefreshTokenResponse(
    val accessToken: String?,
    val refreshToken: String?,
)

internal data class SendNewTokenResponse(
    val accessToken: String?,
    val refreshToken: String?,
    val message: String?,
)

// ── Language (Android-only) ───────────────────────────────────────────────────

internal data class SupportedLanguage(
    val id: Int,
    val name: String,
    val code: String,
    val displayName: String,
    val flag: String?,
    val isAsrEnabled: Boolean,
    val isTtsEnabled: Boolean,
) {
    companion object {
        fun fromJson(json: JSONObject): SupportedLanguage = SupportedLanguage(
            id = json.optInt("id", 0),
            name = json.optString("name", ""),
            code = json.optString("code", ""),
            displayName = json.optString("display_name", ""),
            flag = json.optStringOrNull("flag"),
            isAsrEnabled = json.optBoolean("asr_enabled", false),
            isTtsEnabled = json.optBoolean("tts_enabled", false),
        )
    }
}

internal data class SupportedLanguageGroup(
    val displayName: String,
    val flag: String,
    val languages: List<SupportedLanguage>,
) {
    companion object {
        fun fromJson(json: JSONObject): SupportedLanguageGroup = SupportedLanguageGroup(
            displayName = json.optString("displayName", ""),
            flag = json.optString("flag", ""),
            languages = json.optJSONArray("languages")?.mapObjects { SupportedLanguage.fromJson(it) }
                ?: emptyList(),
        )
    }
}

internal data class SetPreferredLanguageResponse(val userId: String) {
    companion object {
        fun fromJson(json: JSONObject) = SetPreferredLanguageResponse(
            userId = json.optString("user_id", ""),
        )
    }
}

// ── Conversation ──────────────────────────────────────────────────────────────

internal data class NewConversationResponse(
    val conversationId: String,
    val message: String,
    val showPopup: Boolean,
) {
    companion object {
        fun fromJson(json: JSONObject) = NewConversationResponse(
            conversationId = json.optString("conversation_id", ""),
            message = json.optString("message", ""),
            showPopup = json.optBoolean("show_popup", false),
        )
    }
}

// ── Follow-up ─────────────────────────────────────────────────────────────────

internal data class FollowUpQuestionOption(
    val followUpQuestionId: String?,
    val sequence: Int,
    val question: String?,
) {
    companion object {
        fun fromJson(json: JSONObject) = FollowUpQuestionOption(
            followUpQuestionId = json.optStringOrNull("follow_up_question_id"),
            sequence = json.optInt("sequence", 0),
            question = json.optStringOrNull("question"),
        )
    }
}

// ── Intent classification ─────────────────────────────────────────────────────

internal data class IntentClassificationOutput(
    val intent: String?,
    val confidence: String?,
    val assetType: String?,
    val assetName: String?,
    val assetStatus: String?,
    val concern: String?,
    val stage: String?,
    val likelyActivity: String?,
    val rephrasedQuery: String?,
    val seasonalRelevance: String?,
) {
    companion object {
        fun fromJson(json: JSONObject) = IntentClassificationOutput(
            intent = json.optStringOrNull("intent"),
            confidence = json.optStringOrNull("confidence"),
            assetType = json.optStringOrNull("asset_type"),
            assetName = json.optStringOrNull("asset_name"),
            assetStatus = json.optStringOrNull("asset_status"),
            concern = json.optStringOrNull("concern"),
            stage = json.optStringOrNull("stage"),
            likelyActivity = json.optStringOrNull("likely_activity"),
            rephrasedQuery = json.optStringOrNull("rephrased_query"),
            seasonalRelevance = json.optStringOrNull("seasonal_relevance"),
        )
    }
}

// ── Text prompt ───────────────────────────────────────────────────────────────

internal data class TextPromptResponse(
    val error: Boolean,
    val message: String?,
    val messageId: String?,
    val response: String?,
    val translatedResponse: String?,
    val followUpQuestions: List<FollowUpQuestionOption>?,
    val sectionMessageId: String?,
    val contentProviderLogo: String?,
    val hideFollowUpQuestion: Boolean?,
    val hideTtsSpeaker: Boolean?,
    val points: Int?,
    val intentClassificationOutput: IntentClassificationOutput?,
) {
    companion object {
        fun fromJson(json: JSONObject) = TextPromptResponse(
            error = json.optBoolean("error", false),
            message = json.optStringOrNull("message"),
            messageId = json.optStringOrNull("message_id"),
            response = json.optStringOrNull("response"),
            translatedResponse = json.optStringOrNull("translated_response"),
            followUpQuestions = json.optJSONArray("follow_up_questions")
                ?.mapObjects { FollowUpQuestionOption.fromJson(it) },
            sectionMessageId = json.optStringOrNull("section_message_id"),
            contentProviderLogo = json.optStringOrNull("content_provider_logo"),
            hideFollowUpQuestion = if (json.has("hide_follow_up_question")) json.optBoolean("hide_follow_up_question") else null,
            hideTtsSpeaker = if (json.has("hide_tts_speaker")) json.optBoolean("hide_tts_speaker") else null,
            points = if (json.has("points")) json.optInt("points") else null,
            intentClassificationOutput = json.optJSONObject("intent_classification_output")
                ?.let { IntentClassificationOutput.fromJson(it) },
        )
    }
}

// ── Image analysis (Plantix) ──────────────────────────────────────────────────

internal data class PlantixResponse(
    val error: Boolean,
    val message: String,
    val messageId: String,
    val response: String,
    val followUpQuestions: List<FollowUpQuestionOption>?,
    val contentProviderLogo: String?,
    val hideTtsSpeaker: Boolean?,
    val points: Int?,
) {
    companion object {
        fun fromJson(json: JSONObject) = PlantixResponse(
            error = json.optBoolean("error", false),
            message = json.optString("message", ""),
            messageId = json.optString("message_id", ""),
            response = json.optString("response", ""),
            followUpQuestions = json.optJSONArray("follow_up_questions")
                ?.mapObjects { FollowUpQuestionOption.fromJson(it) },
            contentProviderLogo = json.optStringOrNull("content_provider_logo"),
            hideTtsSpeaker = if (json.has("hide_tts_speaker")) json.optBoolean("hide_tts_speaker") else null,
            points = if (json.has("points")) json.optInt("points") else null,
        )
    }
}

// ── Follow-up questions ───────────────────────────────────────────────────────

internal data class FollowUpQuestionsResponse(
    val messageId: String,
    val questions: List<FollowUpQuestionOption>?,
    val sectionMessageId: String,
) {
    companion object {
        fun fromJson(json: JSONObject) = FollowUpQuestionsResponse(
            messageId = json.optString("message_id", ""),
            questions = json.optJSONArray("questions")
                ?.mapObjects { FollowUpQuestionOption.fromJson(it) },
            sectionMessageId = json.optString("section_message_id", ""),
        )
    }
}

// ── Text-to-speech ────────────────────────────────────────────────────────────

internal data class SynthesiseAudioResponse(
    val message: String?,
    val error: Boolean,
    val audio: String?,
    val text: String?,
) {
    companion object {
        fun fromJson(json: JSONObject) = SynthesiseAudioResponse(
            message = json.optStringOrNull("message"),
            error = json.optBoolean("error", false),
            audio = json.optStringOrNull("audio"),
            text = json.optStringOrNull("text"),
        )
    }
}

// ── Speech-to-text ────────────────────────────────────────────────────────────

internal data class GetVoiceResponse(
    val message: String?,
    val heardInputQuery: String?,
    val confidenceScore: Double?,
    val error: Boolean,
    val messageId: String,
    val transcriptionId: String?,
) {
    companion object {
        fun fromJson(json: JSONObject) = GetVoiceResponse(
            message = json.optStringOrNull("message"),
            heardInputQuery = json.optStringOrNull("heard_input_query"),
            confidenceScore = if (json.has("confidence_score")) json.optDouble("confidence_score") else null,
            error = json.optBoolean("error", false),
            messageId = json.optString("message_id", ""),
            transcriptionId = json.optStringOrNull("transcription_id"),
        )
    }
}

// ── History ───────────────────────────────────────────────────────────────────

internal data class ConversationListItem(
    val conversationId: String,
    val conversationTitle: String?,
    val createdOn: String,
    val messageType: String?,
    val grouping: String?,
    val contentProviderLogo: String?,
) {
    companion object {
        fun fromJson(json: JSONObject) = ConversationListItem(
            conversationId = json.optString("conversation_id", ""),
            conversationTitle = json.optStringOrNull("conversation_title"),
            createdOn = json.optString("created_on", ""),
            messageType = json.optStringOrNull("message_type"),
            grouping = json.optStringOrNull("grouping"),
            contentProviderLogo = json.optStringOrNull("content_provider_logo"),
        )
    }
}

internal data class ConversationHistoryQuestion(
    val followUpQuestionId: String,
    val question: String,
    val sequence: Int,
) {
    companion object {
        fun fromJson(json: JSONObject) = ConversationHistoryQuestion(
            followUpQuestionId = json.optString("follow_up_question_id", ""),
            question = json.optString("question", ""),
            sequence = json.optInt("sequence", 0),
        )
    }
}

internal data class ConversationHistoryItem(
    val messageTypeId: Int,
    val messageType: String,
    val messageId: String,
    val queryText: String?,
    val heardQueryText: String?,
    val responseText: String?,
    val questions: List<ConversationHistoryQuestion>?,
    val queryMediaFileUrl: String?,
    val contentProviderLogo: String?,
    val hideTtsSpeaker: Boolean?,
) {
    companion object {
        fun fromJson(json: JSONObject) = ConversationHistoryItem(
            messageTypeId = json.optInt("message_type_id", 0),
            messageType = json.optString("message_type", ""),
            messageId = json.optString("message_id", ""),
            queryText = json.optStringOrNull("query_text"),
            heardQueryText = json.optStringOrNull("heard_query_text"),
            responseText = json.optStringOrNull("response_text"),
            questions = json.optJSONArray("questions")
                ?.mapObjects { ConversationHistoryQuestion.fromJson(it) },
            queryMediaFileUrl = json.optStringOrNull("query_media_file_url"),
            contentProviderLogo = json.optStringOrNull("content_provider_logo"),
            hideTtsSpeaker = if (json.has("hide_tts_speaker")) json.optBoolean("hide_tts_speaker") else null,
        )
    }
}

internal data class ConversationChatHistoryResponse(
    val conversationId: String,
    val data: List<ConversationHistoryItem>,
) {
    companion object {
        fun fromJson(json: JSONObject) = ConversationChatHistoryResponse(
            conversationId = json.optString("conversation_id", ""),
            data = json.optJSONArray("data")
                ?.mapObjects { ConversationHistoryItem.fromJson(it) }
                ?: emptyList(),
        )
    }
}
