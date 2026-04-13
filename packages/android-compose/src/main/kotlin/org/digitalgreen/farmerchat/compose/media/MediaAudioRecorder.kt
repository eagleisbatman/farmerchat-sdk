package org.digitalgreen.farmerchat.compose.media

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.util.Base64
import android.util.Log
import java.io.File

/**
 * Thin wrapper around [MediaRecorder] for the FarmerChat Compose SDK.
 *
 * Usage:
 * 1. [start] — begins recording to a temp file in cacheDir/farmerchat/audio/
 * 2. [stop]  — stops and returns Base64-encoded AMR audio
 * 3. [cancel]— aborts without returning data
 *
 * Audio format: AMR_NB (small, works on all Android versions, API accepts "AMR")
 */
internal class MediaAudioRecorder(private val context: Context) {

    private companion object {
        const val TAG = "FC.AudioRecorder"
    }

    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null

    val isRecording: Boolean get() = recorder != null

    /** Start recording. Returns true if successful. */
    fun start(): Boolean {
        return try {
            val dir = File(context.cacheDir, "farmerchat/audio").also { it.mkdirs() }
            val file = File(dir, "recording_${System.currentTimeMillis()}.amr")
            outputFile = file

            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.AMR_NB)
                setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }
            Log.d(TAG, "Recording started → ${file.name}")
            true
        } catch (e: Exception) {
            Log.e(TAG, "start() failed: ${e.message}")
            release()
            false
        }
    }

    /**
     * Stop recording and return the audio as a Base64 string.
     * Returns null if recording was never started or an error occurs.
     */
    fun stop(): String? {
        return try {
            recorder?.apply {
                stop()
                release()
            }
            recorder = null
            val bytes = outputFile?.readBytes()
            outputFile?.delete()
            outputFile = null
            if (bytes != null) Base64.encodeToString(bytes, Base64.NO_WRAP) else null
        } catch (e: Exception) {
            Log.e(TAG, "stop() failed: ${e.message}")
            release()
            null
        }
    }

    /** Cancel recording without returning data. */
    fun cancel() {
        try {
            release()
            outputFile?.delete()
            outputFile = null
        } catch (e: Exception) {
            Log.w(TAG, "cancel() failed: ${e.message}")
        }
    }

    private fun release() {
        try {
            recorder?.apply { stop(); release() }
        } catch (_: Exception) {}
        recorder = null
    }
}

/** Convert a content/file URI to a Base64-encoded JPEG string. */
internal fun uriToBase64Jpeg(context: Context, uriString: String): String? {
    return try {
        val uri = android.net.Uri.parse(uriString)
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: return null
        // Decode → re-encode as JPEG at 80% quality to reduce size
        val bitmap = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: return null
        val out = java.io.ByteArrayOutputStream()
        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, out)
        Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    } catch (e: Exception) {
        Log.e("FC.ImageUtils", "uriToBase64Jpeg failed: ${e.message}")
        null
    }
}
