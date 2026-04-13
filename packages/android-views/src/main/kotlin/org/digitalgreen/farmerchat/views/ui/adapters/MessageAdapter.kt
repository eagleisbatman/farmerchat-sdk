package org.digitalgreen.farmerchat.views.ui.adapters

import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.chip.Chip
import org.digitalgreen.farmerchat.views.databinding.ItemMessageAssistantBinding
import org.digitalgreen.farmerchat.views.databinding.ItemMessageUserBinding
import org.digitalgreen.farmerchat.views.viewmodel.ChatViewModel

/**
 * RecyclerView adapter for chat messages with two view types:
 * - [UserMessageViewHolder]: Right-aligned user message bubble
 * - [AssistantMessageViewHolder]: Left-aligned assistant message with avatar, markdown,
 *   follow-up chips, and feedback buttons
 *
 * Uses [ListAdapter] with [DiffUtil] for efficient updates during SSE streaming.
 *
 * All bind operations are wrapped in try-catch — the SDK must never crash the host app.
 */
internal class MessageAdapter(
    private val onFollowUpClick: (String) -> Unit,
    private val onFeedbackClick: (messageId: String, rating: String) -> Unit,
) : ListAdapter<ChatViewModel.ChatMessage, RecyclerView.ViewHolder>(MessageDiffCallback()) {

    private companion object {
        const val TAG = "FC.MessageAdapter"
        const val VIEW_TYPE_USER = 0
        const val VIEW_TYPE_ASSISTANT = 1
    }

    override fun getItemViewType(position: Int): Int {
        return try {
            val message = getItem(position)
            if (message.role == "user") VIEW_TYPE_USER else VIEW_TYPE_ASSISTANT
        } catch (e: Exception) {
            Log.w(TAG, "getItemViewType failed", e)
            VIEW_TYPE_ASSISTANT
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val inflater = LayoutInflater.from(parent.context)
        return when (viewType) {
            VIEW_TYPE_USER -> {
                val binding = ItemMessageUserBinding.inflate(inflater, parent, false)
                UserMessageViewHolder(binding)
            }
            else -> {
                val binding = ItemMessageAssistantBinding.inflate(inflater, parent, false)
                AssistantMessageViewHolder(binding)
            }
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        try {
            val message = getItem(position)
            when (holder) {
                is UserMessageViewHolder -> holder.bind(message)
                is AssistantMessageViewHolder -> holder.bind(message)
            }
        } catch (e: Exception) {
            Log.w(TAG, "onBindViewHolder failed at position $position", e)
        }
    }

    // ── User Message ViewHolder ──────────────────────────────────────

    internal inner class UserMessageViewHolder(
        private val binding: ItemMessageUserBinding,
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(message: ChatViewModel.ChatMessage) {
            try {
                binding.textMessage.text = message.text

                // Show image thumbnail if present
                if (message.imageData != null) {
                    binding.imagePreview.visibility = View.VISIBLE
                    // Decode base64 image if needed — simplified for now
                } else {
                    binding.imagePreview.visibility = View.GONE
                }
            } catch (e: Exception) {
                Log.w(TAG, "UserMessageViewHolder.bind failed", e)
            }
        }
    }

    // ── Assistant Message ViewHolder ─────────────────────────────────

    internal inner class AssistantMessageViewHolder(
        private val binding: ItemMessageAssistantBinding,
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(message: ChatViewModel.ChatMessage) {
            try {
                binding.markdownText.setMarkdownText(message.text)

                // Follow-up chips
                binding.followUpChips.removeAllViews()
                if (message.followUps.isNotEmpty()) {
                    binding.followUpChips.visibility = View.VISIBLE
                    for (followUp in message.followUps) {
                        val questionText = followUp.question ?: continue
                        val chip = Chip(binding.root.context).apply {
                            text = questionText
                            isClickable = true
                            isCheckable = false
                            setOnClickListener {
                                try {
                                    onFollowUpClick(questionText)
                                } catch (e: Exception) {
                                    Log.w(TAG, "Follow-up chip click failed", e)
                                }
                            }
                        }
                        binding.followUpChips.addView(chip)
                    }
                } else {
                    binding.followUpChips.visibility = View.GONE
                }

                // Feedback buttons
                binding.btnThumbUp.setOnClickListener {
                    try {
                        onFeedbackClick(message.id, "up")
                    } catch (e: Exception) {
                        Log.w(TAG, "Thumb up click failed", e)
                    }
                }
                binding.btnThumbDown.setOnClickListener {
                    try {
                        onFeedbackClick(message.id, "down")
                    } catch (e: Exception) {
                        Log.w(TAG, "Thumb down click failed", e)
                    }
                }

                // Update feedback button states
                when (message.feedbackRating) {
                    "up" -> {
                        binding.btnThumbUp.isSelected = true
                        binding.btnThumbDown.isSelected = false
                    }
                    "down" -> {
                        binding.btnThumbUp.isSelected = false
                        binding.btnThumbDown.isSelected = true
                    }
                    else -> {
                        binding.btnThumbUp.isSelected = false
                        binding.btnThumbDown.isSelected = false
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "AssistantMessageViewHolder.bind failed", e)
            }
        }
    }

    // ── DiffUtil ─────────────────────────────────────────────────────

    private class MessageDiffCallback : DiffUtil.ItemCallback<ChatViewModel.ChatMessage>() {
        override fun areItemsTheSame(
            oldItem: ChatViewModel.ChatMessage,
            newItem: ChatViewModel.ChatMessage,
        ): Boolean = oldItem.id == newItem.id

        override fun areContentsTheSame(
            oldItem: ChatViewModel.ChatMessage,
            newItem: ChatViewModel.ChatMessage,
        ): Boolean = oldItem == newItem
    }
}
