package org.digitalgreen.farmerchat.views

/**
 * Configuration for the FarmerChat SDK.
 * Passed to [FarmerChat.initialize] to customize behavior and appearance.
 *
 * All fields have sensible defaults. Only override what you need.
 */
data class FarmerChatConfig(

    /** Base URL for the FarmerChat API. Defaults to development instance. */
    val baseUrl: String = "https://farmerchat.farmstack.co/mobile-app-dev",

    /** Partner/content provider identifier for multi-tenant setups. */
    val contentProviderId: String? = null,

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

    /** HTTP connect timeout and read timeout for fast endpoints (auth, metadata) in milliseconds. Defaults to 15 000 ms. */
    val requestTimeoutMs: Int = 15_000,

    /**
     * Read timeout in milliseconds for AI inference endpoints:
     * sendTextPrompt, imageAnalysis, synthesiseAudio, transcribeAudio.
     * LLM responses can take 20–45 s, so this should be well above requestTimeoutMs.
     */
    val aiReadTimeoutMs: Int = 60_000,

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

    // ── Location / Region ─────────────────────────────────────────────────

    /**
     * ISO 3166-1 alpha-2 country code used for the language selection API.
     * If blank, CountryDetector uses SIM / network / locale as fallback.
     */
    val countryCode: String = "",

    /** State/province code for more localised language lists (optional). */
    val stateCode: String? = null,

    // ── Weather Widget ────────────────────────────────────────────────────

    /**
     * Primary weather text shown in the weather card (e.g. "28°C ☀️").
     * If null the weather widget is hidden entirely.
     */
    val weatherTemp: String? = null,

    /** Location label shown below the temperature (e.g. "Coorg, Karnataka"). */
    val weatherLocation: String? = null,

    /** Crop name shown as a green chip on the weather card (e.g. "Rice"). */
    val cropName: String? = null,
)
