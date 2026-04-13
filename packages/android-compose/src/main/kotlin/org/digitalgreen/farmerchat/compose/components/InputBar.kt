package org.digitalgreen.farmerchat.compose.components

import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface2
import org.digitalgreen.farmerchat.compose.theme.SdkGreen500
import org.digitalgreen.farmerchat.compose.theme.SdkTextPrimary
import org.digitalgreen.farmerchat.compose.theme.SdkTextMuted

/**
 * Chat input bar — dark theme.
 *
 * Surface: #1A2318. Text field pill: #243020.
 * Send button: 48dp circle #4CAF50 with elevation 4dp.
 * Camera: 40dp circle #243020. Mic: 48dp circle #4CAF50.
 * Padding: start 14, end 12, top 10, bottom 12.
 */
@Composable
internal fun InputBar(
    enabled: Boolean = true,
    onSend: (String) -> Unit,
    onSendWithImage: ((String, String) -> Unit)? = null,
    selectedImageBase64: String? = null,
    onMicClick: (() -> Unit)? = null,
    onCameraClick: (() -> Unit)? = null,
    voiceEnabled: Boolean = true,
    cameraEnabled: Boolean = true,
) {
    var text by remember { mutableStateOf("") }
    val hasText = text.isNotBlank()
    val hasImage = selectedImageBase64 != null

    Surface(
        color = SdkDarkSurface,
        modifier = Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.navigationBars),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 14.dp, end = 12.dp, top = 10.dp, bottom = 12.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            // Text field (weight = 1f, radius 24dp pill, bg #243020)
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(24.dp))
                    .background(SdkDarkSurface2)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) {
                if (text.isEmpty()) {
                    Text(
                        text  = "Ask about your crops…",
                        color = SdkTextMuted,
                        fontSize = 14.sp,
                    )
                }
                BasicTextField(
                    value    = text,
                    onValueChange = { if (it.length <= 2000) text = it },
                    modifier = Modifier.fillMaxWidth(),
                    enabled  = enabled,
                    maxLines = 4,
                    textStyle = TextStyle(color = SdkTextPrimary, fontSize = 14.sp),
                    cursorBrush = SolidColor(SdkGreen500),
                )
            }

            Spacer(Modifier.width(10.dp))

            // Primary button group
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (hasText || hasImage) {
                    // Send button — 48dp circle #4CAF50
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .shadow(4.dp, CircleShape)
                            .background(if (enabled) SdkGreen500 else SdkGreen500.copy(alpha = 0.4f), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        IconButton(
                            onClick = {
                                try {
                                    if (enabled) {
                                        val img = selectedImageBase64
                                        if (img != null) {
                                            onSendWithImage?.invoke(text.trim(), img)
                                        } else {
                                            onSend(text.trim())
                                        }
                                        text = ""
                                    }
                                } catch (e: Exception) {
                                    Log.w("FC.InputBar", "Send failed", e)
                                }
                            },
                            modifier = Modifier.size(48.dp),
                            enabled = enabled,
                        ) {
                            Icon(
                                Icons.AutoMirrored.Filled.Send,
                                contentDescription = "Send",
                                tint = Color.White,
                                modifier = Modifier.size(22.dp),
                            )
                        }
                    }
                } else {
                    // Camera button — 40dp circle, bg #243020
                    if (cameraEnabled) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .background(SdkDarkSurface2, CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            IconButton(
                                onClick = {
                                    try { onCameraClick?.invoke() } catch (e: Exception) {
                                        Log.w("FC.InputBar", "Camera click failed", e)
                                    }
                                },
                                modifier = Modifier.size(40.dp),
                                enabled = enabled,
                            ) {
                                Icon(
                                    Icons.Default.CameraAlt,
                                    contentDescription = "Camera",
                                    tint = SdkTextMuted,
                                    modifier = Modifier.size(20.dp),
                                )
                            }
                        }
                        Spacer(Modifier.width(6.dp))
                    }

                    // Mic button — 48dp circle, bg #4CAF50
                    if (voiceEnabled) {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .background(if (enabled) SdkGreen500 else SdkGreen500.copy(alpha = 0.4f), CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            IconButton(
                                onClick = {
                                    try { onMicClick?.invoke() } catch (e: Exception) {
                                        Log.w("FC.InputBar", "Mic click failed", e)
                                    }
                                },
                                modifier = Modifier.size(48.dp),
                                enabled = enabled,
                            ) {
                                Icon(
                                    Icons.Default.Mic,
                                    contentDescription = "Voice",
                                    tint = Color.White,
                                    modifier = Modifier.size(24.dp),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
