package org.digitalgreen.farmerchat.compose.crash

import android.util.Log

/**
 * Detects the host app's crash reporting provider at runtime via reflection
 * and forwards SDK errors through it.
 *
 * Supports Firebase Crashlytics, Sentry, and Bugsnag. Falls back gracefully
 * to no-op when no provider is present.
 *
 * All public methods are wrapped in try-catch — this class must NEVER crash the host app.
 */
internal class CrashBridge {

    private companion object {
        const val TAG = "FC.CrashBridge"
    }

    /** Detected crash provider in the host app. */
    enum class CrashProvider { FIREBASE, SENTRY, BUGSNAG, NONE }

    private var provider: CrashProvider = CrashProvider.NONE

    /**
     * Detect the crash provider available in the host app's classpath.
     * Call once during SDK initialization.
     */
    fun detect() {
        try {
            provider = when {
                classExists("com.google.firebase.crashlytics.FirebaseCrashlytics") ->
                    CrashProvider.FIREBASE
                classExists("io.sentry.Sentry") ->
                    CrashProvider.SENTRY
                classExists("com.bugsnag.android.Bugsnag") ->
                    CrashProvider.BUGSNAG
                else ->
                    CrashProvider.NONE
            }
            Log.d(TAG, "Detected crash provider: $provider")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to detect crash provider", e)
            provider = CrashProvider.NONE
        }
    }

    /** Returns the currently detected [CrashProvider]. */
    fun detectedProvider(): CrashProvider = provider

    /**
     * Report an error to the host app's crash provider.
     *
     * @param error The throwable to report.
     * @param breadcrumbs Optional context breadcrumbs attached before reporting.
     */
    fun reportError(error: Throwable, breadcrumbs: List<String> = emptyList()) {
        try {
            // Attach breadcrumbs first
            for (crumb in breadcrumbs) {
                addBreadcrumb(crumb)
            }

            when (provider) {
                CrashProvider.FIREBASE -> reportFirebase(error)
                CrashProvider.SENTRY -> reportSentry(error)
                CrashProvider.BUGSNAG -> reportBugsnag(error)
                CrashProvider.NONE -> Log.w(TAG, "SDK error (no crash provider)", error)
            }
        } catch (e: Exception) {
            // Never crash the host app — swallow and log
            Log.w(TAG, "Failed to report error to $provider", e)
        }
    }

    /**
     * Add a breadcrumb for crash context.
     *
     * @param message Descriptive breadcrumb text.
     */
    fun addBreadcrumb(message: String) {
        try {
            when (provider) {
                CrashProvider.FIREBASE -> {
                    val clazz = Class.forName("com.google.firebase.crashlytics.FirebaseCrashlytics")
                    val instance = clazz.getMethod("getInstance").invoke(null)
                    clazz.getMethod("log", String::class.java).invoke(instance, message)
                }
                CrashProvider.SENTRY -> {
                    val breadcrumbClass = Class.forName("io.sentry.Breadcrumb")
                    val breadcrumb = breadcrumbClass
                        .getMethod("info", String::class.java)
                        .invoke(null, message)
                    val sentryClass = Class.forName("io.sentry.Sentry")
                    sentryClass.getMethod("addBreadcrumb", breadcrumbClass)
                        .invoke(null, breadcrumb)
                }
                CrashProvider.BUGSNAG -> {
                    val clazz = Class.forName("com.bugsnag.android.Bugsnag")
                    clazz.getMethod("leaveBreadcrumb", String::class.java)
                        .invoke(null, message)
                }
                CrashProvider.NONE -> { /* no-op */ }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to add breadcrumb to $provider", e)
        }
    }

    /**
     * Set a custom key-value pair on crash reports for additional SDK context.
     *
     * @param key The key name.
     * @param value The value.
     */
    fun setCustomKey(key: String, value: String) {
        try {
            when (provider) {
                CrashProvider.FIREBASE -> {
                    val clazz = Class.forName("com.google.firebase.crashlytics.FirebaseCrashlytics")
                    val instance = clazz.getMethod("getInstance").invoke(null)
                    clazz.getMethod("setCustomKey", String::class.java, String::class.java)
                        .invoke(instance, key, value)
                }
                CrashProvider.SENTRY -> {
                    val sentryClass = Class.forName("io.sentry.Sentry")
                    // Sentry uses configureScope with a lambda, but we can use setTag directly
                    // via Sentry.configureScope. Simplest reflection path: setTag on HubAdapter.
                    // Alternative: Use Sentry.setTag which is a static convenience method.
                    sentryClass.getMethod("setTag", String::class.java, String::class.java)
                        .invoke(null, key, value)
                }
                CrashProvider.BUGSNAG -> {
                    val clazz = Class.forName("com.bugsnag.android.Bugsnag")
                    clazz.getMethod("addMetadata", String::class.java, String::class.java, Any::class.java)
                        .invoke(null, "farmerchat", key, value)
                }
                CrashProvider.NONE -> { /* no-op */ }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to set custom key on $provider", e)
        }
    }

    // ── Private helpers ──────────────────────────────────────────────

    private fun reportFirebase(error: Throwable) {
        val clazz = Class.forName("com.google.firebase.crashlytics.FirebaseCrashlytics")
        val instance = clazz.getMethod("getInstance").invoke(null)
        clazz.getMethod("recordException", Throwable::class.java)
            .invoke(instance, error)
    }

    private fun reportSentry(error: Throwable) {
        val clazz = Class.forName("io.sentry.Sentry")
        clazz.getMethod("captureException", Throwable::class.java)
            .invoke(null, error)
    }

    private fun reportBugsnag(error: Throwable) {
        val clazz = Class.forName("com.bugsnag.android.Bugsnag")
        clazz.getMethod("notify", Throwable::class.java)
            .invoke(null, error)
    }

    private fun classExists(name: String): Boolean = try {
        Class.forName(name)
        true
    } catch (_: ClassNotFoundException) {
        false
    }
}
