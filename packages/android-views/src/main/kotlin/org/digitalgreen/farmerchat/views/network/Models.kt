package org.digitalgreen.farmerchat.views.network

import org.json.JSONArray
import org.json.JSONObject

// ── Guest / Auth ─────────────────────────────────────────────────────────────

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

// ── Conversation list (History) ───────────────────────────────────────────────

/**
 * A single conversation item returned by `GET /api/chat/conversation_list/`
 */
internal data class ConversationListItem(
    val conversationId: String,
    val conversationTitle: String?,
    val createdOn: String,
    val messageType: String?,
    val grouping: String?,
    val contentProviderLogo: String?,
) {
    internal companion object {
        fun fromJson(json: JSONObject) = ConversationListItem(
            conversationId    = json.optString("conversation_id", ""),
            conversationTitle = json.optString("conversation_title", null),
            createdOn         = json.optString("created_on", ""),
            messageType       = json.optString("message_type", null),
            grouping          = json.optString("grouping", null),
            contentProviderLogo = json.optString("content_provider_logo", null),
        )
    }
}

// ── Language ──────────────────────────────────────────────────────────────────

internal data class SupportedLanguage(
    val id: Int,
    val name: String,
    val code: String,
    val displayName: String,
    val flag: String?,
    val isAsrEnabled: Boolean,
    val isTtsEnabled: Boolean,
) {
    internal companion object {
        fun fromJson(json: JSONObject) = SupportedLanguage(
            id          = json.optInt("id", 0),
            name        = json.optString("name", ""),
            code        = json.optString("code", ""),
            displayName = json.optString("display_name", ""),
            flag        = json.optString("flag", null),
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
    internal companion object {
        fun fromJson(json: JSONObject): SupportedLanguageGroup {
            val langArray = json.optJSONArray("languages") ?: JSONArray()
            return SupportedLanguageGroup(
                displayName = json.optString("displayName", json.optString("display_name", "")),
                flag        = json.optString("flag", ""),
                languages   = (0 until langArray.length()).map {
                    SupportedLanguage.fromJson(langArray.getJSONObject(it))
                },
            )
        }
    }
}

// ── Follow-up questions ───────────────────────────────────────────────────────

internal data class FollowUpQuestionOption(
    val followUpQuestionId: String?,
    val sequence: Int,
    val question: String?,
) {
    internal companion object {
        fun fromJson(json: JSONObject) = FollowUpQuestionOption(
            followUpQuestionId = json.optString("follow_up_question_id", null),
            sequence           = json.optInt("sequence", 0),
            question           = json.optString("question", null),
        )
    }
}

// ── Text prompt response ─────────────────────────────────────────────────────

internal data class TextPromptResponse(
    val error: Boolean,
    val message: String?,
    val messageId: String?,
    val response: String?,
    val translatedResponse: String?,
    val followUpQuestions: List<FollowUpQuestionOption>,
    val sectionMessageId: String?,
    val contentProviderLogo: String?,
    val hideFollowUpQuestion: Boolean?,
    val hideTtsSpeaker: Boolean?,
) {
    internal companion object {
        fun fromJson(json: JSONObject): TextPromptResponse {
            val fuqArr = json.optJSONArray("follow_up_questions") ?: JSONArray()
            return TextPromptResponse(
                error               = json.optBoolean("error", false),
                message             = json.optString("message", null),
                messageId           = json.optString("message_id", null),
                response            = json.optString("response", null),
                translatedResponse  = json.optString("translated_response", null),
                followUpQuestions   = (0 until fuqArr.length()).map {
                    FollowUpQuestionOption.fromJson(fuqArr.getJSONObject(it))
                },
                sectionMessageId    = json.optString("section_message_id", null),
                contentProviderLogo = json.optString("content_provider_logo", null),
                hideFollowUpQuestion = json.optBoolean("hide_follow_up_question", false),
                hideTtsSpeaker      = json.optBoolean("hide_tts_speaker", false),
            )
        }
    }
}

// ── New conversation ──────────────────────────────────────────────────────────

internal data class NewConversationResponse(
    val conversationId: String,
    val message: String,
    val showPopup: Boolean,
) {
    internal companion object {
        fun fromJson(json: JSONObject) = NewConversationResponse(
            conversationId = json.optString("conversation_id", ""),
            message        = json.optString("message", ""),
            showPopup      = json.optBoolean("show_popup", false),
        )
    }
}

// ── TTS ───────────────────────────────────────────────────────────────────────

internal data class SynthesiseAudioResponse(
    val audio: String?,
    val text: String?,
    val error: Boolean,
) {
    internal companion object {
        fun fromJson(json: JSONObject) = SynthesiseAudioResponse(
            audio = json.optString("audio", null),
            text  = json.optString("text", null),
            error = json.optBoolean("error", false),
        )
    }
}

// ── STT ───────────────────────────────────────────────────────────────────────

internal data class GetVoiceResponse(
    val message: String?,
    val heardInputQuery: String?,
    val confidenceScore: Double?,
    val error: Boolean,
    val messageId: String,
    val transcriptionId: String?,
) {
    internal companion object {
        fun fromJson(json: JSONObject) = GetVoiceResponse(
            message          = json.optString("message", null),
            heardInputQuery  = json.optString("heard_input_query", null),
            confidenceScore  = if (json.has("confidence_score")) json.getDouble("confidence_score") else null,
            error            = json.optBoolean("error", false),
            messageId        = json.optString("message_id", ""),
            transcriptionId  = json.optString("transcription_id", null),
        )
    }
}

// ── Starter questions (legacy) ────────────────────────────────────────────────

internal data class StarterQuestionResponse(
    val text: String,
    val category: String? = null,
) {
    internal companion object {
        fun fromJson(json: JSONObject): StarterQuestionResponse = StarterQuestionResponse(
            text     = json.optString("text", ""),
            category = json.optString("category", null),
        )
    }
}

// ── SSE event ────────────────────────────────────────────────────────────────

internal data class SseEvent(
    val event: String,
    val data: String,
)

// ── JSON helpers ──────────────────────────────────────────────────────────────

internal inline fun <T> JSONArray.mapObjects(transform: (JSONObject) -> T): List<T> {
    return (0 until length()).map { transform(getJSONObject(it)) }
}
