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
import org.digitalgreen.farmerchat.views.FarmerChat
import org.digitalgreen.farmerchat.views.databinding.FragmentProfileBinding
import org.digitalgreen.farmerchat.views.ui.adapters.LanguageAdapter
import org.digitalgreen.farmerchat.views.viewmodel.ChatViewModel

/**
 * Profile fragment displaying language settings and SDK branding.
 *
 * Uses ViewBinding with [FragmentProfileBinding]. Allows the user to change the active
 * language. Shows "Powered by FarmerChat" footer if configured.
 *
 * All lifecycle methods and user interactions are wrapped in try-catch — the SDK must
 * never crash the host app.
 */
internal class ProfileFragment : Fragment() {

    private companion object {
        const val TAG = "FC.ProfileFragment"
    }

    private var _binding: FragmentProfileBinding? = null
    private val binding get() = _binding!!

    private val viewModel: ChatViewModel by activityViewModels()
    private lateinit var languageAdapter: LanguageAdapter

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View? {
        return try {
            _binding = FragmentProfileBinding.inflate(inflater, container, false)
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
            setupLanguageSelector()
            setupFooter()
            observeState()
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

    private fun setupLanguageSelector() {
        languageAdapter = LanguageAdapter(
            selectedCode = viewModel.selectedLanguage.value,
            onLanguageSelected = { language ->
                try {
                    viewModel.setLanguage(language.code)
                    languageAdapter.setSelectedCode(language.code)
                } catch (e: Exception) {
                    Log.w(TAG, "Language selection failed", e)
                }
            },
        )

        binding.recyclerLanguages.apply {
            layoutManager = LinearLayoutManager(requireContext())
            adapter = languageAdapter
        }
    }

    private fun setupFooter() {
        val config = FarmerChat.getConfig()
        binding.poweredByFooter.visibility = if (config.showPoweredBy) View.VISIBLE else View.GONE
    }

    private fun observeState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                // Observe languages
                launch {
                    viewModel.availableLanguageGroups.collect { groups ->
                        try {
                            languageAdapter.submitList(groups.flatMap { it.languages })
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating languages", e)
                        }
                    }
                }

                // Observe selected language
                launch {
                    viewModel.selectedLanguage.collect { code ->
                        try {
                            languageAdapter.setSelectedCode(code)
                        } catch (e: Exception) {
                            Log.w(TAG, "Error updating selected language", e)
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
