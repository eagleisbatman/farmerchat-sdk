package org.digitalgreen.farmerchat.compose.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import org.digitalgreen.farmerchat.compose.FarmerChat
import org.digitalgreen.farmerchat.compose.FarmerChatConfig

/**
 * FarmerChat theme wrapper that extends MaterialTheme
 * with SDK-specific color and typography customizations.
 *
 * Derives the color scheme from [FarmerChatConfig.primaryColor] and
 * [FarmerChatConfig.secondaryColor], layered on top of the current
 * MaterialTheme so host-app tokens are preserved where possible.
 */
@Composable
fun FarmerChatTheme(
    config: FarmerChatConfig = FarmerChat.getConfig(),
    content: @Composable () -> Unit,
) {
    val primaryColor = Color(config.primaryColor)
    val secondaryColor = Color(config.secondaryColor)

    val colorScheme = MaterialTheme.colorScheme.copy(
        primary = primaryColor,
        onPrimary = Color.White,
        primaryContainer = secondaryColor,
        onPrimaryContainer = primaryColor,
        secondary = primaryColor.copy(alpha = 0.8f),
        surface = Color.White,
        background = Color.White,
    )

    MaterialTheme(
        colorScheme = colorScheme,
        content = content,
    )
}
