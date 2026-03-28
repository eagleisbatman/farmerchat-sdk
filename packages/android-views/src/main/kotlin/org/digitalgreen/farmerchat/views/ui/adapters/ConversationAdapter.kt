package org.digitalgreen.farmerchat.views.ui.adapters

import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import org.digitalgreen.farmerchat.views.databinding.ItemConversationCardBinding
import org.digitalgreen.farmerchat.views.network.ConversationResponse
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * RecyclerView adapter for conversation history cards.
 *
 * Displays conversation title and last-updated date. Tapping a card loads
 * that conversation's messages into the chat view.
 *
 * All bind operations are wrapped in try-catch — the SDK must never crash the host app.
 *
 * @param onConversationClick Callback when a conversation card is tapped.
 */
internal class ConversationAdapter(
    private val onConversationClick: (ConversationResponse) -> Unit,
) : ListAdapter<ConversationResponse, ConversationAdapter.ConversationViewHolder>(ConversationDiffCallback()) {

    private companion object {
        const val TAG = "FC.ConversationAdapter"
        val DATE_FORMAT: DateTimeFormatter = DateTimeFormatter
            .ofPattern("MMM dd, yyyy", Locale.getDefault())
            .withZone(ZoneId.systemDefault())
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

        fun bind(conversation: ConversationResponse) {
            try {
                binding.textTitle.text = conversation.title.ifEmpty { "Untitled Conversation" }

                val dateText = if (conversation.updatedAt > 0) {
                    DATE_FORMAT.format(Instant.ofEpochMilli(conversation.updatedAt))
                } else if (conversation.createdAt > 0) {
                    DATE_FORMAT.format(Instant.ofEpochMilli(conversation.createdAt))
                } else {
                    ""
                }
                binding.textDate.text = dateText

                val messageCount = conversation.messages.size
                binding.textMessageCount.text = "$messageCount messages"

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

    private class ConversationDiffCallback : DiffUtil.ItemCallback<ConversationResponse>() {
        override fun areItemsTheSame(
            oldItem: ConversationResponse,
            newItem: ConversationResponse,
        ): Boolean = oldItem.id == newItem.id

        override fun areContentsTheSame(
            oldItem: ConversationResponse,
            newItem: ConversationResponse,
        ): Boolean = oldItem == newItem
    }
}
