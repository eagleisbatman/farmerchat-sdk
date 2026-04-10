package org.digitalgreen.farmerchat.compose.network

import android.annotation.SuppressLint
import android.content.Context
import android.os.Build
import android.provider.Settings
import org.json.JSONObject
import java.net.URLEncoder
import java.util.UUID

/**
 * Builds the URL-encoded JSON string required for the `Device-Info` request header.
 *
 * Format (JSON, then URL-encoded):
 * ```json
 * {
 *   "android_id":    "<ANDROID_ID>",
 *   "app_version":   "<versionName>",
 *   "manufacturer":  "<Build.MANUFACTURER>",
 *   "model":         "<Build.MODEL>",
 *   "sdk_level":     "<Build.VERSION.SDK_INT>",
 *   "package_name":  "<packageName>"
 * }
 * ```
 */
internal object DeviceInfoProvider {

    @SuppressLint("HardwareIds")
    fun getStableDeviceId(context: Context): String {
        val androidId = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID,
        )
        return if (androidId.isNullOrBlank() || androidId == "9774d56d682e549c") {
            // Emulator / unusable ID — fall back to a random UUID seeded from Build info
            UUID.nameUUIDFromBytes(
                "${Build.BOARD}${Build.BRAND}${Build.DEVICE}".toByteArray()
            ).toString()
        } else {
            androidId
        }
    }

    @SuppressLint("HardwareIds")
    fun buildHeader(context: Context): String {
        val versionName = try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "0.0.0"
        } catch (_: Exception) {
            "0.0.0"
        }

        val json = JSONObject().apply {
            put("android_id", getStableDeviceId(context))
            put("app_version", versionName)
            put("manufacturer", Build.MANUFACTURER)
            put("model", Build.MODEL)
            put("sdk_level", Build.VERSION.SDK_INT.toString())
            put("package_name", context.packageName)
        }

        return URLEncoder.encode(json.toString(), "UTF-8")
    }
}
