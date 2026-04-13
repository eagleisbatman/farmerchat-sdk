package org.digitalgreen.farmerchat.views.media

import androidx.core.content.FileProvider

/**
 * Empty FileProvider subclass so the Views SDK has a unique android:name in the manifest,
 * preventing conflicts when the host app also includes the Compose SDK.
 */
internal class ViewsFileProvider : FileProvider()
