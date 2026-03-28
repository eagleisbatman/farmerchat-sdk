package org.digitalgreen.farmerchat.views.ui.fragments

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.navigation.fragment.findNavController
import org.digitalgreen.farmerchat.views.R
import org.digitalgreen.farmerchat.views.databinding.FragmentOnboardingLocationBinding
import org.digitalgreen.farmerchat.views.viewmodel.ChatViewModel

/**
 * Onboarding step 1: Location sharing.
 *
 * The user can share their location or skip to the language selection step.
 * All user interactions are wrapped in try-catch — the SDK must never crash the host app.
 */
internal class OnboardingLocationFragment : Fragment() {

    private companion object {
        const val TAG = "FC.OnboardingLoc"
    }

    private var _binding: FragmentOnboardingLocationBinding? = null
    private val binding get() = _binding!!

    private val viewModel: ChatViewModel by activityViewModels()

    private val locationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        try {
            if (granted) {
                // Location permission granted — navigate to language step
                findNavController().navigate(R.id.action_onboarding_location_to_language)
            } else {
                // Permission denied — still allow proceeding
                findNavController().navigate(R.id.action_onboarding_location_to_language)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Location permission result handling failed", e)
        }
    }

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
            binding.btnShareLocation.setOnClickListener {
                try {
                    requestLocationPermission()
                } catch (e: Exception) {
                    Log.w(TAG, "Share location click failed", e)
                    // Navigate anyway
                    findNavController().navigate(R.id.action_onboarding_location_to_language)
                }
            }

            binding.btnSkipLocation.setOnClickListener {
                try {
                    findNavController().navigate(R.id.action_onboarding_location_to_language)
                } catch (e: Exception) {
                    Log.w(TAG, "Skip location click failed", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "onViewCreated failed", e)
        }
    }

    private fun requestLocationPermission() {
        val permission = Manifest.permission.ACCESS_FINE_LOCATION
        if (ContextCompat.checkSelfPermission(requireContext(), permission)
            == PackageManager.PERMISSION_GRANTED
        ) {
            // Already granted
            findNavController().navigate(R.id.action_onboarding_location_to_language)
        } else {
            locationPermissionLauncher.launch(permission)
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
