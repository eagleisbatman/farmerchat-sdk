package org.digitalgreen.farmerchat.compose.components

import android.util.Log
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.ThumbDown
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import org.digitalgreen.farmerchat.compose.viewmodel.ChatViewModel

/**
 * AI response card with markdown rendering and action bar.
 *
 * Displays the assistant avatar, rendered markdown content, optional follow-up
 * suggestion chips, and a feedback action row (thumbs up/down + share).
 */
@Composable
internal fun ResponseCard(
    message: ChatViewModel.ChatMessage,
    isStreaming: Boolean = false,
    onFollowUpClick: (String) -> Unit = {},
    onFeedback: (String) -> Unit = {},
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp),
    ) {
        // Avatar + name row
        Row(verticalAlignment = Alignment.Top) {
            // Small green circle avatar with "FC"
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .background(MaterialTheme.colorScheme.primary, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "FC",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onPrimary,
                )
            }

            Spacer(Modifier.width(8.dp))

            Column(modifier = Modifier.weight(1f)) {
                // Markdown rendered content
                MarkdownContent(text = message.text)

                // Blinking cursor if streaming
                if (isStreaming) {
                    BlinkingCursor()
                }
            }
        }

        // Follow-up chips (only when not streaming)
        if (!isStreaming && message.followUps.isNotEmpty()) {
            FlowRow(
                modifier = Modifier.padding(start = 36.dp, top = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                message.followUps.forEach { followUp ->
                    SuggestionChip(
                        onClick = {
                            try {
                                onFollowUpClick(followUp)
                            } catch (e: Exception) {
                                Log.w("FC.ResponseCard", "Follow-up click failed", e)
                            }
                        },
                        label = {
                            Text(
                                followUp,
                                style = MaterialTheme.typography.bodySmall,
                            )
                        },
                    )
                }
            }
        }

        // Action bar (only when not streaming)
        if (!isStreaming) {
            Row(
                modifier = Modifier.padding(start = 36.dp, top = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                // Thumbs up
                IconButton(
                    onClick = {
                        try {
                            onFeedback("positive")
                        } catch (e: Exception) {
                            Log.w("FC.ResponseCard", "Positive feedback failed", e)
                        }
                    },
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        Icons.Default.ThumbUp,
                        contentDescription = "Helpful",
                        modifier = Modifier.size(16.dp),
                        tint = if (message.feedbackRating == "positive") {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                }

                // Thumbs down
                IconButton(
                    onClick = {
                        try {
                            onFeedback("negative")
                        } catch (e: Exception) {
                            Log.w("FC.ResponseCard", "Negative feedback failed", e)
                        }
                    },
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        Icons.Default.ThumbDown,
                        contentDescription = "Not helpful",
                        modifier = Modifier.size(16.dp),
                        tint = if (message.feedbackRating == "negative") {
                            MaterialTheme.colorScheme.error
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                }

                // Share button
                IconButton(
                    onClick = {
                        try {
                            // TODO: share message text
                        } catch (e: Exception) {
                            Log.w("FC.ResponseCard", "Share failed", e)
                        }
                    },
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        Icons.Default.Share,
                        contentDescription = "Share",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

/**
 * A small blinking rectangle to indicate the stream is still producing tokens.
 */
@Composable
private fun BlinkingCursor() {
    val infiniteTransition = rememberInfiniteTransition(label = "cursor")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 500),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "cursorAlpha",
    )

    Box(
        modifier = Modifier
            .padding(top = 2.dp)
            .size(width = 8.dp, height = 16.dp)
            .alpha(alpha)
            .background(
                color = MaterialTheme.colorScheme.primary,
                shape = RoundedCornerShape(2.dp),
            ),
    )
}
