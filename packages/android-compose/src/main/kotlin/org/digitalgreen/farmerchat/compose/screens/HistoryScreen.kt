package org.digitalgreen.farmerchat.compose.screens

import android.util.Log
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
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.digitalgreen.farmerchat.compose.network.ConversationListItem
import org.digitalgreen.farmerchat.compose.theme.HistoryBackground
import org.digitalgreen.farmerchat.compose.theme.HistoryCardBg
import org.digitalgreen.farmerchat.compose.theme.HistoryGroupLabel
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface2
import org.digitalgreen.farmerchat.compose.theme.SdkGreen500
import org.digitalgreen.farmerchat.compose.theme.SdkTextMuted
import org.digitalgreen.farmerchat.compose.theme.SdkTextPrimary
import org.digitalgreen.farmerchat.compose.theme.SdkTextSecondary
import org.digitalgreen.farmerchat.compose.viewmodel.ChatViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Chat history screen — dark forest theme.
 *
 * Displays server-fetched conversations grouped by date.
 * Tapping a conversation loads it into the chat screen.
 */
@Composable
internal fun HistoryScreen(viewModel: ChatViewModel) {
    val conversations by viewModel.conversationList.collectAsStateWithLifecycle()
    val isLoading by viewModel.historyLoading.collectAsStateWithLifecycle()
    var searchQuery by remember { mutableStateOf("") }

    LaunchedEffect(Unit) {
        try { viewModel.loadConversationList() } catch (e: Exception) {
            Log.w("FC.History", "Load failed", e)
        }
    }

    val filtered = if (searchQuery.isBlank()) conversations
    else conversations.filter { it.conversationTitle?.contains(searchQuery, ignoreCase = true) == true }

    Box(modifier = Modifier.fillMaxSize().background(HistoryBackground)) {
        Column(modifier = Modifier.fillMaxSize()) {

            // ── Top bar ──────────────────────────────────────────────────────
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF1A2318))
                    .padding(start = 4.dp, end = 12.dp, top = 8.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = {
                    try { viewModel.navigateTo(ChatViewModel.Screen.Chat) } catch (_: Exception) {}
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Chat History",
                        color = Color.White,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = "Your farming conversations",
                        color = SdkTextSecondary,
                        fontSize = 12.sp,
                    )
                }
                // New conversation button
                Box(
                    modifier = Modifier
                        .size(38.dp)
                        .clip(CircleShape)
                        .background(SdkGreen500)
                        .clickable {
                            try {
                                viewModel.startNewConversation()
                                viewModel.navigateTo(ChatViewModel.Screen.Chat)
                            } catch (_: Exception) {}
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Default.Add, contentDescription = "New chat", tint = Color.White, modifier = Modifier.size(22.dp))
                }
            }

            // ── Search bar ──────────────────────────────────────────────────
            TextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = {
                    Text("Search conversations...", color = SdkTextMuted, fontSize = 14.sp)
                },
                leadingIcon = {
                    Icon(Icons.Default.Search, contentDescription = null, tint = SdkTextMuted, modifier = Modifier.size(20.dp))
                },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor   = SdkDarkSurface2,
                    unfocusedContainerColor = SdkDarkSurface2,
                    focusedTextColor        = SdkTextPrimary,
                    unfocusedTextColor      = SdkTextPrimary,
                    focusedIndicatorColor   = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    cursorColor             = SdkGreen500,
                ),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            )

            // ── Content ──────────────────────────────────────────────────────
            when {
                isLoading -> HistoryShimmer()
                filtered.isEmpty() -> EmptyHistoryState()
                else -> {
                    val grouped = filtered.groupBy { it.grouping ?: "Older" }

                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 16.dp),
                    ) {
                        grouped.forEach { (group, items) ->
                            item(key = "header_$group") {
                                Text(
                                    text = group.uppercase(),
                                    color = HistoryGroupLabel,
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    letterSpacing = 1.5.sp,
                                    modifier = Modifier.padding(start = 20.dp, end = 16.dp, top = 12.dp, bottom = 4.dp),
                                )
                            }
                            items(items, key = { it.conversationId }) { item ->
                                ConversationCard(
                                    item    = item,
                                    onClick = {
                                        try { viewModel.loadConversation(item) } catch (_: Exception) {}
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// ── ConversationCard ──────────────────────────────────────────────────────────

@Composable
private fun ConversationCard(item: ConversationListItem, onClick: () -> Unit) {
    val (emoji, iconColor) = topicIconAndColor(item.conversationTitle, item.messageType)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(HistoryCardBg)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Icon circle 44dp
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(iconColor.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(emoji, fontSize = 20.sp)
        }

        Spacer(Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text  = item.conversationTitle?.takeIf { it.isNotBlank() } ?: "Conversation",
                color = SdkTextPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(3.dp))
            Text(
                text  = formatDate(item.createdOn),
                color = SdkTextMuted,
                fontSize = 11.sp,
            )
        }

        // Chevron
        Text("›", color = HistoryGroupLabel, fontSize = 20.sp)
    }
}

// ── Empty state ────────────────────────────────────────────────────────────────

@Composable
private fun EmptyHistoryState() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(32.dp)) {
            Box(
                modifier = Modifier
                    .size(90.dp)
                    .clip(CircleShape)
                    .background(SdkGreen500.copy(alpha = 0.10f)),
                contentAlignment = Alignment.Center,
            ) {
                Text("💬", fontSize = 40.sp)
            }
            Spacer(Modifier.height(16.dp))
            Text(
                text  = "No conversations yet",
                color = SdkTextPrimary,
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text  = "Your past conversations will appear here",
                color = SdkTextSecondary,
                fontSize = 14.sp,
                textAlign = TextAlign.Center,
            )
        }
    }
}

// ── History shimmer ────────────────────────────────────────────────────────────

@Composable
private fun HistoryShimmer() {
    val transition = rememberInfiniteTransition(label = "historyShimmer")
    val alpha by transition.animateFloat(
        initialValue = 0.08f,
        targetValue  = 0.22f,
        animationSpec = infiniteRepeatable(
            animation  = tween(900, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "shimmerAlpha",
    )
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 8.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Section header placeholder
        item {
            Box(
                modifier = Modifier
                    .padding(start = 20.dp, top = 12.dp)
                    .width(60.dp)
                    .height(10.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.White.copy(alpha = alpha)),
            )
        }
        // 8 shimmer cards
        items(8) { idx ->
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .height(72.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color.White.copy(alpha = alpha * (0.9f + idx * 0.012f))),
            )
        }
    }
}

// ── Date formatter ─────────────────────────────────────────────────────────────

private fun formatDate(dateStr: String?): String {
    if (dateStr.isNullOrBlank()) return ""
    return try {
        // Normalize to "yyyy-MM-dd HH:mm:ss" regardless of source format:
        //   • Replace T separator → space
        //   • Strip timezone suffix (Z, +05:30, etc.)
        //   • Trim sub-second precision (microseconds, milliseconds)
        val normalized = dateStr
            .replace('T', ' ')
            .substringBefore('Z')
            .substringBefore('+')
            .trim()
            .let { s -> if (s.length > 19) s.take(19) else s }

        val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).apply {
            isLenient = false
            timeZone  = TimeZone.getTimeZone("UTC")
        }

        val date: Date = try { sdf.parse(normalized) } catch (_: Exception) { null }
            ?: return dateStr

        val diffMs = System.currentTimeMillis() - date.time
        when {
            diffMs < 0L            -> SimpleDateFormat("MMM d", Locale.getDefault()).format(date)
            diffMs < 60_000L       -> "Just now"
            diffMs < 3_600_000L    -> "${diffMs / 60_000}m ago"
            diffMs < 86_400_000L   -> "${diffMs / 3_600_000}h ago"
            diffMs < 172_800_000L  -> "Yesterday"
            diffMs < 604_800_000L  -> "${diffMs / 86_400_000}d ago"
            else -> SimpleDateFormat("MMM d", Locale.getDefault()).format(date)
        }
    } catch (_: Exception) {
        dateStr
    }
}

// ── Topic icon / color mapping ─────────────────────────────────────────────────

private fun topicIconAndColor(title: String?, messageType: String?): Pair<String, Color> {
    val t = title?.lowercase() ?: ""
    val mt = messageType?.lowercase() ?: ""
    return when {
        mt == "image"                        -> "📸" to Color(0xFF6A1B9A)
        mt == "audio"                        -> "🎤" to Color(0xFF00838F)
        "tomato" in t || "vegetable" in t    -> "🍅" to Color(0xFFE53935)
        "weather" in t || "rain" in t
            || "monsoon" in t                -> "🌧️" to Color(0xFF1565C0)
        "soil" in t || "npk" in t           -> "🌱" to Color(0xFF558B2F)
        "irrigation" in t || "water" in t   -> "💧" to Color(0xFF0288D1)
        "fertilizer" in t || "nutrient" in t-> "🌻" to Color(0xFFF9A825)
        "pest" in t || "insect" in t        -> "🐛" to Color(0xFF6D4C41)
        "wheat" in t || "rice" in t
            || "crop" in t                  -> "🌾" to Color(0xFF8D6E63)
        "disease" in t || "virus" in t      -> "⚠️" to Color(0xFFE65100)
        else                                -> "💬" to Color(0xFF2E7D32)
    }
}
