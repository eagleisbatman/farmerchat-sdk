package org.digitalgreen.farmerchat.views

import android.os.Bundle
import android.util.Log
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.navigation.fragment.NavHostFragment
import org.digitalgreen.farmerchat.views.network.SdkPreferences

/**
 * Transparent-themed Activity hosting SDK fragments via Navigation Component.
 *
 * Uses a single Activity + NavHostFragment to avoid consuming the host app's backstack.
 * On re-launch after completed onboarding, the start destination is changed to chat_fragment
 * so the user is never shown the onboarding screens again.
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

            // Set nav graph programmatically so we can override the start destination
            // when onboarding has already been completed.
            // Only on fresh start (savedInstanceState == null) — on rotation the
            // NavController restores its own state automatically.
            if (savedInstanceState == null) {
                val navHostFragment =
                    supportFragmentManager.findFragmentById(R.id.nav_host_fragment) as? NavHostFragment
                if (navHostFragment != null) {
                    val navController = navHostFragment.navController
                    val graph = navController.navInflater.inflate(R.navigation.nav_graph)
                    val config = FarmerChat.getConfig()
                    val skipOnboarding =
                        SdkPreferences.onboardingDone || config.defaultLanguage != null
                    if (skipOnboarding) {
                        graph.setStartDestination(R.id.chat_fragment)
                    }
                    navController.setGraph(graph, null)
                }
            }

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
