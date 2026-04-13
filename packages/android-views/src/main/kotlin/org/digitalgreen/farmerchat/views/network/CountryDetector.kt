package org.digitalgreen.farmerchat.views.network

import android.content.Context
import android.telephony.TelephonyManager
import java.util.Locale

/**
 * Detects the device's country code without requiring any location permission.
 *
 * Priority:
 * 1. TelephonyManager.networkCountryIso — active cell-tower network
 * 2. TelephonyManager.simCountryIso    — SIM card issuing country
 * 3. Locale.getDefault().country       — device language / region settings
 * 4. Fallback "IN"
 *
 * Used exclusively to supply the `country_code` query parameter for
 * `GET api/language/v2/country_wise_supported_languages/`.
 * No GPS / location permission is requested.
 */
internal object CountryDetector {

    fun detect(context: Context, fallback: String = "IN"): String {
        return try {
            val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

            val networkCountry = tm?.networkCountryIso
                ?.uppercase(Locale.ROOT)
                ?.takeIf { it.length == 2 }
            if (networkCountry != null) return networkCountry

            val simCountry = tm?.simCountryIso
                ?.uppercase(Locale.ROOT)
                ?.takeIf { it.length == 2 }
            if (simCountry != null) return simCountry

            val localeCountry = Locale.getDefault().country
                .uppercase(Locale.ROOT)
                .takeIf { it.length == 2 }
            if (localeCountry != null) return localeCountry

            fallback
        } catch (_: Exception) {
            fallback
        }
    }
}
