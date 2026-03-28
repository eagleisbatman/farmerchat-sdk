package org.digitalgreen.farmerchat.views

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.util.AttributeSet
import android.util.Log
import com.google.android.material.floatingactionbutton.FloatingActionButton

/**
 * Custom FloatingActionButton for launching the FarmerChat widget.
 *
 * Applies SDK branding (green background, white message icon) by default.
 * The host app can override appearance via XML attributes or programmatically.
 *
 * All click handling is wrapped in try-catch — the SDK must never crash the host app.
 */
class FarmerChatFAB @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = com.google.android.material.R.attr.floatingActionButtonStyle,
) : FloatingActionButton(context, attrs, defStyleAttr) {

    init {
        try {
            imageTintList = ColorStateList.valueOf(Color.WHITE)
            setImageResource(android.R.drawable.sym_action_chat)
            backgroundTintList = ColorStateList.valueOf(Color.parseColor("#1B6B3A"))
            elevation = 8f
            contentDescription = "Open FarmerChat"
        } catch (e: Exception) {
            Log.w("FarmerChat", "FAB init error", e)
        }
    }

    override fun performClick(): Boolean {
        return try {
            super.performClick()
        } catch (e: Exception) {
            Log.e("FarmerChat", "FAB click error", e)
            false
        }
    }
}
