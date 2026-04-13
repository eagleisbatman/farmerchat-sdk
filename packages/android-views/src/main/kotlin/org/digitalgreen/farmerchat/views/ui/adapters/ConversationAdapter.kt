package org.digitalgreen.farmerchat.views.ui.adapters

import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import org.digitalgreen.farmerchat.views.databinding.ItemConversationCardBinding
import org.digitalgreen.farmerchat.views.network.ConversationListItem
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * RecyclerView adapter for conversation history cards.
 *
 * Displays conversation title and relative creation date.
 * Tapping a card loads that conversation.
 *
 * All bind operations are wrapped in try-catch — the SDK must never crash the host app.
 */
internal class ConversationAdapter(
    private val onConversationClick: (ConversationListItem) -> Unit,
) : ListAdapter<ConversationListItem, ConversationAdapter.ConversationViewHolder>(ConversationDiffCallback()) {

    private companion object {
        const val TAG = "FC.ConversationAdapter"

        fun formatDate(dateStr: String?): String {
            if (dateStr.isNullOrBlank()) return ""
            return try {
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
                    diffMs < 0L           -> SimpleDateFormat("MMM d", Locale.getDefault()).format(date)
                    diffMs < 60_000L      -> "Just now"
                    diffMs < 3_600_000L   -> "${diffMs / 60_000}m ago"
                    diffMs < 86_400_000L  -> "${diffMs / 3_600_000}h ago"
                    diffMs < 172_800_000L -> "Yesterday"
                    diffMs < 604_800_000L -> "${diffMs / 86_400_000}d ago"
                    else -> SimpleDateFormat("MMM d", Locale.getDefault()).format(date)
                }
            } catch (_: Exception) {
                dateStr
            }
        }

        fun topicEmoji(title: String?): String {
            val t = title?.lowercase() ?: ""
            return when {
                "tomato" in t || "vegetable" in t -> "🍅"
                "weather" in t || "rain" in t     -> "🌧️"
                "soil" in t || "npk" in t         -> "🌱"
                "irrigation" in t || "water" in t -> "💧"
                "fertilizer" in t || "nutrient" in t -> "🌻"
                "pest" in t || "insect" in t      -> "🐛"
                "wheat" in t || "rice" in t || "crop" in t -> "🌾"
                "disease" in t || "virus" in t    -> "⚠️"
                "image" in t                      -> "📸"
                "audio" in t                      -> "🎤"
                else                              -> "💬"
            }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ConversationViewHolder {
        val binding = ItemConversationCardBinding.inflate(
            LayoutInflater.from(parent.context), parent, false,
        )
        return ConversationViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ConversationViewHolder, position: Int) {
        try {
            holder.bind(getItem(position))
        } catch (e: Exception) {
            Log.w(TAG, "onBindViewHolder failed at position $position", e)
        }
    }

    inner class ConversationViewHolder(
        private val binding: ItemConversationCardBinding,
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(conversation: ConversationListItem) {
            try {
                binding.textTitle.text = conversation.conversationTitle
                    ?.takeIf { it.isNotBlank() } ?: "Conversation"
                binding.textDate.text = formatDate(conversation.createdOn)
                binding.textMessageCount.text = ""
                binding.textIconEmoji.text = topicEmoji(conversation.conversationTitle)

                binding.root.setOnClickListener {
                    try {
                        onConversationClick(conversation)
                    } catch (e: Exception) {
                        Log.w(TAG, "Conversation card click failed", e)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "ConversationViewHolder.bind failed", e)
            }
        }
    }

    private class ConversationDiffCallback : DiffUtil.ItemCallback<ConversationListItem>() {
        override fun areItemsTheSame(
            oldItem: ConversationListItem,
            newItem: ConversationListItem,
        ): Boolean = oldItem.conversationId == newItem.conversationId

        override fun areContentsTheSame(
            oldItem: ConversationListItem,
            newItem: ConversationListItem,
        ): Boolean = oldItem == newItem
    }
}
