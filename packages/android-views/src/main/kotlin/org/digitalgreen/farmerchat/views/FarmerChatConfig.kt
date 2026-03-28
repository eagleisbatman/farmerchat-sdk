package org.digitalgreen.farmerchat.views

/**
 * Configuration for the FarmerChat SDK.
 * Passed to [FarmerChat.initialize] to customize behavior and appearance.
 *
 * All fields have sensible defaults. Only override what you need.
 */
data class FarmerChatConfig(

    /** Base URL for the FarmerChat API. Defaults to production. */
    val baseUrl: String = "https://api.farmerchat.digitalgreen.org",

    /** Primary brand color as ARGB Long (e.g., 0xFF1B6B3A). */
    val primaryColor: Long = 0xFF1B6B3A,

    /** Secondary/accent color as ARGB Long. Used for backgrounds and highlights. */
    val secondaryColor: Long = 0xFFF0F7F2,

    /** Header title displayed in the chat screen toolbar. */
    val headerTitle: String = "FarmerChat",

    /** Default language code (e.g., "hi", "en", "sw"). Loaded from server if null. */
    val defaultLanguage: String? = null,

    /** Enable voice input. Defaults to true. */
    val voiceInputEnabled: Boolean = true,

    /** Enable image input (camera/gallery). Defaults to true. */
    val imageInputEnabled: Boolean = true,

    /** Enable chat history screen. Defaults to true. */
    val historyEnabled: Boolean = true,

    /** Enable profile/settings screen. Defaults to true. */
    val profileEnabled: Boolean = true,

    /** Show "Powered by FarmerChat" branding. Defaults to true. */
    val showPoweredBy: Boolean = true,

    /** Maximum number of messages to keep in memory. Defaults to 50. */
    val maxMessagesInMemory: Int = 50,

    /** HTTP request timeout in milliseconds. Defaults to 15 000 ms. */
    val requestTimeoutMs: Int = 15_000,

    /** SSE stream read timeout in milliseconds. Defaults to 30 000 ms. */
    val sseTimeoutMs: Int = 30_000,

    /**
     * Number of SSE reconnect attempts before showing a connection error.
     * Defaults to 1.
     */
    val sseReconnectAttempts: Int = 1,

    /** Corner radius for cards and buttons in dp. Defaults to 12. */
    val cornerRadius: Int = 12,

    /** Font family name. "System" uses the platform default. */
    val fontFamily: String = "System",

    /** Partner identifier used for analytics segmentation and content injection. */
    val partnerId: String? = null,

    /** Maximum thumbnail dimension in dp for image previews. Defaults to 300. */
    val maxImageDimension: Int = 300,

    /** Image compression quality (0-100) applied before uploading. Defaults to 80. */
    val imageCompressionQuality: Int = 80,

    /** Maximum image upload size in bytes. Defaults to 5 MB. */
    val imageSizeLimitBytes: Long = 5_242_880L,
)
