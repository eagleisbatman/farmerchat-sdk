package org.digitalgreen.farmerchat.views.media

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.util.Base64
import android.util.Log
import java.io.ByteArrayOutputStream
import java.io.File

internal class MediaAudioRecorder(private val context: Context) {
    private companion object { const val TAG = "FC.AudioRecorder" }
    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null
    val isRecording: Boolean get() = recorder != null

    fun start(): Boolean {
        return try {
            val dir = File(context.cacheDir, "farmerchat/audio").also { it.mkdirs() }
            val file = File(dir, "recording_${System.currentTimeMillis()}.amr")
            outputFile = file
            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION") MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.AMR_NB)
                setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "start() failed: ${e.message}")
            release(); false
        }
    }

    fun stop(): String? {
        return try {
            recorder?.apply { stop(); release() }
            recorder = null
            val bytes = outputFile?.readBytes()
            outputFile?.delete(); outputFile = null
            if (bytes != null) Base64.encodeToString(bytes, Base64.NO_WRAP) else null
        } catch (e: Exception) {
            Log.e(TAG, "stop() failed: ${e.message}")
            release(); null
        }
    }

    fun cancel() {
        try { release(); outputFile?.delete(); outputFile = null }
        catch (e: Exception) { Log.w(TAG, "cancel failed", e) }
    }

    private fun release() {
        try { recorder?.apply { stop(); release() } } catch (_: Exception) {}
        recorder = null
    }
}

internal fun uriToBase64Jpeg(context: Context, uriString: String): String? {
    return try {
        val uri = Uri.parse(uriString)
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
        Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    } catch (e: Exception) {
        Log.e("FC.ImageUtils", "uriToBase64Jpeg failed: ${e.message}")
        null
    }
}
