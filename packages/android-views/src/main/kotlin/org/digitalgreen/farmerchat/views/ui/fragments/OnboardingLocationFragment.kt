package org.digitalgreen.farmerchat.views.ui.fragments

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.navigation.fragment.findNavController
import org.digitalgreen.farmerchat.views.R
import org.digitalgreen.farmerchat.views.databinding.FragmentOnboardingLocationBinding
import org.digitalgreen.farmerchat.views.network.TokenStore
import org.digitalgreen.farmerchat.views.viewmodel.ChatViewModel

/**
 * Onboarding step 1: Region auto-detected.
 *
 * Per WEATHER_GPS_FLOW spec, the SDK does NOT request GPS / location permission.
 * The user's region is detected server-side via IP geolocation during initialize_user.
 * This screen shows the detected region and lets the user proceed to language selection.
 */
internal class OnboardingLocationFragment : Fragment() {

    private companion object {
        const val TAG = "FC.OnboardingLoc"
    }

    private var _binding: FragmentOnboardingLocationBinding? = null
    private val binding get() = _binding!!

    private val viewModel: ChatViewModel by activityViewModels()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View? {
        return try {
            _binding = FragmentOnboardingLocationBinding.inflate(inflater, container, false)
            binding.root
        } catch (e: Exception) {
            Log.e(TAG, "onCreateView failed", e)
            null
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        try {
            // Display IP-detected region (populated by initialize_user, no GPS permission needed)
            val country = TokenStore.country.ifBlank { "" }
            val state   = TokenStore.state.ifBlank { "" }
            val label   = when {
                state.isNotEmpty() && country.isNotEmpty() -> "$state, $country"
                country.isNotEmpty() -> country
                else -> "Your Region"
            }
            binding.tvRegionLabel.text  = label
            binding.tvRegionDetail.text =
                "Your region was automatically detected from your network." +
                " This helps us provide farming advice relevant to your area."

            // "Continue" — proceed to language selection
            binding.btnShareLocation.setOnClickListener {
                try {
                    findNavController().navigate(R.id.action_onboarding_location_to_language)
                } catch (e: Exception) {
                    Log.w(TAG, "Continue click failed", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "onViewCreated failed", e)
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
