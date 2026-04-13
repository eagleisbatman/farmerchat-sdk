package org.digitalgreen.farmerchat.compose

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.digitalgreen.farmerchat.compose.screens.ChatScreen
import org.digitalgreen.farmerchat.compose.screens.HistoryScreen
import org.digitalgreen.farmerchat.compose.screens.OnboardingScreen
import org.digitalgreen.farmerchat.compose.screens.ProfileScreen
import org.digitalgreen.farmerchat.compose.theme.FarmerChatTheme
import org.digitalgreen.farmerchat.compose.viewmodel.ChatViewModel

/**
 * Internal Activity that hosts the full FarmerChat Compose UI.
 * Launched via [FarmerChat.presentChat].
 *
 * Navigation is driven by [ChatViewModel.currentScreen]: Onboarding → Chat,
 * and Chat ↔ History / Profile. The back press handler navigates sub-screens
 * back to Chat and finishes the activity from the Chat screen.
 */
internal class FarmerChatActivity : ComponentActivity() {

    private val viewModel: ChatViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        try {
            onBackPressedDispatcher.addCallback(
                this,
                object : OnBackPressedCallback(true) {
                    override fun handleOnBackPressed() {
                        try {
                            when (viewModel.currentScreen.value) {
                                is ChatViewModel.Screen.History,
                                is ChatViewModel.Screen.Profile,
                                -> viewModel.navigateTo(ChatViewModel.Screen.Chat)
                                else -> finish()
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Back press handling failed", e)
                            finish()
                        }
                    }
                },
            )

            setContent {
                FarmerChatTheme {
                    val screen by viewModel.currentScreen.collectAsStateWithLifecycle()
                    when (screen) {
                        is ChatViewModel.Screen.Onboarding -> OnboardingScreen(viewModel)
                        is ChatViewModel.Screen.Chat -> ChatScreen(viewModel)
                        is ChatViewModel.Screen.History -> HistoryScreen(viewModel)
                        is ChatViewModel.Screen.Profile -> ProfileScreen(viewModel)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch chat UI", e)
            finish()
        }
    }

    internal companion object {
        private const val TAG = "FarmerChatActivity"

        fun createIntent(context: Context): Intent =
            Intent(context, FarmerChatActivity::class.java)
    }
}
