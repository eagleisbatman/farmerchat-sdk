package org.digitalgreen.farmerchat.views.network

import android.content.Context
import android.content.SharedPreferences

/**
 * Lightweight SharedPreferences wrapper for SDK-level user preferences.
 *
 * Persists:
 *  - Whether the user has completed the onboarding flow.
 *  - The language code they selected, so it survives app restarts.
 *
 * Call [init] once inside [FarmerChat.initialize].
 */
internal object SdkPreferences {

    private const val PREFS_NAME          = "fc_sdk_prefs"
    private const val KEY_ONBOARDING_DONE = "fc_onboarding_done"
    private const val KEY_LANGUAGE        = "fc_selected_language"

    private var prefs: SharedPreferences? = null

    fun init(context: Context) {
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    /** True if the user has already completed the onboarding / language-selection flow. */
    var onboardingDone: Boolean
        get()      = prefs?.getBoolean(KEY_ONBOARDING_DONE, false) ?: false
        set(value) { prefs?.edit()?.putBoolean(KEY_ONBOARDING_DONE, value)?.apply() }

    /** The BCP-47 language code the user selected during onboarding. Empty string = not set. */
    var selectedLanguage: String
        get()      = prefs?.getString(KEY_LANGUAGE, "") ?: ""
        set(value) { prefs?.edit()?.putString(KEY_LANGUAGE, value)?.apply() }
}
