package org.digitalgreen.farmerchat.views.ui.fragments

import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
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
import org.digitalgreen.farmerchat.views.network.ConversationListItem
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

    private var allConversations: List<ConversationListItem> = emptyList()
    private var searchQuery: String = ""

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
            applyWindowInsets()
            setupToolbar()
            setupSearch()
            setupRecyclerView()
            observeState()
            viewModel.loadHistory()
        } catch (e: Exception) {
            Log.e(TAG, "onViewCreated failed", e)
        }
    }

    private fun applyWindowInsets() {
        try {
            ViewCompat.setOnApplyWindowInsetsListener(binding.root) { _, insets ->
                val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
                binding.toolbar.updatePadding(top = bars.top)
                binding.recyclerConversations.updatePadding(bottom = bars.bottom)
                WindowInsetsCompat.CONSUMED
            }
        } catch (e: Exception) {
            Log.w(TAG, "applyWindowInsets failed", e)
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
        binding.btnNewConversation.setOnClickListener {
            try {
                viewModel.startNewConversation()
                findNavController().navigateUp()
            } catch (e: Exception) {
                Log.w(TAG, "New conversation click failed", e)
            }
        }
    }

    private fun setupSearch() {
        binding.editSearch.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                try {
                    searchQuery = s?.toString() ?: ""
                    applyFilter()
                } catch (e: Exception) {
                    Log.w(TAG, "Search filter failed", e)
                }
            }
        })
    }

    private fun applyFilter() {
        val filtered = if (searchQuery.isBlank()) allConversations
        else allConversations.filter {
            it.conversationTitle?.contains(searchQuery, ignoreCase = true) == true
        }
        conversationAdapter.submitList(filtered)
        updateEmptyState(filtered.isEmpty())
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

    private fun updateEmptyState(isEmpty: Boolean) {
        val loading = viewModel.historyLoading.value
        binding.emptyState.visibility = if (isEmpty && !loading) View.VISIBLE else View.GONE
        binding.recyclerConversations.visibility = if (!isEmpty && !loading) View.VISIBLE else View.GONE
    }

    private fun observeState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                launch {
                    viewModel.conversations.collect { conversations ->
                        try {
                            allConversations = conversations
                            applyFilter()
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating conversations", e)
                        }
                    }
                }

                launch {
                    viewModel.historyLoading.collect { loading ->
                        try {
                            binding.progressBar.visibility = if (loading) View.VISIBLE else View.GONE
                            if (loading) {
                                binding.recyclerConversations.visibility = View.GONE
                                binding.emptyState.visibility = View.GONE
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating loading state", e)
                        }
                    }
                }

                launch {
                    viewModel.historyError.collect { error ->
                        try {
                            if (error != null) {
                                binding.errorState.visibility = View.VISIBLE
                                binding.errorText.text = error
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
