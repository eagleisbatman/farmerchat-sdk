package org.digitalgreen.farmerchat.views

import android.os.Bundle
import android.util.Log
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity

/**
 * Transparent-themed Activity hosting SDK fragments via Navigation Component.
 *
 * Uses a single Activity + NavHostFragment to avoid consuming the host app's backstack.
 * All lifecycle methods are wrapped in try-catch — the SDK must never crash the host app.
 */
class FarmerChatActivity : AppCompatActivity() {

    private companion object {
        const val TAG = "FC.Activity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            enableEdgeToEdge()
            super.onCreate(savedInstanceState)
            setContentView(R.layout.activity_farmerchat)
            // NavHostFragment is declared in activity_farmerchat.xml with nav_graph
            // Navigation handles fragment transactions automatically

            // Emit ChatOpened event
            FarmerChat.eventCallback?.invoke(
                FarmerChatEvent.ChatOpened(sessionId = FarmerChat.getSessionId()),
            )
        } catch (e: Exception) {
            Log.e(TAG, "onCreate failed", e)
            finish()
        }
    }

    override fun onDestroy() {
        try {
            // Emit ChatClosed event
            FarmerChat.eventCallback?.invoke(
                FarmerChatEvent.ChatClosed(
                    sessionId = FarmerChat.getSessionId(),
                    messageCount = 0, // ViewModel may already be cleared
                ),
            )
        } catch (e: Exception) {
            Log.w(TAG, "Error emitting ChatClosed event", e)
        }
        super.onDestroy()
    }
}
