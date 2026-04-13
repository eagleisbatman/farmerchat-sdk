package org.digitalgreen.farmerchat.views.ui.views

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import android.view.LayoutInflater
import android.widget.EditText
import android.widget.ImageButton
import android.widget.LinearLayout
import org.digitalgreen.farmerchat.views.R
import org.digitalgreen.farmerchat.views.databinding.ViewInputBarBinding

/**
 * Custom compound view for the chat input bar.
 *
 * Contains an [EditText] for message input and buttons for send, voice, and camera.
 * Inflates [R.layout.view_input_bar] via ViewBinding.
 *
 * The host fragment accesses child views through the [binding] property to wire up
 * click listeners and observe text changes.
 *
 * All initialization is wrapped in try-catch — the SDK must never crash the host app.
 */
internal class InputBarView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : LinearLayout(context, attrs, defStyleAttr) {

    private companion object {
        const val TAG = "FC.InputBarView"
    }

    private val binding: ViewInputBarBinding?

    /** EditText for message input. */
    val editMessage: EditText? get() = binding?.editMessage

    /** Send button. */
    val btnSend: ImageButton? get() = binding?.btnSend

    /** Container for the send button (has circular green bg + elevation). */
    val btnSendContainer: android.widget.FrameLayout? get() = binding?.btnSendContainer

    /** Voice input button. */
    val btnVoice: ImageButton? get() = binding?.btnVoice

    /** Container for the voice button (has circular green bg + elevation). */
    val btnVoiceContainer: android.widget.FrameLayout? get() = binding?.btnVoiceContainer

    /** Camera/image input button. */
    val btnCamera: ImageButton? get() = binding?.btnCamera

    /** Container for the camera button (has dark circular bg). */
    val btnCameraContainer: android.widget.FrameLayout? get() = binding?.btnCameraContainer

    init {
        binding = try {
            ViewInputBarBinding.inflate(LayoutInflater.from(context), this, true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to inflate input bar", e)
            null // SDK must never crash the host app
        }
    }
}
