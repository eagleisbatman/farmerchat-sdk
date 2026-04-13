package org.digitalgreen.farmerchat.compose.components

import android.util.Log
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.digitalgreen.farmerchat.compose.media.MediaAudioRecorder
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface
import org.digitalgreen.farmerchat.compose.theme.SdkGreen500
import org.digitalgreen.farmerchat.compose.theme.SdkTextMuted
import org.digitalgreen.farmerchat.compose.theme.SdkTextPrimary
import org.digitalgreen.farmerchat.compose.theme.SdkError

private enum class VoiceState { Idle, Recording, Processing, Done }

/**
 * Modal bottom sheet for voice recording.
 * Idle → Recording → Processing → Done → onAudioCaptured(base64, "AMR")
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun VoiceInputSheet(
    onDismiss: () -> Unit,
    onAudioCaptured: (base64: String, format: String) -> Unit,
) {
    val context = LocalContext.current
    val scope   = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var voiceState by remember { mutableStateOf(VoiceState.Idle) }
    val recorder = remember { MediaAudioRecorder(context) }

    DisposableEffect(Unit) {
        onDispose { recorder.cancel() }
    }

    ModalBottomSheet(
        onDismissRequest = {
            try { recorder.cancel() } catch (_: Exception) {}
            onDismiss()
        },
        sheetState = sheetState,
        containerColor = SdkDarkSurface,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Handle bar
            Box(
                Modifier
                    .width(40.dp)
                    .height(4.dp)
                    .background(SdkTextMuted.copy(alpha = 0.4f), CircleShape)
            )
            Spacer(Modifier.height(20.dp))

            // Status text
            val statusText = when (voiceState) {
                VoiceState.Idle       -> "Tap mic to start recording"
                VoiceState.Recording  -> "Recording… tap stop when done"
                VoiceState.Processing -> "Processing audio…"
                VoiceState.Done       -> "Audio captured!"
            }
            Text(statusText, color = SdkTextPrimary, fontSize = 16.sp, fontWeight = FontWeight.Medium)
            Spacer(Modifier.height(32.dp))

            // Central widget
            when (voiceState) {
                VoiceState.Idle -> {
                    // Big mic button
                    Box(
                        modifier = Modifier
                            .size(72.dp)
                            .background(SdkGreen500, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        IconButton(
                            onClick = {
                                try {
                                    if (recorder.start()) {
                                        voiceState = VoiceState.Recording
                                    }
                                } catch (e: Exception) {
                                    Log.w("FC.VoiceSheet", "start failed", e)
                                }
                            },
                            modifier = Modifier.size(72.dp),
                        ) {
                            Icon(Icons.Default.Mic, contentDescription = "Start Recording",
                                tint = Color.White, modifier = Modifier.size(36.dp))
                        }
                    }
                }

                VoiceState.Recording -> {
                    WaveformBars()
                    Spacer(Modifier.height(24.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                        // Cancel
                        Box(Modifier.size(56.dp).background(SdkError.copy(alpha = 0.15f), CircleShape),
                            contentAlignment = Alignment.Center) {
                            IconButton(onClick = {
                                try { recorder.cancel(); voiceState = VoiceState.Idle } catch (_: Exception) {}
                            }, modifier = Modifier.size(56.dp)) {
                                Icon(Icons.Default.Close, contentDescription = "Cancel",
                                    tint = SdkError, modifier = Modifier.size(28.dp))
                            }
                        }
                        // Stop
                        Box(Modifier.size(64.dp).background(SdkGreen500, CircleShape),
                            contentAlignment = Alignment.Center) {
                            IconButton(onClick = {
                                try {
                                    voiceState = VoiceState.Processing
                                    scope.launch {
                                        val base64 = withContext(Dispatchers.IO) { recorder.stop() }
                                        if (base64 != null) {
                                            voiceState = VoiceState.Done
                                            onAudioCaptured(base64, "AMR")
                                        } else {
                                            voiceState = VoiceState.Idle
                                        }
                                    }
                                } catch (e: Exception) {
                                    Log.w("FC.VoiceSheet", "stop failed", e)
                                    voiceState = VoiceState.Idle
                                }
                            }, modifier = Modifier.size(64.dp)) {
                                Icon(Icons.Default.Stop, contentDescription = "Stop",
                                    tint = Color.White, modifier = Modifier.size(32.dp))
                            }
                        }
                    }
                }

                VoiceState.Processing -> {
                    CircularProgressIndicator(color = SdkGreen500, modifier = Modifier.size(48.dp))
                }

                VoiceState.Done -> {
                    Box(Modifier.size(64.dp).background(SdkGreen500, CircleShape),
                        contentAlignment = Alignment.Center) {
                        Icon(Icons.Default.Check, contentDescription = "Done",
                            tint = Color.White, modifier = Modifier.size(32.dp))
                    }
                }
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun WaveformBars() {
    val infiniteTransition = rememberInfiniteTransition(label = "waveform")
    val bars = 7
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.height(48.dp),
    ) {
        repeat(bars) { i ->
            val phase = i * (360f / bars)
            val scale by infiniteTransition.animateFloat(
                initialValue = 0.3f, targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(600, delayMillis = (phase * 600f / 360f).toInt(),
                        easing = LinearEasing),
                    repeatMode = RepeatMode.Reverse,
                ),
                label = "bar$i",
            )
            Box(
                Modifier
                    .width(5.dp)
                    .height((48 * scale).dp)
                    .background(SdkGreen500, RoundedCornerShape(3.dp))
            )
        }
    }
}
