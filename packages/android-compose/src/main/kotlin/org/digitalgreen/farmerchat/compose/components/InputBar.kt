package org.digitalgreen.farmerchat.compose.components

import android.util.Log
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * Chat input bar with text, voice, and camera inputs.
 *
 * Displays a text field with an adaptive trailing button: voice (mic) when the
 * field is empty, send (arrow) when text is present. An optional camera button
 * appears to the left.
 */
@Composable
internal fun InputBar(
    enabled: Boolean = true,
    onSend: (String) -> Unit,
    onImageSelected: ((String) -> Unit)? = null,
    voiceEnabled: Boolean = true,
    cameraEnabled: Boolean = true,
) {
    var text by remember { mutableStateOf("") }

    Surface(tonalElevation = 2.dp) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Camera button (if enabled)
            if (cameraEnabled) {
                IconButton(
                    onClick = {
                        try {
                            // TODO: launch image picker
                        } catch (e: Exception) {
                            Log.w("FC.InputBar", "Camera button failed", e)
                        }
                    },
                ) {
                    Icon(
                        Icons.Default.CameraAlt,
                        contentDescription = "Attach image",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // Text field
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                modifier = Modifier.weight(1f),
                placeholder = {
                    Text(
                        "Ask about farming\u2026",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                },
                shape = RoundedCornerShape(24.dp),
                singleLine = false,
                maxLines = 4,
                enabled = enabled,
            )

            // Voice or Send button
            if (text.isBlank() && voiceEnabled) {
                IconButton(
                    onClick = {
                        try {
                            // TODO: voice input
                        } catch (e: Exception) {
                            Log.w("FC.InputBar", "Voice button failed", e)
                        }
                    },
                ) {
                    Icon(
                        Icons.Default.Mic,
                        contentDescription = "Voice input",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                IconButton(
                    onClick = {
                        try {
                            if (text.isNotBlank()) {
                                onSend(text.trim())
                                text = ""
                            }
                        } catch (e: Exception) {
                            Log.w("FC.InputBar", "Send button failed", e)
                        }
                    },
                    enabled = enabled && text.isNotBlank(),
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send",
                        tint = if (enabled && text.isNotBlank()) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                }
            }
        }
    }
}
