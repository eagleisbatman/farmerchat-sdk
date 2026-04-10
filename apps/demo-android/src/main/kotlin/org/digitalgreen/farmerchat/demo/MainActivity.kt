package org.digitalgreen.farmerchat.demo

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import org.digitalgreen.farmerchat.demo.ui.theme.FarmerChatDemoTheme

class MainActivity : ComponentActivity() {

    companion object {
        private const val TAG = "FarmerChatDemo"
        // API key sourced from BuildConfig (set via gradle.properties or env var FC_API_KEY)
        private val DEMO_API_KEY = BuildConfig.FC_API_KEY
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        initializeSdks()

        setContent {
            FarmerChatDemoTheme {
                DemoApp()
            }
        }
    }

    /**
     * Initialize both SDK variants. Each is wrapped in its own try-catch
     * so a failure in one does not prevent the other from starting.
     */
    private fun initializeSdks() {
        // Compose SDK
        try {
            org.digitalgreen.farmerchat.compose.FarmerChat.initialize(
                context = applicationContext,
                apiKey = DEMO_API_KEY,
            )
            Log.d(TAG, "Compose SDK initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Compose SDK initialization failed", e)
        }

        // Views SDK
        try {
            org.digitalgreen.farmerchat.views.FarmerChat.initialize(
                context = applicationContext,
                apiKey = DEMO_API_KEY,
            )
            Log.d(TAG, "Views SDK initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Views SDK initialization failed", e)
        }
    }

    override fun onDestroy() {
        try {
            org.digitalgreen.farmerchat.compose.FarmerChat.destroy()
        } catch (e: Exception) {
            Log.w(TAG, "Compose SDK destroy failed", e)
        }
        try {
            org.digitalgreen.farmerchat.views.FarmerChat.destroy()
        } catch (e: Exception) {
            Log.w(TAG, "Views SDK destroy failed", e)
        }
        super.onDestroy()
    }
}

// ---------------------------------------------------------------------------
// Root composable
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DemoApp() {
    var selectedTab by rememberSaveable { mutableIntStateOf(0) }

    Scaffold(
        topBar = {
            LargeTopAppBar(
                title = {
                    Text(stringResource(R.string.demo_title))
                },
                colors = TopAppBarDefaults.largeTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    titleContentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                ),
            )
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.Dashboard,
                            contentDescription = null,
                        )
                    },
                    label = { Text(stringResource(R.string.tab_compose)) },
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.Widgets,
                            contentDescription = null,
                        )
                    },
                    label = { Text(stringResource(R.string.tab_views)) },
                )
            }
        },
    ) { innerPadding ->
        Box(modifier = Modifier.padding(innerPadding)) {
            AnimatedVisibility(
                visible = selectedTab == 0,
                enter = fadeIn(),
                exit = fadeOut(),
            ) {
                ComposeTab()
            }
            AnimatedVisibility(
                visible = selectedTab == 1,
                enter = fadeIn(),
                exit = fadeOut(),
            ) {
                ViewsTab()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Compose SDK tab
// ---------------------------------------------------------------------------

@Composable
private fun ComposeTab() {
    val context = LocalContext.current

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(
                imageVector = Icons.Default.Dashboard,
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = stringResource(R.string.tab_compose),
                style = MaterialTheme.typography.headlineSmall,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.compose_description),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(24.dp))
            SdkStatusCard(
                label = "Compose SDK",
                initialized = org.digitalgreen.farmerchat.compose.FarmerChat.isInitialized(),
            )
        }

        // Compose SDK FAB
        org.digitalgreen.farmerchat.compose.FarmerChatFAB(
            modifier = Modifier.align(Alignment.BottomEnd),
            onClick = {
                org.digitalgreen.farmerchat.compose.FarmerChat.presentChat(context)
            },
        )
    }
}

// ---------------------------------------------------------------------------
// Views SDK tab
// ---------------------------------------------------------------------------

@Composable
private fun ViewsTab() {
    val context = LocalContext.current

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(
                imageVector = Icons.Default.Widgets,
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = stringResource(R.string.tab_views),
                style = MaterialTheme.typography.headlineSmall,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.views_description),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(24.dp))
            SdkStatusCard(
                label = "Views SDK",
                initialized = org.digitalgreen.farmerchat.views.FarmerChat.isInitialized(),
            )
        }

        // Views SDK FAB — embedded via AndroidView interop
        AndroidView(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp),
            factory = { ctx ->
                org.digitalgreen.farmerchat.views.FarmerChatFAB(ctx).apply {
                    // Wrap in a FrameLayout to give proper layout params
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                    )
                    setOnClickListener {
                        try {
                            val intent = Intent(ctx, org.digitalgreen.farmerchat.views.FarmerChatActivity::class.java)
                            ctx.startActivity(intent)
                        } catch (e: Exception) {
                            Log.e("FarmerChatDemo", "Failed to launch Views chat", e)
                        }
                    }
                }
            },
        )
    }
}

// ---------------------------------------------------------------------------
// Shared components
// ---------------------------------------------------------------------------

@Composable
private fun SdkStatusCard(label: String, initialized: Boolean) {
    val status = if (initialized) "Initialized" else "Not initialized"
    val statusColor = if (initialized) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.error
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant,
        ),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = label,
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = status,
                style = MaterialTheme.typography.bodyLarge,
                color = statusColor,
            )
        }
    }
}
