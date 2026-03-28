package org.digitalgreen.farmerchat.views

/**
 * Sealed interface representing SDK lifecycle events.
 *
 * Register a listener via [FarmerChat.setEventCallback] to receive these events.
 * Each event carries a [timestamp] (epoch millis) for ordering and analytics.
 */
sealed interface FarmerChatEvent {

    /** Emitted when the chat screen is opened. */
    data class ChatOpened(
        val sessionId: String,
        val timestamp: Long = System.currentTimeMillis(),
    ) : FarmerChatEvent

    /** Emitted when the chat screen is closed. */
    data class ChatClosed(
        val sessionId: String,
        val messageCount: Int,
        val timestamp: Long = System.currentTimeMillis(),
    ) : FarmerChatEvent

    /** Emitted when the user sends a query (text, voice, or image). */
    data class QuerySent(
        val sessionId: String,
        val queryId: String,
        val inputMethod: String,
        val timestamp: Long = System.currentTimeMillis(),
    ) : FarmerChatEvent

    /** Emitted when an AI response is received. */
    data class ResponseReceived(
        val sessionId: String,
        val responseId: String,
        val latencyMs: Long,
        val timestamp: Long = System.currentTimeMillis(),
    ) : FarmerChatEvent

    /** Emitted when an SDK error occurs. */
    data class Error(
        val code: String,
        val message: String,
        val fatal: Boolean = false,
        val timestamp: Long = System.currentTimeMillis(),
    ) : FarmerChatEvent

    /** Emitted when network connectivity changes. */
    data class ConnectivityChanged(
        val isConnected: Boolean,
        val timestamp: Long = System.currentTimeMillis(),
    ) : FarmerChatEvent
}
