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

        /** ISO date parsers — ordered from most to least specific. */
        val DATE_PARSERS: List<SimpleDateFormat> = listOf(
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
        ).map { pattern ->
            SimpleDateFormat(pattern, Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        }

        fun formatDate(dateStr: String?): String {
            if (dateStr.isNullOrEmpty()) return ""
            var date: Date? = null
            for (parser in DATE_PARSERS) {
                date = try { parser.parse(dateStr) } catch (_: Exception) { null }
                if (date != null) break
            }
            if (date == null) return dateStr
            val now = System.currentTimeMillis()
            val diffMs = now - date.time
            val diffSec = diffMs / 1000
            return when {
                diffSec < 60       -> "Just now"
                diffSec < 3600     -> "${diffSec / 60}m ago"
                diffSec < 86400    -> "${diffSec / 3600}h ago"
                diffSec < 172800   -> "Yesterday"
                else               -> SimpleDateFormat("MMM d", Locale.getDefault()).format(date)
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
                    ?.takeIf { it.isNotEmpty() } ?: "Conversation"

                binding.textDate.text = formatDate(conversation.createdOn)
                binding.textMessageCount.text = conversation.grouping?.takeIf { it.isNotEmpty() } ?: ""

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
