package org.digitalgreen.farmerchat.views.ui.views

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import android.view.LayoutInflater
import android.widget.LinearLayout
import org.digitalgreen.farmerchat.views.databinding.ViewConnectivityBannerBinding

/**
 * Custom compound view showing an offline connectivity banner.
 *
 * Displays a warning icon and "No internet connection" message.
 * Visibility should be toggled by observing the ViewModel's isConnected state.
 *
 * All initialization is wrapped in try-catch — the SDK must never crash the host app.
 */
internal class ConnectivityBannerView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : LinearLayout(context, attrs, defStyleAttr) {

    private companion object {
        const val TAG = "FC.ConnBanner"
    }

    init {
        try {
            ViewConnectivityBannerBinding.inflate(LayoutInflater.from(context), this, true)
            orientation = HORIZONTAL
        } catch (e: Exception) {
            Log.e(TAG, "Failed to inflate connectivity banner", e)
        }
    }
}
