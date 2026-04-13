package org.digitalgreen.farmerchat.compose.screens

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.ui.graphics.Brush
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.filled.Warning
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import org.digitalgreen.farmerchat.compose.FarmerChat
import org.digitalgreen.farmerchat.compose.components.ConnectivityBanner
import org.digitalgreen.farmerchat.compose.components.ImageSourcePickerSheet
import org.digitalgreen.farmerchat.compose.components.InputBar
import org.digitalgreen.farmerchat.compose.components.ResponseCard
import org.digitalgreen.farmerchat.compose.components.VoiceInputSheet
import org.digitalgreen.farmerchat.compose.media.uriToBase64Jpeg
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import org.digitalgreen.farmerchat.compose.theme.SdkAiBubble
import org.digitalgreen.farmerchat.compose.theme.SdkDarkBg
import org.digitalgreen.farmerchat.compose.theme.SdkError
import org.digitalgreen.farmerchat.compose.theme.SdkErrorContainer
import org.digitalgreen.farmerchat.compose.theme.SdkGreen500
import org.digitalgreen.farmerchat.compose.theme.SdkGreenAccent
import org.digitalgreen.farmerchat.compose.theme.SdkTextMuted
import org.digitalgreen.farmerchat.compose.theme.SdkTextPrimary
import org.digitalgreen.farmerchat.compose.theme.SdkTextSecondary
import org.digitalgreen.farmerchat.compose.theme.SdkUserBubble
import org.digitalgreen.farmerchat.compose.viewmodel.ChatViewModel

/**
 * Main chat screen — dark forest-green theme.
 *
 * Layout: Top bar → Connectivity banner → Chat body → Input bar.
 * The chat body switches between an empty-state prompt and the message list.
 */
@Composable
internal fun ChatScreen(viewModel: ChatViewModel) {
    val messages by viewModel.messages.collectAsStateWithLifecycle()
    val chatState by viewModel.chatState.collectAsStateWithLifecycle()
    val isConnected by viewModel.isConnected.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val context = LocalContext.current

    // Voice / image sheet visibility
    var showVoiceSheet by remember { mutableStateOf(false) }
    var showImageSheet by remember { mutableStateOf(false) }
    var selectedImageBase64 by remember { mutableStateOf<String?>(null) }
    var selectedImageUri by remember { mutableStateOf<Uri?>(null) }

    // Temp URI for camera photo
    var cameraPhotoUri by remember { mutableStateOf<Uri?>(null) }

    // Permission launchers
    val micPermLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) showVoiceSheet = true }

    val camPermLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) showImageSheet = true }

    // Gallery picker
    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        uri?.let {
            selectedImageUri = it
            CoroutineScope(Dispatchers.IO).launch {
                val b64 = uriToBase64Jpeg(context, it.toString())
                if (b64 != null) selectedImageBase64 = b64
            }
        }
    }

    // Camera capture
    val takePictureLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success) {
            cameraPhotoUri?.let { uri ->
                selectedImageUri = uri
                CoroutineScope(Dispatchers.IO).launch {
                    val b64 = uriToBase64Jpeg(context, uri.toString())
                    if (b64 != null) selectedImageBase64 = b64
                }
            }
        }
    }

    fun launchCamera() {
        try {
            val dir = File(context.cacheDir, "farmerchat/images").also { it.mkdirs() }
            val file = File(dir, "photo_${System.currentTimeMillis()}.jpg")
            val uri = FileProvider.getUriForFile(
                context, "${context.packageName}.fc_compose_provider", file)
            cameraPhotoUri = uri
            takePictureLauncher.launch(uri)
        } catch (e: Exception) {
            Log.w("FC.ChatScreen", "Camera launch failed", e)
        }
    }

    fun onMicClick() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            == PackageManager.PERMISSION_GRANTED) {
            showVoiceSheet = true
        } else {
            micPermLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    fun onCameraClick() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED) {
            showImageSheet = true
        } else {
            camPermLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    LaunchedEffect(messages.size) {
        try {
            if (messages.isNotEmpty()) listState.animateScrollToItem(messages.size - 1)
        } catch (e: Exception) {
            Log.w("FC.ChatScreen", "Auto-scroll failed", e)
        }
    }

    Box(
        modifier = Modifier.fillMaxSize().background(
            Brush.verticalGradient(
                colors = listOf(Color(0xFF152014), SdkDarkBg),
            ),
        ),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {

            ChatTopBar(
                title           = FarmerChat.getConfig().headerTitle,
                onHistoryClick  = {
                    try { viewModel.navigateTo(ChatViewModel.Screen.History) } catch (_: Exception) {}
                },
                onLanguageClick = {
                    try { viewModel.navigateTo(ChatViewModel.Screen.Profile) } catch (_: Exception) {}
                },
            )

            if (!isConnected) ConnectivityBanner()

            // Weather widget — shown only when host app provides weatherTemp in config
            val cfg = FarmerChat.getConfig()
            if (!cfg.weatherTemp.isNullOrEmpty()) {
                WeatherWidget(
                    weatherTemp     = cfg.weatherTemp!!,
                    weatherLocation = cfg.weatherLocation,
                    cropName        = cfg.cropName,
                    onTap           = {
                        try {
                            val q = "Tell me about farming advice for this weather"
                            viewModel.sendWeatherQuery(q)
                        } catch (_: Exception) {}
                    },
                )
            }

            Box(modifier = Modifier.weight(1f)) {
                if (messages.isEmpty() && selectedImageBase64 == null) {
                    EmptyState()
                } else {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = 8.dp),
                    ) {
                        items(messages, key = { it.id }) { message ->
                            if (message.role == "user") {
                                UserMessageBubble(message)
                            } else {
                                ResponseCard(
                                    message = message,
                                    onFollowUpClick = { text ->
                                        try { viewModel.sendFollowUp(text) } catch (_: Exception) {}
                                    },
                                    onSynthesise = { msgId, text ->
                                        try { viewModel.synthesiseAudio(msgId, text) }
                                        catch (_: Exception) { null }
                                    },
                                )
                            }
                        }

                        if (chatState is ChatViewModel.ChatUiState.Sending) {
                            item { TypingIndicator() }
                        }

                        if (chatState is ChatViewModel.ChatUiState.Error) {
                            item {
                                val err = chatState as ChatViewModel.ChatUiState.Error
                                ErrorBanner(
                                    message  = err.message,
                                    retryable = err.retryable,
                                    onRetry  = {
                                        try { viewModel.retryLastQuery() } catch (_: Exception) {}
                                    },
                                )
                            }
                        }
                    }
                }
            }

            InputBar(
                enabled              = chatState !is ChatViewModel.ChatUiState.Sending && isConnected,
                onSend               = { text ->
                    try { viewModel.sendQuery(text) } catch (_: Exception) {}
                },
                onSendWithImage      = { text, b64 ->
                    try {
                        // Extract GPS coordinates from EXIF (no location permission needed)
                        val gps = selectedImageUri?.let {
                            org.digitalgreen.farmerchat.compose.media.ImageUtils.getLocationFromExif(context, it)
                        }
                        viewModel.sendQueryWithImage(text, b64, gps?.first, gps?.second)
                        selectedImageBase64 = null
                        selectedImageUri = null
                    } catch (_: Exception) {}
                },
                selectedImageBase64  = selectedImageBase64,
                onMicClick           = { onMicClick() },
                onCameraClick        = { onCameraClick() },
                voiceEnabled         = FarmerChat.getConfig().voiceInputEnabled,
                cameraEnabled        = FarmerChat.getConfig().imageInputEnabled,
            )
        }
    }

    // Voice input sheet
    if (showVoiceSheet) {
        VoiceInputSheet(
            onDismiss = { showVoiceSheet = false },
            onAudioCaptured = { base64, format ->
                showVoiceSheet = false
                try { viewModel.transcribeAndSendAudio(base64, format) } catch (_: Exception) {}
            },
        )
    }

    // Image source picker sheet
    if (showImageSheet) {
        ImageSourcePickerSheet(
            onDismiss = { showImageSheet = false },
            onCamera  = { launchCamera() },
            onGallery = {
                galleryLauncher.launch(
                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                )
            },
        )
    }
}

// ── Top bar ────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChatTopBar(
    title: String,
    onHistoryClick: () -> Unit,
    onLanguageClick: () -> Unit,
) {
    Surface(
        color = Color(0xFF1A2318),
        modifier = Modifier.fillMaxWidth(),
        shadowElevation = 4.dp,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
                // Logo circle 40dp
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .background(SdkGreen500, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("🌱", fontSize = 20.sp)
                }

                Spacer(Modifier.width(10.dp))

                // Title + online dot + subtitle
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text  = title.ifBlank { "FarmerChat AI" },
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Spacer(Modifier.width(6.dp))
                        Box(
                            modifier = Modifier
                                .size(7.dp)
                                .background(SdkGreenAccent, CircleShape),
                        )
                    }
                    Text(
                        text  = "Smart Farming Assistant",
                        color = SdkTextSecondary,
                        fontSize = 11.sp,
                    )
                }

                // Language / profile icon
                if (FarmerChat.getConfig().profileEnabled) {
                    IconButton(onClick = onLanguageClick) {
                        Icon(
                            Icons.Default.Translate,
                            contentDescription = "Language",
                            tint = SdkTextSecondary,
                            modifier = Modifier.size(22.dp),
                        )
                    }
                }

                // History icon
                if (FarmerChat.getConfig().historyEnabled) {
                    IconButton(onClick = onHistoryClick) {
                        Icon(
                            Icons.Default.History,
                            contentDescription = "History",
                            tint = SdkTextSecondary,
                            modifier = Modifier.size(22.dp),
                        )
                    }
                }
        }
    }
}

// ── Empty state ────────────────────────────────────────────────────────────────

@Composable
private fun EmptyState() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(32.dp)) {
            Text("🌾", fontSize = 48.sp)
            Spacer(Modifier.height(16.dp))
            Text(
                text = "Ask a question about farming to get started",
                color = SdkTextSecondary,
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center,
            )
        }
    }
}

// ── User bubble ────────────────────────────────────────────────────────────────

@Composable
private fun UserMessageBubble(message: ChatViewModel.ChatMessage) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.End,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(0.72f)
                .clip(RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp, bottomStart = 18.dp, bottomEnd = 4.dp))
                .background(SdkUserBubble)
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Text(
                text  = message.text,
                color = Color.White,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

// ── Typing / loading indicator ─────────────────────────────────────────────────

@Composable
private fun TypingIndicator() {
    val infiniteTransition = rememberInfiniteTransition(label = "typing")
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Avatar
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(SdkGreen500, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text("🌱", fontSize = 16.sp)
        }
        Spacer(Modifier.width(10.dp))

        // Bouncing dots
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 18.dp, bottomStart = 18.dp, bottomEnd = 18.dp))
                .background(SdkAiBubble)
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                listOf(0, 120, 240).forEach { delayMs ->
                    val offsetY by infiniteTransition.animateFloat(
                        initialValue = 0f,
                        targetValue  = -8f,
                        animationSpec = infiniteRepeatable(
                            animation  = tween(400, delayMillis = delayMs, easing = LinearEasing),
                            repeatMode = RepeatMode.Reverse,
                        ),
                        label = "dot$delayMs",
                    )
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .offset(y = offsetY.dp)
                            .background(SdkGreen500, CircleShape),
                    )
                }
            }
        }
    }
}

// ── Error banner ───────────────────────────────────────────────────────────────

@Composable
private fun ErrorBanner(message: String, retryable: Boolean, onRetry: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(SdkError.copy(alpha = 0.12f))
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Default.Warning,
            contentDescription = "Error",
            modifier = Modifier.size(18.dp),
            tint = SdkError,
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text  = message,
            color = SdkError,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f),
        )
        if (retryable) {
            TextButton(onClick = onRetry) {
                Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(16.dp), tint = SdkError)
                Spacer(Modifier.width(4.dp))
                Text("Retry", color = SdkError)
            }
        }
    }
}

// ── Weather Widget ─────────────────────────────────────────────────────────────

/**
 * Weather card shown at the top of the chat when the host app provides weather data
 * via [FarmerChatConfig.weatherTemp]. Tapping sends a query with weather_cta_triggered = true.
 */
@Composable
private fun WeatherWidget(
    weatherTemp: String,
    weatherLocation: String?,
    cropName: String?,
    onTap: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xFF172213))
            .clickable(onClick = onTap)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text       = weatherTemp,
                color      = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize   = 14.sp,
            )
            if (!weatherLocation.isNullOrEmpty()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text     = "📍  $weatherLocation",
                    color    = Color(0xFF8FA88C),
                    fontSize = 12.sp,
                )
            }
        }
        if (!cropName.isNullOrEmpty()) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(Color(0xFF4CAF50).copy(alpha = 0.22f))
                    .padding(horizontal = 10.dp, vertical = 5.dp),
            ) {
                Text(
                    text       = "🌾  $cropName",
                    color      = Color(0xFF4CAF50),
                    fontSize   = 12.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
    }
}
