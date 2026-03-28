package org.digitalgreen.farmerchat.compose.screens

import android.util.Log
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.digitalgreen.farmerchat.compose.FarmerChat
import org.digitalgreen.farmerchat.compose.components.ConnectivityBanner
import org.digitalgreen.farmerchat.compose.components.InputBar
import org.digitalgreen.farmerchat.compose.components.ResponseCard
import org.digitalgreen.farmerchat.compose.network.StarterQuestionResponse
import org.digitalgreen.farmerchat.compose.viewmodel.ChatViewModel

/**
 * Main chat screen composable.
 * Displays messages, starter questions, input bar, and connectivity state.
 */
@Composable
internal fun ChatScreen(viewModel: ChatViewModel) {
    val messages by viewModel.messages.collectAsStateWithLifecycle()
    val chatState by viewModel.chatState.collectAsStateWithLifecycle()
    val isConnected by viewModel.isConnected.collectAsStateWithLifecycle()
    val starters by viewModel.starterQuestions.collectAsStateWithLifecycle()

    val listState = rememberLazyListState()

    // Auto-scroll to bottom on new messages
    LaunchedEffect(messages.size) {
        try {
            if (messages.isNotEmpty()) {
                listState.animateScrollToItem(messages.size - 1)
            }
        } catch (e: Exception) {
            Log.w("FC.ChatScreen", "Auto-scroll failed", e)
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // Top bar
        ChatTopBar(
            title = FarmerChat.getConfig().headerTitle,
            onHistoryClick = {
                try {
                    viewModel.navigateTo(ChatViewModel.Screen.History)
                } catch (e: Exception) {
                    Log.w("FC.ChatScreen", "History navigation failed", e)
                }
            },
            onProfileClick = {
                try {
                    viewModel.navigateTo(ChatViewModel.Screen.Profile)
                } catch (e: Exception) {
                    Log.w("FC.ChatScreen", "Profile navigation failed", e)
                }
            },
        )

        // Connectivity banner
        if (!isConnected) {
            ConnectivityBanner()
        }

        // Messages or starter questions
        Box(modifier = Modifier.weight(1f)) {
            if (messages.isEmpty()) {
                StarterQuestions(starters) { text ->
                    try {
                        viewModel.sendFollowUp(text)
                    } catch (e: Exception) {
                        Log.w("FC.ChatScreen", "Starter question click failed", e)
                    }
                }
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
                                isStreaming = chatState is ChatViewModel.ChatUiState.Streaming &&
                                    message.id == messages.lastOrNull()?.id,
                                onFollowUpClick = { text ->
                                    try {
                                        viewModel.sendFollowUp(text)
                                    } catch (e: Exception) {
                                        Log.w("FC.ChatScreen", "Follow-up click failed", e)
                                    }
                                },
                                onFeedback = { rating ->
                                    try {
                                        viewModel.submitFeedback(message.id, rating)
                                    } catch (e: Exception) {
                                        Log.w("FC.ChatScreen", "Feedback click failed", e)
                                    }
                                },
                            )
                        }
                    }

                    // Streaming indicator
                    if (chatState is ChatViewModel.ChatUiState.Streaming) {
                        item {
                            StreamingIndicator(onStop = {
                                try {
                                    viewModel.stopStream()
                                } catch (e: Exception) {
                                    Log.w("FC.ChatScreen", "Stop stream failed", e)
                                }
                            })
                        }
                    }

                    // Error with retry
                    if (chatState is ChatViewModel.ChatUiState.Error) {
                        item {
                            val error = chatState as ChatViewModel.ChatUiState.Error
                            ErrorBanner(
                                message = error.message,
                                retryable = error.retryable,
                                onRetry = {
                                    try {
                                        viewModel.retryLastQuery()
                                    } catch (e: Exception) {
                                        Log.w("FC.ChatScreen", "Retry failed", e)
                                    }
                                },
                            )
                        }
                    }
                }
            }
        }

        // Input bar
        InputBar(
            enabled = chatState !is ChatViewModel.ChatUiState.Streaming && isConnected,
            onSend = { text ->
                try {
                    viewModel.sendQuery(text)
                } catch (e: Exception) {
                    Log.w("FC.ChatScreen", "Send failed", e)
                }
            },
            voiceEnabled = FarmerChat.getConfig().voiceInputEnabled,
            cameraEnabled = FarmerChat.getConfig().imageInputEnabled,
        )
    }
}

// ── Helper composables ─────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChatTopBar(
    title: String,
    onHistoryClick: () -> Unit,
    onProfileClick: () -> Unit,
) {
    TopAppBar(
        title = {
            Text(
                text = title,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = MaterialTheme.colorScheme.primary,
            titleContentColor = MaterialTheme.colorScheme.onPrimary,
            actionIconContentColor = MaterialTheme.colorScheme.onPrimary,
        ),
        actions = {
            if (FarmerChat.getConfig().historyEnabled) {
                IconButton(onClick = onHistoryClick) {
                    Icon(Icons.Default.History, contentDescription = "Chat history")
                }
            }
            if (FarmerChat.getConfig().profileEnabled) {
                IconButton(onClick = onProfileClick) {
                    Icon(Icons.Default.Person, contentDescription = "Profile")
                }
            }
        },
    )
}

@Composable
private fun StarterQuestions(
    starters: List<StarterQuestionResponse>,
    onStarterClick: (String) -> Unit,
) {
    if (starters.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "Ask a question about farming to get started",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(32.dp),
            )
        }
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "Try asking about...",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(bottom = 16.dp),
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            starters.forEach { starter ->
                SuggestionChip(
                    onClick = { onStarterClick(starter.text) },
                    label = {
                        Text(
                            text = starter.text,
                            style = MaterialTheme.typography.bodyMedium,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                    },
                )
            }
        }
    }
}

@Composable
private fun UserMessageBubble(message: ChatViewModel.ChatMessage) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.End,
    ) {
        Card(
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ),
            shape = MaterialTheme.shapes.medium,
        ) {
            Text(
                text = message.text,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            )
        }
    }
}

@Composable
private fun StreamingIndicator(onStop: () -> Unit) {
    val infiniteTransition = rememberInfiniteTransition(label = "streaming")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 600),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulse",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "\u2022",
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.alpha(alpha),
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text = "Generating response\u2026",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        IconButton(onClick = onStop, modifier = Modifier.size(32.dp)) {
            Icon(
                Icons.Default.Stop,
                contentDescription = "Stop generating",
                modifier = Modifier.size(18.dp),
                tint = MaterialTheme.colorScheme.error,
            )
        }
    }
}

@Composable
private fun ErrorBanner(
    message: String,
    retryable: Boolean,
    onRetry: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer,
            contentColor = MaterialTheme.colorScheme.onErrorContainer,
        ),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.Warning,
                contentDescription = "Error",
                modifier = Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.error,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = message,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.weight(1f),
            )
            if (retryable) {
                TextButton(onClick = onRetry) {
                    Icon(
                        Icons.Default.Refresh,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.width(4.dp))
                    Text("Retry")
                }
            }
        }
    }
}
