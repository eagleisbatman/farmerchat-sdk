package org.digitalgreen.farmerchat.compose.network

import org.json.JSONArray
import org.json.JSONObject

// ── SSE ──────────────────────────────────────────────────────────────

/**
 * A single Server-Sent Event parsed from the stream.
 *
 * @property event Event type: "token", "followup", "done", "message", "error".
 * @property data Raw JSON string payload.
 */
internal data class SseEvent(
    val event: String,
    val data: String,
)

// ── Requests ─────────────────────────────────────────────────────────

/**
 * Request body for sending a chat query.
 */
internal data class QueryRequest(
    val text: String,
    val inputMethod: String,
    val language: String,
    val imageData: String? = null,
    val location: Location? = null,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("text", text)
        put("input_method", inputMethod)
        put("language", language)
        imageData?.let { put("image_data", it) }
        location?.let { loc ->
            put("location", JSONObject().apply {
                put("lat", loc.lat)
                put("lng", loc.lng)
            })
        }
    }
}

/**
 * Request body for submitting feedback on a response.
 */
internal data class FeedbackRequest(
    val responseId: String,
    val rating: String,
    val comment: String? = null,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("response_id", responseId)
        put("rating", rating)
        comment?.let { put("comment", it) }
    }
}

// ── Responses ────────────────────────────────────────────────────────

/**
 * A single message within a conversation history entry.
 */
internal data class MessageResponse(
    val id: String,
    val role: String,
    val text: String,
    val timestamp: Long = 0L,
    val imageData: String? = null,
    val followUps: List<String> = emptyList(),
) {
    internal companion object {
        fun fromJson(json: JSONObject): MessageResponse = MessageResponse(
            id = json.optString("id", ""),
            role = json.optString("role", ""),
            text = json.optString("text", ""),
            timestamp = json.optLong("timestamp", 0L),
            imageData = json.optString("image_data", null),
            followUps = json.optJSONArray("follow_ups")?.let { arr ->
                (0 until arr.length()).map { arr.optString(it, "") }
            } ?: emptyList(),
        )
    }
}

/**
 * A conversation returned from the history endpoint.
 */
internal data class ConversationResponse(
    val id: String,
    val title: String,
    val messages: List<MessageResponse>,
    val createdAt: Long = 0L,
    val updatedAt: Long = 0L,
) {
    internal companion object {
        fun fromJson(json: JSONObject): ConversationResponse = ConversationResponse(
            id = json.optString("id", ""),
            title = json.optString("title", ""),
            messages = json.optJSONArray("messages")?.let { arr ->
                (0 until arr.length()).map { MessageResponse.fromJson(arr.getJSONObject(it)) }
            } ?: emptyList(),
            createdAt = json.optLong("created_at", 0L),
            updatedAt = json.optLong("updated_at", 0L),
        )
    }
}

/**
 * A language option returned from the languages endpoint.
 */
internal data class LanguageResponse(
    val code: String,
    val name: String,
    val nativeName: String,
) {
    internal companion object {
        fun fromJson(json: JSONObject): LanguageResponse = LanguageResponse(
            code = json.optString("code", ""),
            name = json.optString("name", ""),
            nativeName = json.optString("native_name", ""),
        )
    }
}

/**
 * A starter question returned from the starters endpoint.
 */
internal data class StarterQuestionResponse(
    val text: String,
    val category: String? = null,
) {
    internal companion object {
        fun fromJson(json: JSONObject): StarterQuestionResponse = StarterQuestionResponse(
            text = json.optString("text", ""),
            category = json.optString("category", null),
        )
    }
}

/**
 * Geographic coordinates.
 */
internal data class Location(
    val lat: Double,
    val lng: Double,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("lat", lat)
        put("lng", lng)
    }
}

// ── JSON Array helpers ───────────────────────────────────────────────

/** Parse a [JSONArray] into a list using [transform] for each element. */
internal inline fun <T> JSONArray.mapObjects(transform: (JSONObject) -> T): List<T> {
    return (0 until length()).map { transform(getJSONObject(it)) }
}
