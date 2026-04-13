package org.digitalgreen.farmerchat.compose.screens

import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.digitalgreen.farmerchat.compose.FarmerChat
import org.digitalgreen.farmerchat.compose.network.SupportedLanguage
import org.digitalgreen.farmerchat.compose.theme.SdkDarkBg
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface2
import org.digitalgreen.farmerchat.compose.theme.SdkGreen500
import org.digitalgreen.farmerchat.compose.theme.SdkGreen800
import org.digitalgreen.farmerchat.compose.theme.SdkOutlineVariant
import org.digitalgreen.farmerchat.compose.theme.SdkTextMuted
import org.digitalgreen.farmerchat.compose.theme.SdkTextPrimary
import org.digitalgreen.farmerchat.compose.theme.SdkTextSecondary
import org.digitalgreen.farmerchat.compose.viewmodel.ChatViewModel

/**
 * Settings / profile screen — dark theme.
 *
 * Shows the language selector and "Powered by FarmerChat" branding.
 */
@Composable
internal fun ProfileScreen(viewModel: ChatViewModel) {
    val languageGroups by viewModel.availableLanguageGroups.collectAsStateWithLifecycle()
    val selectedLanguage by viewModel.selectedLanguage.collectAsStateWithLifecycle()
    val config = FarmerChat.getConfig()

    // Flatten all languages from all groups
    val languages: List<SupportedLanguage> = remember(languageGroups) {
        languageGroups.flatMap { it.languages }
    }

    // Load languages once
    LaunchedEffect(Unit) {
        try { viewModel.loadLanguages() } catch (_: Exception) {}
    }

    Box(modifier = Modifier.fillMaxSize().background(SdkDarkBg)) {
        Column(modifier = Modifier.fillMaxSize()) {

            // ── Top bar ──────────────────────────────────────────────────────
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF1A2318))
                    .statusBarsPadding()
                    .padding(horizontal = 4.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = {
                    try { viewModel.navigateTo(ChatViewModel.Screen.Chat) } catch (_: Exception) {}
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Language",
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = "Choose your preferred language",
                        color = SdkTextSecondary,
                        fontSize = 11.sp,
                    )
                }
            }

            // ── Language section ─────────────────────────────────────────────
            Text(
                text = "LANGUAGE",
                color = SdkGreen500,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.5.sp,
                modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 8.dp),
            )

            if (languages.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(32.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(color = SdkGreen500)
                }
            } else {
                LazyColumn(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        horizontal = 16.dp,
                        vertical = 4.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(languages, key = { it.id }) { language ->
                        LanguageRow(
                            language   = language,
                            isSelected = language.code == selectedLanguage,
                            onSelect   = {
                                try { viewModel.setPreferredLanguage(language) } catch (e: Exception) {
                                    Log.w("FC.Profile", "setPreferredLanguage failed", e)
                                }
                            },
                        )
                    }
                }
            }

            // ── Footer ───────────────────────────────────────────────────────
            Column(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                HorizontalDivider(color = SdkOutlineVariant)
                Spacer(Modifier.height(16.dp))
                if (config.showPoweredBy) {
                    Text(
                        text = "Powered by FarmerChat",
                        color = SdkTextMuted,
                        fontSize = 12.sp,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(4.dp))
                }
                Text(
                    text = "SDK v${FarmerChat.SDK_VERSION}",
                    color = SdkTextMuted,
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

// ── Language row ──────────────────────────────────────────────────────────────

@Composable
private fun LanguageRow(
    language: SupportedLanguage,
    isSelected: Boolean,
    onSelect: () -> Unit,
) {
    val bgColor = if (isSelected) SdkGreen800.copy(alpha = 0.25f) else SdkDarkSurface
    val borderColor = if (isSelected) SdkGreen500 else SdkOutlineVariant

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .border(if (isSelected) 1.5.dp else 1.dp, borderColor, RoundedCornerShape(12.dp))
            .clickable(onClick = onSelect)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // Speaker icon
        Icon(
            Icons.Default.VolumeUp,
            contentDescription = null,
            tint = if (isSelected) SdkGreen500 else SdkTextMuted,
            modifier = Modifier.size(18.dp),
        )

        // Names
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text       = language.displayName.ifBlank { language.name },
                color      = SdkTextPrimary,
                fontSize   = 14.sp,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            )
            if (language.name != language.displayName && language.name.isNotBlank()) {
                Text(text = language.name, color = SdkTextSecondary, fontSize = 12.sp)
            }
        }

        // Check indicator
        if (isSelected) {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .background(SdkGreen500, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
            }
        }
    }
}
