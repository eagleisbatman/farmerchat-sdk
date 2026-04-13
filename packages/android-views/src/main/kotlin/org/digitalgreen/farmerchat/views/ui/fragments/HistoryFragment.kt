package org.digitalgreen.farmerchat.views.ui.fragments

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import kotlinx.coroutines.launch
import org.digitalgreen.farmerchat.views.R
import org.digitalgreen.farmerchat.views.databinding.FragmentHistoryBinding
import org.digitalgreen.farmerchat.views.ui.adapters.ConversationAdapter
import org.digitalgreen.farmerchat.views.viewmodel.ChatViewModel

/**
 * History fragment displaying server-fetched conversation list.
 *
 * Uses ViewBinding with [FragmentHistoryBinding]. Shows loading, error, and empty states.
 *
 * All lifecycle methods and user interactions are wrapped in try-catch — the SDK must
 * never crash the host app.
 */
internal class HistoryFragment : Fragment() {

    private companion object {
        const val TAG = "FC.HistoryFragment"
    }

    private var _binding: FragmentHistoryBinding? = null
    private val binding get() = _binding!!

    private val viewModel: ChatViewModel by activityViewModels()
    private lateinit var conversationAdapter: ConversationAdapter

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View? {
        return try {
            _binding = FragmentHistoryBinding.inflate(inflater, container, false)
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
            observeState()
            viewModel.loadHistory()
        } catch (e: Exception) {
            Log.e(TAG, "onViewCreated failed", e)
        }
    }

    private fun setupToolbar() {
        binding.btnBack.setOnClickListener {
            try {
                findNavController().navigateUp()
            } catch (e: Exception) {
                Log.w(TAG, "Back navigation failed", e)
            }
        }
    }

    private fun setupRecyclerView() {
        conversationAdapter = ConversationAdapter { conversation ->
            try {
                viewModel.loadConversation(conversation)
                findNavController().navigateUp()
            } catch (e: Exception) {
                Log.w(TAG, "Conversation click failed", e)
            }
        }

        binding.btnRetry.setOnClickListener {
            viewModel.loadHistory()
        }

        binding.recyclerConversations.apply {
            layoutManager = LinearLayoutManager(requireContext())
            adapter = conversationAdapter
        }
    }

    private fun observeState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                // Observe conversations
                launch {
                    viewModel.conversations.collect { conversations ->
                        try {
                            conversationAdapter.submitList(conversations)
                            binding.emptyState.visibility =
                                if (conversations.isEmpty() && !viewModel.historyLoading.value) View.VISIBLE else View.GONE
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating conversations", e)
                        }
                    }
                }

                // Observe loading state
                launch {
                    viewModel.historyLoading.collect { loading ->
                        try {
                            binding.progressBar.visibility = if (loading) View.VISIBLE else View.GONE
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating loading state", e)
                        }
                    }
                }

                // Observe error state
                launch {
                    viewModel.historyError.collect { error ->
                        try {
                            if (error != null) {
                                binding.errorState.visibility = View.VISIBLE
                                binding.errorText.text = error
                                binding.btnRetry.setOnClickListener {
                                    viewModel.loadHistory()
                                }
                            } else {
                                binding.errorState.visibility = View.GONE
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating error state", e)
                        }
                    }
                }
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
