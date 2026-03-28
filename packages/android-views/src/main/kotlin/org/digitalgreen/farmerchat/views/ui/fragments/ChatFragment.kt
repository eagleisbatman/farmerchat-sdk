package org.digitalgreen.farmerchat.views.ui.fragments

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.LinearLayout
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.android.material.chip.Chip
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import org.digitalgreen.farmerchat.views.FarmerChat
import org.digitalgreen.farmerchat.views.R
import org.digitalgreen.farmerchat.views.databinding.FragmentChatBinding
import org.digitalgreen.farmerchat.views.ui.adapters.MessageAdapter
import org.digitalgreen.farmerchat.views.viewmodel.ChatViewModel

/**
 * Main chat fragment displaying messages, input bar, starter questions, and connectivity banner.
 *
 * Uses ViewBinding with [FragmentChatBinding]. Observes [ChatViewModel] StateFlows for
 * all state changes.
 *
 * All public methods and lifecycle callbacks are wrapped in try-catch — the SDK must
 * never crash the host app.
 */
internal class ChatFragment : Fragment() {

    private companion object {
        const val TAG = "FC.ChatFragment"
    }

    private var _binding: FragmentChatBinding? = null
    private val binding get() = _binding!!

    private val viewModel: ChatViewModel by activityViewModels()
    private lateinit var messageAdapter: MessageAdapter

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View? {
        return try {
            _binding = FragmentChatBinding.inflate(inflater, container, false)
            binding.root
        } catch (e: Exception) {
            Log.e(TAG, "onCreateView failed", e)
            null
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        try {
            setupToolbar()
            setupRecyclerView()
            setupInputBar()
            observeState()
            viewModel.loadStarters()
        } catch (e: Exception) {
            Log.e(TAG, "onViewCreated failed", e)
        }
    }

    private fun setupToolbar() {
        val config = FarmerChat.getConfig()
        binding.toolbarTitle.text = config.headerTitle

        binding.btnHistory.visibility = if (config.historyEnabled) View.VISIBLE else View.GONE
        binding.btnProfile.visibility = if (config.profileEnabled) View.VISIBLE else View.GONE

        binding.btnHistory.setOnClickListener {
            try {
                findNavController().navigate(R.id.action_chat_to_history)
            } catch (e: Exception) {
                Log.w(TAG, "Navigation to history failed", e)
            }
        }

        binding.btnProfile.setOnClickListener {
            try {
                findNavController().navigate(R.id.action_chat_to_profile)
            } catch (e: Exception) {
                Log.w(TAG, "Navigation to profile failed", e)
            }
        }
    }

    private fun setupRecyclerView() {
        messageAdapter = MessageAdapter(
            onFollowUpClick = { text ->
                try {
                    viewModel.sendFollowUp(text)
                } catch (e: Exception) {
                    Log.w(TAG, "Follow-up click failed", e)
                }
            },
            onFeedbackClick = { messageId, rating ->
                try {
                    viewModel.submitFeedback(messageId, rating)
                } catch (e: Exception) {
                    Log.w(TAG, "Feedback click failed", e)
                }
            },
        )

        binding.recyclerMessages.apply {
            layoutManager = LinearLayoutManager(requireContext()).apply {
                stackFromEnd = true
            }
            adapter = messageAdapter
        }
    }

    private fun setupInputBar() {
        binding.inputBar.btnSend?.setOnClickListener {
            try {
                val text = binding.inputBar.editMessage?.text?.toString()?.trim() ?: return@setOnClickListener
                if (text.isEmpty()) return@setOnClickListener
                viewModel.sendQuery(text)
                binding.inputBar.editMessage?.text?.clear()
            } catch (e: Exception) {
                Log.w(TAG, "Send click failed", e)
            }
        }

        binding.inputBar.editMessage?.setOnEditorActionListener { _, actionId, _ ->
            try {
                if (actionId == EditorInfo.IME_ACTION_SEND) {
                    val text = binding.inputBar.editMessage?.text?.toString()?.trim() ?: return@setOnEditorActionListener false
                    if (text.isEmpty()) return@setOnEditorActionListener false
                    viewModel.sendQuery(text)
                    binding.inputBar.editMessage?.text?.clear()
                    true
                } else {
                    false
                }
            } catch (e: Exception) {
                Log.w(TAG, "Editor action failed", e)
                false
            }
        }

        // Show/hide voice and camera buttons based on config
        val config = FarmerChat.getConfig()
        binding.inputBar.btnVoice?.visibility = if (config.voiceInputEnabled) View.VISIBLE else View.GONE
        binding.inputBar.btnCamera?.visibility = if (config.imageInputEnabled) View.VISIBLE else View.GONE
    }

    private fun observeState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                // Observe messages
                launch {
                    viewModel.messages.collect { messages ->
                        try {
                            messageAdapter.submitList(messages) {
                                // Auto-scroll to bottom on new messages
                                if (messages.isNotEmpty()) {
                                    binding.recyclerMessages.smoothScrollToPosition(messages.size - 1)
                                }
                            }
                            // Show starter questions when no messages
                            binding.starterQuestionsArea.visibility =
                                if (messages.isEmpty()) View.VISIBLE else View.GONE
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating messages", e)
                        }
                    }
                }

                // Observe chat state
                launch {
                    viewModel.chatState.collect { state ->
                        try {
                            updateChatState(state)
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating chat state", e)
                        }
                    }
                }

                // Observe connectivity
                launch {
                    viewModel.isConnected.collect { connected ->
                        try {
                            binding.connectivityBanner.visibility =
                                if (connected) View.GONE else View.VISIBLE
                            binding.inputBar.btnSend?.isEnabled = connected
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating connectivity", e)
                        }
                    }
                }

                // Observe starter questions
                launch {
                    viewModel.starterQuestions.collect { starters ->
                        try {
                            populateStarterQuestions(starters)
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating starters", e)
                        }
                    }
                }
            }
        }
    }

    private fun updateChatState(state: ChatViewModel.ChatUiState) {
        when (state) {
            is ChatViewModel.ChatUiState.Idle,
            is ChatViewModel.ChatUiState.Complete -> {
                binding.sendingIndicator.visibility = View.GONE
                binding.errorBanner.visibility = View.GONE
                binding.inputBar.btnSend?.isEnabled = true
            }
            is ChatViewModel.ChatUiState.Sending -> {
                binding.sendingIndicator.visibility = View.VISIBLE
                binding.errorBanner.visibility = View.GONE
                binding.inputBar.btnSend?.isEnabled = false
            }
            is ChatViewModel.ChatUiState.Streaming -> {
                binding.sendingIndicator.visibility = View.GONE
                binding.errorBanner.visibility = View.GONE
                binding.inputBar.btnSend?.isEnabled = false
            }
            is ChatViewModel.ChatUiState.Error -> {
                binding.sendingIndicator.visibility = View.GONE
                binding.errorBanner.visibility = View.VISIBLE
                binding.errorText.text = state.message
                binding.btnRetry.visibility = if (state.retryable) View.VISIBLE else View.GONE
                binding.btnRetry.setOnClickListener {
                    viewModel.retryLastQuery()
                }
                binding.inputBar.btnSend?.isEnabled = true
            }
        }
    }

    private fun populateStarterQuestions(
        starters: List<org.digitalgreen.farmerchat.views.network.StarterQuestionResponse>,
    ) {
        binding.starterChipsContainer.removeAllViews()
        for (starter in starters) {
            val chip = Chip(requireContext()).apply {
                text = starter.text
                isClickable = true
                isCheckable = false
                setOnClickListener {
                    try {
                        viewModel.sendQuery(starter.text, inputMethod = "starter")
                    } catch (e: Exception) {
                        Log.w(TAG, "Starter chip click failed", e)
                    }
                }
            }
            binding.starterChipsContainer.addView(chip)
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
