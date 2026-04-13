package org.digitalgreen.farmerchat.compose

/**
 * Configuration for the FarmerChat SDK.
 * Passed to [FarmerChat.initialize] to customise behaviour and appearance.
 */
data class FarmerChatConfig(

    /** Base URL for the FarmerChat API. */
    val baseUrl: String = "https://farmerchat.farmstack.co/mobile-app-dev",

    /**
     * SDK API key issued by Digital Green.
     * Format: `fc_live_<16+ alphanumeric>` (production) or `fc_test_<16+ alphanumeric>` (sandbox).
     * Sent on every request as the `X-SDK-Key` header.
     */
    val sdkApiKey: String = "",

    /**
     * Optional multi-tenant content provider identifier.
     * Sent in [newConversation] requests when non-null.
     */
    val contentProviderId: String? = null,

    // ── UI / behaviour ────────────────────────────────────────────────────

    /** Primary brand color as ARGB Long (e.g., 0xFF1B6B3A). */
    val primaryColor: Long = 0xFF1B6B3A,

    /** Secondary/accent color as ARGB Long. */
    val secondaryColor: Long = 0xFFF0F7F2,

    /** Header title displayed in the chat screen toolbar. */
    val headerTitle: String = "FarmerChat",

    /** Default language code (e.g., "hi", "en", "sw"). */
    val defaultLanguage: String? = null,

    /** Enable voice input. */
    val voiceInputEnabled: Boolean = true,

    /** Enable image input (camera / gallery). */
    val imageInputEnabled: Boolean = true,

    /** Enable chat history screen. */
    val historyEnabled: Boolean = true,

    /** Enable profile / settings screen. */
    val profileEnabled: Boolean = true,

    /** Show "Powered by FarmerChat" branding. */
    val showPoweredBy: Boolean = true,

    /** Maximum number of messages to keep in memory. */
    val maxMessagesInMemory: Int = 50,

    // ── Network ───────────────────────────────────────────────────────────

    /** HTTP connect timeout and read timeout for fast endpoints (auth, metadata) in milliseconds. */
    val requestTimeoutMs: Int = 15_000,

    /**
     * Read timeout in milliseconds for AI inference endpoints:
     * sendTextPrompt, imageAnalysis, synthesiseAudio, transcribeAudio.
     * LLM responses can take 20–45 s, so this should be well above requestTimeoutMs.
     */
    val aiReadTimeoutMs: Int = 60_000,

    /** Corner radius for cards and buttons in dp. */
    val cornerRadius: Int = 12,

    /** Maximum thumbnail dimension in dp for image previews. */
    val maxImageDimension: Int = 300,

    /** Image compression quality (0–100) applied before uploading. */
    val imageCompressionQuality: Int = 80,

    /** Maximum image upload size in bytes (default 5 MB). */
    val imageSizeLimitBytes: Long = 5_242_880L,

    // ── Location / Region ─────────────────────────────────────────────────

    /**
     * ISO 3166-1 alpha-2 country code to use for language selection API.
     * If blank, CountryDetector uses SIM / network / locale as fallback.
     */
    val countryCode: String = "",

    /** State/province code for more localised language lists (optional). */
    val stateCode: String? = null,

    // ── Weather Widget ────────────────────────────────────────────────────

    /**
     * Primary weather text shown in the weather card (e.g., "28°C ☀️").
     * If null the weather widget is hidden entirely.
     */
    val weatherTemp: String? = null,

    /** Location label shown below the temperature (e.g., "Coorg, Karnataka"). */
    val weatherLocation: String? = null,

    /** Crop name shown as a green chip on the weather card (e.g., "Rice"). */
    val cropName: String? = null,
)
