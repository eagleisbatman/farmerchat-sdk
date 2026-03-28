package org.digitalgreen.farmerchat.demo.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val FarmerChatGreen = Color(0xFF1B6B3A)
private val FarmerChatGreenLight = Color(0xFFF0F7F2)
private val FarmerChatSecondary = Color(0xFF4E8D60)

private val LightColorScheme = lightColorScheme(
    primary = FarmerChatGreen,
    onPrimary = Color.White,
    primaryContainer = FarmerChatGreenLight,
    onPrimaryContainer = FarmerChatGreen,
    secondary = FarmerChatSecondary,
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFD4EDDA),
    onSecondaryContainer = Color(0xFF0D3B1E),
    surface = Color.White,
    onSurface = Color(0xFF1C1B1F),
    background = Color(0xFFFAFDF7),
    onBackground = Color(0xFF1C1B1F),
    surfaceVariant = Color(0xFFF0F7F2),
    onSurfaceVariant = Color(0xFF43493F),
    outline = Color(0xFF73796E),
)

@Composable
fun FarmerChatDemoTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        content = content,
    )
}
