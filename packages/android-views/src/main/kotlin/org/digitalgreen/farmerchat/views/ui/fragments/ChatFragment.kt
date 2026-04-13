package org.digitalgreen.farmerchat.views.ui.fragments

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.util.Base64
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
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
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.chip.Chip
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.digitalgreen.farmerchat.views.FarmerChat
import org.digitalgreen.farmerchat.views.R
import org.digitalgreen.farmerchat.views.databinding.FragmentChatBinding
import org.digitalgreen.farmerchat.views.media.MediaAudioRecorder
import org.digitalgreen.farmerchat.views.media.uriToBase64Jpeg
import org.digitalgreen.farmerchat.views.ui.adapters.MessageAdapter
import org.digitalgreen.farmerchat.views.viewmodel.ChatViewModel
import java.io.File

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

    // Audio recording
    private var audioRecorder: MediaAudioRecorder? = null
    private var isRecording = false
    private var cameraPhotoUri: Uri? = null
    private var selectedImageBase64: String? = null
    private var selectedImageUri: Uri? = null

    // Permission launchers
    private val micPermLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) showVoiceBottomSheet() }

    private val camPermLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) showImageSourceSheet() }

    private val galleryLauncher = registerForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        uri?.let {
            selectedImageUri = it
            viewLifecycleOwner.lifecycleScope.launch {
                val b64 = withContext(Dispatchers.IO) { uriToBase64Jpeg(requireContext(), it.toString()) }
                if (b64 != null) onImageSelected(b64)
            }
        }
    }

    private val takePictureLauncher = registerForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success) {
            cameraPhotoUri?.let { uri ->
                selectedImageUri = uri
                viewLifecycleOwner.lifecycleScope.launch {
                    val b64 = withContext(Dispatchers.IO) { uriToBase64Jpeg(requireContext(), uri.toString()) }
                    if (b64 != null) onImageSelected(b64)
                }
            }
        }
    }

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
            applyWindowInsets()
            setupToolbar()
            setupWeatherWidget()
            setupRecyclerView()
            setupInputBar()
            observeState()
            viewModel.loadStarters()
        } catch (e: Exception) {
            Log.e(TAG, "onViewCreated failed", e)
        }
    }

    private fun setupWeatherWidget() {
        try {
            val config = FarmerChat.getConfig()
            val temp = config.weatherTemp
            if (temp.isNullOrEmpty()) {
                binding.weatherWidget.visibility = android.view.View.GONE
                return
            }
            binding.weatherWidget.visibility = android.view.View.VISIBLE
            binding.tvWeatherTemp.text = temp

            val loc = config.weatherLocation
            if (!loc.isNullOrEmpty()) {
                binding.tvWeatherLocation.text = "📍  $loc"
                binding.tvWeatherLocation.visibility = android.view.View.VISIBLE
            }

            val crop = config.cropName
            if (!crop.isNullOrEmpty()) {
                binding.tvCropName.text = "🌾  $crop"
                binding.tvCropName.visibility = android.view.View.VISIBLE
            }

            binding.weatherWidget.setOnClickListener {
                try {
                    viewModel.sendWeatherQuery("Tell me about farming advice for this weather")
                } catch (e: Exception) {
                    Log.w(TAG, "Weather widget click failed", e)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "setupWeatherWidget failed", e)
        }
    }

    private fun applyWindowInsets() {
        try {
            ViewCompat.setOnApplyWindowInsetsListener(binding.root) { _, insets ->
                val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
                // Toolbar gets top padding so its background fills behind the status bar
                binding.toolbar.updatePadding(top = bars.top)
                // Input bar at bottom gets navigation bar padding
                binding.inputBar.updatePadding(bottom = bars.bottom)
                WindowInsetsCompat.CONSUMED
            }
        } catch (e: Exception) {
            Log.w(TAG, "applyWindowInsets failed", e)
        }
    }

    private fun setupToolbar() {
        val config = FarmerChat.getConfig()
        // Only override the title if the host app set one; default is in the layout string
        if (config.headerTitle.isNotBlank()) {
            binding.toolbarTitle.text = config.headerTitle
        }

        binding.btnHistory.visibility = if (config.historyEnabled) View.VISIBLE else View.GONE
        binding.btnLanguage?.visibility = if (config.profileEnabled) View.VISIBLE else View.GONE
        binding.btnProfile.visibility = if (config.profileEnabled) View.VISIBLE else View.GONE

        binding.btnHistory.setOnClickListener {
            try {
                findNavController().navigate(R.id.action_chat_to_history)
            } catch (e: Exception) {
                Log.w(TAG, "Navigation to history failed", e)
            }
        }

        binding.btnLanguage?.setOnClickListener {
            try {
                findNavController().navigate(R.id.action_chat_to_profile)
            } catch (e: Exception) {
                Log.w(TAG, "Navigation to profile (language) failed", e)
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

    private fun dispatchSend() {
        try {
            if (selectedImageBase64 != null) {
                dispatchSendWithImage()
                return
            }
            val text = binding.inputBar.editMessage?.text?.toString()?.trim()
            if (text.isNullOrEmpty()) return
            viewModel.sendQuery(text)
            binding.inputBar.editMessage?.text?.clear()
            updateInputBarButtons(hasText = false)
        } catch (e: Exception) {
            Log.w(TAG, "Send failed", e)
        }
    }

    private fun setupInputBar() {
        binding.inputBar.btnSend?.setOnClickListener { dispatchSend() }

        binding.inputBar.editMessage?.addTextChangedListener(object : android.text.TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: android.text.Editable?) {
                updateInputBarButtons(hasText = !s.isNullOrBlank())
            }
        })

        binding.inputBar.editMessage?.setOnEditorActionListener { _, actionId, _ ->
            try {
                if (actionId == EditorInfo.IME_ACTION_SEND) {
                    dispatchSend()
                    true
                } else false
            } catch (e: Exception) {
                Log.w(TAG, "Editor action failed", e)
                false
            }
        }

        // Mic button
        binding.inputBar.btnVoice?.setOnClickListener {
            try { onMicClicked() } catch (e: Exception) { Log.w(TAG, "Mic click failed", e) }
        }

        // Camera button
        binding.inputBar.btnCamera?.setOnClickListener {
            try { onCameraClicked() } catch (e: Exception) { Log.w(TAG, "Camera click failed", e) }
        }

        val config = FarmerChat.getConfig()
        if (!config.imageInputEnabled) binding.inputBar.btnCameraContainer?.visibility = View.GONE
        if (!config.voiceInputEnabled) binding.inputBar.btnVoiceContainer?.visibility = View.GONE
        updateInputBarButtons(hasText = false)
    }

    private fun updateInputBarButtons(hasText: Boolean) {
        try {
            val showSend = hasText || selectedImageBase64 != null
            binding.inputBar.btnSendContainer?.visibility = if (showSend) View.VISIBLE else View.GONE
            binding.inputBar.btnVoiceContainer?.visibility = if (showSend) View.GONE else View.VISIBLE
        } catch (e: Exception) {
            Log.w(TAG, "updateInputBarButtons failed", e)
        }
    }

    private fun onMicClicked() {
        val ctx = context ?: return
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO)
            == PackageManager.PERMISSION_GRANTED) {
            showVoiceBottomSheet()
        } else {
            micPermLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    private fun onCameraClicked() {
        val ctx = context ?: return
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED) {
            showImageSourceSheet()
        } else {
            camPermLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    private fun showVoiceBottomSheet() {
        try {
            val ctx = context ?: return
            val dialog = BottomSheetDialog(ctx)
            val sheetView = layoutInflater.inflate(R.layout.sheet_voice_input, null)
            dialog.setContentView(sheetView)

            val recorder = MediaAudioRecorder(ctx).also { audioRecorder = it }
            var sheetState = "idle"

            val tvStatus = sheetView.findViewById<TextView?>(R.id.tvVoiceStatus)
            val btnMicStart = sheetView.findViewById<View?>(R.id.btnMicStart)
            val btnStop    = sheetView.findViewById<View?>(R.id.btnStop)
            val btnCancel  = sheetView.findViewById<View?>(R.id.btnCancelRecording)
            val progressAudio = sheetView.findViewById<View?>(R.id.progressAudio)
            val waveformView = sheetView.findViewById<View?>(R.id.waveformContainer)

            btnMicStart?.setOnClickListener {
                if (recorder.start()) {
                    sheetState = "recording"
                    isRecording = true
                    tvStatus?.setText(R.string.fc_voice_recording)
                    btnMicStart.visibility = View.GONE
                    waveformView?.visibility = View.VISIBLE
                    btnStop?.visibility = View.VISIBLE
                    btnCancel?.visibility = View.VISIBLE
                }
            }

            btnStop?.setOnClickListener {
                sheetState = "processing"
                tvStatus?.setText(R.string.fc_voice_processing)
                waveformView?.visibility = View.GONE
                btnStop.visibility = View.GONE
                btnCancel?.visibility = View.GONE
                progressAudio?.visibility = View.VISIBLE
                viewLifecycleOwner.lifecycleScope.launch {
                    val base64 = withContext(Dispatchers.IO) { recorder.stop() }
                    isRecording = false
                    dialog.dismiss()
                    if (base64 != null) {
                        viewModel.transcribeAndSendAudio(base64, "AMR")
                    }
                }
            }

            btnCancel?.setOnClickListener {
                recorder.cancel()
                isRecording = false
                dialog.dismiss()
            }

            dialog.setOnDismissListener {
                if (isRecording) { recorder.cancel(); isRecording = false }
                audioRecorder = null
            }

            dialog.show()
        } catch (e: Exception) {
            Log.w(TAG, "showVoiceBottomSheet failed", e)
        }
    }

    private fun showImageSourceSheet() {
        try {
            val ctx = context ?: return
            val dialog = BottomSheetDialog(ctx)
            val sheetView = layoutInflater.inflate(R.layout.sheet_image_source, null)
            dialog.setContentView(sheetView)

            sheetView.findViewById<View?>(R.id.btnTakePhoto)?.setOnClickListener {
                dialog.dismiss()
                launchCamera()
            }
            sheetView.findViewById<View?>(R.id.btnChooseGallery)?.setOnClickListener {
                dialog.dismiss()
                galleryLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            }
            sheetView.findViewById<View?>(R.id.btnCancelImageSource)?.setOnClickListener {
                dialog.dismiss()
            }

            dialog.show()
        } catch (e: Exception) {
            Log.w(TAG, "showImageSourceSheet failed", e)
        }
    }

    private fun launchCamera() {
        try {
            val ctx = context ?: return
            val dir = File(ctx.cacheDir, "farmerchat/images").also { it.mkdirs() }
            val file = File(dir, "photo_${System.currentTimeMillis()}.jpg")
            val uri = FileProvider.getUriForFile(
                ctx, "${ctx.packageName}.fc_views_provider", file)
            cameraPhotoUri = uri
            takePictureLauncher.launch(uri)
        } catch (e: Exception) {
            Log.w(TAG, "launchCamera failed", e)
        }
    }

    private fun onImageSelected(base64: String) {
        selectedImageBase64 = base64
        updateInputBarButtons(hasText = !binding.inputBar.editMessage?.text.isNullOrBlank())
    }

    private fun dispatchSendWithImage() {
        try {
            val text = binding.inputBar.editMessage?.text?.toString()?.trim() ?: ""
            val img = selectedImageBase64 ?: return
            // Extract GPS from EXIF — no location permission needed
            val gps = selectedImageUri?.let {
                org.digitalgreen.farmerchat.views.media.ImageUtils.getLocationFromExif(requireContext(), it)
            }
            viewModel.sendQueryWithImage(text, img, gps?.first, gps?.second)
            selectedImageBase64 = null
            selectedImageUri = null
            binding.inputBar.editMessage?.text?.clear()
            updateInputBarButtons(hasText = false)
        } catch (e: Exception) {
            Log.w(TAG, "dispatchSendWithImage failed", e)
        }
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
