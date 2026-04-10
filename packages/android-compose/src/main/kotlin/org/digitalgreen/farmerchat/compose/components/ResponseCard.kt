package org.digitalgreen.farmerchat.compose.components

import android.util.Log
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.digitalgreen.farmerchat.compose.theme.SdkAiBubble
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface
import org.digitalgreen.farmerchat.compose.theme.SdkGreen500
import org.digitalgreen.farmerchat.compose.theme.SdkGreen800
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
) {
    val clipboardManager = LocalClipboardManager.current
    var listenState by remember { mutableStateOf("idle") } // idle | loading | playing

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

        Column(modifier = Modifier.widthIn(max = (0.88f * 1000).dp)) {
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
                // Listen button (TTS outline pill)
                if (!message.hideTtsSpeaker) {
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .border(1.dp, SdkGreen500, RoundedCornerShape(20.dp))
                            .clickable {
                                try { listenState = "loading" } catch (_: Exception) {}
                            }
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Icon(Icons.Default.VolumeUp, contentDescription = null, tint = SdkGreen500, modifier = Modifier.size(18.dp))
                        Text("Listen", color = SdkGreen500, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                    }
                }

                // Copy button 30dp bg surfaceVariant
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
