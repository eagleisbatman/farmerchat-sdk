package org.digitalgreen.farmerchat.compose.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import org.digitalgreen.farmerchat.compose.FarmerChat
import org.digitalgreen.farmerchat.compose.FarmerChatConfig

/**
 * FarmerChat dark theme wrapper — all SDK screens run inside this.
 *
 * Uses the forest-green dark palette defined in [SdkColors].
 * Config-supplied [FarmerChatConfig.primaryColor] and [FarmerChatConfig.secondaryColor]
 * are honoured if set; otherwise the SDK defaults to [SdkGreen500] / [SdkGreen800].
 */
@Composable
fun FarmerChatTheme(
    config: FarmerChatConfig = FarmerChat.getConfig(),
    content: @Composable () -> Unit,
) {
    val primary = if (config.primaryColor != 0) Color(config.primaryColor) else SdkGreen500
    val primaryDark = if (config.secondaryColor != 0) Color(config.secondaryColor) else SdkGreen800

    val colorScheme = darkColorScheme(
        primary             = primary,
        onPrimary           = Color.White,
        primaryContainer    = SdkPrimaryContainer,
        onPrimaryContainer  = SdkTextPrimary,
        secondary           = SdkGreen400,
        onSecondary         = Color.White,
        secondaryContainer  = SdkDarkSurface2,
        onSecondaryContainer = SdkTextSecondary,
        tertiary            = SdkGreenAccent,
        surface             = SdkDarkSurface,
        onSurface           = SdkTextPrimary,
        surfaceVariant      = SdkDarkSurface2,
        onSurfaceVariant    = SdkTextSecondary,
        background          = SdkDarkBg,
        onBackground        = SdkTextPrimary,
        error               = SdkError,
        onError             = Color.White,
        errorContainer      = SdkErrorContainer,
        onErrorContainer    = SdkError,
        outline             = SdkOutlineVariant,
        outlineVariant      = SdkOutlineVariant,
        inverseSurface      = SdkTextPrimary,
        inverseOnSurface    = SdkDarkBg,
        inversePrimary      = primaryDark,
    )

    MaterialTheme(
        colorScheme = colorScheme,
        content = content,
    )
}
