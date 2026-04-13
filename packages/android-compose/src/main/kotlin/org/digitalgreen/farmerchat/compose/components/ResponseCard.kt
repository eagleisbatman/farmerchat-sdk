package org.digitalgreen.farmerchat.compose.components

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.util.Log
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import org.digitalgreen.farmerchat.compose.theme.SdkAiBubble
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface
import org.digitalgreen.farmerchat.compose.theme.SdkGreen500
import org.digitalgreen.farmerchat.compose.theme.SdkTextSecondary
import org.digitalgreen.farmerchat.compose.viewmodel.ChatViewModel

/**
 * AI response card — dark theme.
 *
 * AI bubble: bg #1A2318, corners 18dp (top-left = 4dp), padding h16 v12.
 * Max width 88%. Avatar circle 36dp with 🌱.
 * Follow-ups: horizontal scroll row below bubble.
 * Actions: Listen (TTS outline pill) + Copy icon.
 */
@Composable
internal fun ResponseCard(
    message: ChatViewModel.ChatMessage,
    onFollowUpClick: (String) -> Unit = {},
    onSynthesise: (suspend (String, String) -> String?)? = null,
) {
    val clipboardManager = LocalClipboardManager.current
    val scope = rememberCoroutineScope()

    // idle | loading | playing
    var listenState by remember { mutableStateOf("idle") }
    var audioUrl by remember { mutableStateOf<String?>(null) }
    val mediaPlayer = remember { MediaPlayer() }

    DisposableEffect(Unit) {
        onDispose {
            try { mediaPlayer.stop(); mediaPlayer.release() } catch (_: Exception) {}
        }
    }

    // Play audio once the URL is available
    LaunchedEffect(audioUrl) {
        val url = audioUrl ?: return@LaunchedEffect
        try {
            mediaPlayer.reset()
            mediaPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )
            mediaPlayer.setDataSource(url)
            mediaPlayer.setOnPreparedListener { it.start(); listenState = "playing" }
            mediaPlayer.setOnCompletionListener { listenState = "idle"; audioUrl = null }
            mediaPlayer.setOnErrorListener { _, _, _ -> listenState = "idle"; audioUrl = null; true }
            mediaPlayer.prepareAsync()
        } catch (e: Exception) {
            Log.w("FC.ResponseCard", "MediaPlayer error", e)
            listenState = "idle"; audioUrl = null
        }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.Start,
        verticalAlignment = Alignment.Top,
    ) {
        // Avatar circle 36dp
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(SdkGreen500, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text("🌱", fontSize = 16.sp)
        }

        Spacer(Modifier.width(10.dp))

        Column(modifier = Modifier.fillMaxWidth(0.88f)) {
            // AI bubble
            Box(
                modifier = Modifier
                    .clip(
                        RoundedCornerShape(
                            topStart = 4.dp,
                            topEnd   = 18.dp,
                            bottomStart = 18.dp,
                            bottomEnd   = 18.dp,
                        )
                    )
                    .background(SdkAiBubble)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            ) {
                MarkdownContent(text = message.text)
            }

            // ── Follow-up chips (horizontal scroll row) ──────────────────────
            if (message.followUps.isNotEmpty()) {
                // "Related questions" label
                Text(
                    text = "Related questions",
                    color = SdkTextSecondary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.padding(top = 12.dp, start = 4.dp, bottom = 8.dp),
                )

                Row(
                    modifier = Modifier
                        .horizontalScroll(rememberScrollState())
                        .fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    message.followUps.forEach { followUp ->
                        FollowUpChip(
                            text    = followUp.question,
                            onClick = {
                                try { onFollowUpClick(followUp.question) } catch (_: Exception) {}
                            },
                        )
                    }
                }
            }

            // ── Actions bar (Listen + Copy) ──────────────────────────────────
            Row(
                modifier = Modifier.padding(top = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Listen button — only shown when serverMessageId is set and hideTtsSpeaker=false
                if (!message.hideTtsSpeaker && !message.serverMessageId.isNullOrEmpty()) {
                    ListenButton(
                        state = listenState,
                        onClick = {
                            when (listenState) {
                                "idle" -> {
                                    val msgId = message.serverMessageId ?: return@ListenButton
                                    listenState = "loading"
                                    scope.launch {
                                        try {
                                            val url = onSynthesise?.invoke(msgId, message.text)
                                            if (url != null) {
                                                audioUrl = url
                                            } else {
                                                listenState = "idle"
                                            }
                                        } catch (_: Exception) {
                                            listenState = "idle"
                                        }
                                    }
                                }
                                "playing" -> {
                                    try { mediaPlayer.stop() } catch (_: Exception) {}
                                    listenState = "idle"; audioUrl = null
                                }
                            }
                        },
                    )
                }

                // Copy button — 30dp circle
                Box(
                    modifier = Modifier
                        .size(30.dp)
                        .clip(CircleShape)
                        .background(SdkDarkSurface)
                        .clickable {
                            try { clipboardManager.setText(AnnotatedString(message.text)) } catch (_: Exception) {}
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Default.ContentCopy, contentDescription = "Copy", tint = SdkTextSecondary, modifier = Modifier.size(14.dp))
                }
            }
        }
    }
}

// ── Listen button — 3 states: idle / loading / playing ─────────────────────────

@Composable
private fun ListenButton(state: String, onClick: () -> Unit) {
    val bgAlpha = when (state) { "playing" -> 0.10f; "loading" -> 0.08f; else -> 0.07f }
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(SdkGreen500.copy(alpha = bgAlpha))
            .then(if (state != "loading") Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        when (state) {
            "loading" -> {
                CircularProgressIndicator(
                    modifier = Modifier.size(13.dp),
                    strokeWidth = 1.5.dp,
                    color = SdkGreen500,
                )
                Text("Loading…", color = SdkGreen500, fontSize = 11.sp)
            }
            "playing" -> {
                SoundBarsAnimation()
                Spacer(Modifier.width(2.dp))
                Text("Stop", color = SdkGreen500, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                Icon(Icons.Default.Stop, contentDescription = null, tint = SdkGreen500, modifier = Modifier.size(13.dp))
            }
            else -> {
                Icon(Icons.Default.VolumeUp, contentDescription = null, tint = SdkGreen500, modifier = Modifier.size(14.dp))
                Text("Listen", color = SdkGreen500, fontSize = 11.sp, fontWeight = FontWeight.Medium)
            }
        }
    }
}

@Composable
private fun SoundBarsAnimation() {
    val transition = rememberInfiniteTransition(label = "soundbars")
    val delays = listOf(0, 80, 160, 240)
    Row(
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        delays.forEach { delayMs ->
            val scaleY by transition.animateFloat(
                initialValue = 0.3f,
                targetValue  = 1f,
                animationSpec = infiniteRepeatable(
                    animation  = tween(350, delayMillis = delayMs, easing = LinearEasing),
                    repeatMode = RepeatMode.Reverse,
                ),
                label = "bar$delayMs",
            )
            Box(
                modifier = Modifier
                    .width(2.5.dp)
                    .height(12.dp)
                    .graphicsLayer(scaleY = scaleY)
                    .background(SdkGreen500, RoundedCornerShape(2.dp)),
            )
        }
    }
}

// ── Follow-up chip ─────────────────────────────────────────────────────────────

@Composable
private fun FollowUpChip(text: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50.dp))
            .background(SdkAiBubble)
            .border(1.dp, SdkGreen500.copy(alpha = 0.25f), RoundedCornerShape(50.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text  = text,
            color = Color.White,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Icon(
            Icons.AutoMirrored.Filled.Send,
            contentDescription = null,
            tint  = SdkGreen500,
            modifier = Modifier.size(16.dp),
        )
    }
}
