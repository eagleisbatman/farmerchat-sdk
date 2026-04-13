package org.digitalgreen.farmerchat.compose.media

import androidx.core.content.FileProvider

/**
 * Empty FileProvider subclass so the Compose SDK has a unique android:name in the manifest,
 * preventing conflicts when the host app also includes the Views SDK.
 */
internal class ComposeFileProvider : FileProvider()
