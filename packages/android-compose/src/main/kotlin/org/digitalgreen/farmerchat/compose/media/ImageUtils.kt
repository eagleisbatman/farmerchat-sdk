package org.digitalgreen.farmerchat.compose.media

import android.content.Context
import android.net.Uri
import androidx.exifinterface.media.ExifInterface

/**
 * Utilities for extracting metadata from images.
 * No location permission is required — EXIF is read directly from the image stream.
 */
internal object ImageUtils {

    /**
     * Extracts GPS coordinates from the EXIF metadata of the image at [uri].
     *
     * @return Pair(latitude, longitude) as strings (e.g. "12.9716", "77.5946"),
     *         or null if the image has no GPS EXIF data.
     */
    fun getLocationFromExif(context: Context, uri: Uri): Pair<String, String>? {
        return try {
            context.contentResolver.openInputStream(uri)?.use { stream ->
                val exif = ExifInterface(stream)
                val latLong = FloatArray(2)
                if (exif.getLatLong(latLong)) {
                    Pair(latLong[0].toString(), latLong[1].toString())
                } else null
            }
        } catch (_: Exception) {
            null
        }
    }
}
