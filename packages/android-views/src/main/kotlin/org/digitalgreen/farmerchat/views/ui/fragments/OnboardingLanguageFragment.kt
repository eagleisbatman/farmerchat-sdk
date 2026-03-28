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
import org.digitalgreen.farmerchat.views.databinding.FragmentOnboardingLanguageBinding
import org.digitalgreen.farmerchat.views.ui.adapters.LanguageAdapter
import org.digitalgreen.farmerchat.views.viewmodel.ChatViewModel

/**
 * Onboarding step 2: Language selection.
 *
 * Displays available languages in a RecyclerView. The user selects one and taps
 * "Get Started" to proceed to the chat.
 *
 * All user interactions are wrapped in try-catch — the SDK must never crash the host app.
 */
internal class OnboardingLanguageFragment : Fragment() {

    private companion object {
        const val TAG = "FC.OnboardingLang"
    }

    private var _binding: FragmentOnboardingLanguageBinding? = null
    private val binding get() = _binding!!

    private val viewModel: ChatViewModel by activityViewModels()
    private lateinit var languageAdapter: LanguageAdapter
    private var selectedLanguageCode: String = ""

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View? {
        return try {
            _binding = FragmentOnboardingLanguageBinding.inflate(inflater, container, false)
            binding.root
        } catch (e: Exception) {
            Log.e(TAG, "onCreateView failed", e)
            null
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        try {
            selectedLanguageCode = viewModel.selectedLanguage.value

            languageAdapter = LanguageAdapter(
                selectedCode = selectedLanguageCode,
                onLanguageSelected = { code ->
                    try {
                        selectedLanguageCode = code
                        languageAdapter.setSelectedCode(code)
                        binding.btnGetStarted.isEnabled = true
                    } catch (e: Exception) {
                        Log.w(TAG, "Language selection failed", e)
                    }
                },
            )

            binding.recyclerLanguages.apply {
                layoutManager = LinearLayoutManager(requireContext())
                adapter = languageAdapter
            }

            binding.btnGetStarted.isEnabled = selectedLanguageCode.isNotEmpty()
            binding.btnGetStarted.setOnClickListener {
                try {
                    if (selectedLanguageCode.isNotEmpty()) {
                        viewModel.skipOnboarding(selectedLanguageCode)
                        findNavController().navigate(R.id.action_onboarding_language_to_chat)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Get Started click failed", e)
                }
            }

            observeLanguages()
        } catch (e: Exception) {
            Log.e(TAG, "onViewCreated failed", e)
        }
    }

    private fun observeLanguages() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.availableLanguages.collect { languages ->
                    try {
                        languageAdapter.submitList(languages)
                    } catch (e: Exception) {
                        Log.w(TAG, "Error updating languages", e)
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
