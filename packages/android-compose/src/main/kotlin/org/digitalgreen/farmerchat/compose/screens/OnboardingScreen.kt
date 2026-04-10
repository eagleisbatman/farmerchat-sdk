package org.digitalgreen.farmerchat.compose.screens

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.digitalgreen.farmerchat.compose.network.SupportedLanguage
import org.digitalgreen.farmerchat.compose.theme.SdkDarkBg
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface2
import org.digitalgreen.farmerchat.compose.theme.SdkGreen500
import org.digitalgreen.farmerchat.compose.theme.SdkTextMuted
import org.digitalgreen.farmerchat.compose.theme.SdkTextPrimary
import org.digitalgreen.farmerchat.compose.theme.SdkTextSecondary
import org.digitalgreen.farmerchat.compose.viewmodel.ChatViewModel

/**
 * Onboarding screen — dark theme.
 *
 * Step 1: Location permission.
 * Step 2: Language selection (2-col grid, design-guide spec).
 */
@Composable
internal fun OnboardingScreen(viewModel: ChatViewModel) {
    val languageGroups by viewModel.availableLanguageGroups.collectAsStateWithLifecycle()
    val selectedLanguage by viewModel.selectedLanguage.collectAsStateWithLifecycle()

    // Flatten all languages from all groups
    val languages: List<SupportedLanguage> = remember(languageGroups) {
        languageGroups.flatMap { it.languages }
    }

    var step by remember { mutableStateOf(1) }
    var locationGranted by remember { mutableStateOf(false) }

    val context = LocalContext.current

    val hasLocationPermission = remember {
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    if (hasLocationPermission && !locationGranted) {
        locationGranted = true
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        try {
            locationGranted = granted
            step = 2
        } catch (e: Exception) {
            Log.w("FC.Onboarding", "Permission result failed", e)
        }
    }

    // Load languages when entering step 2
    LaunchedEffect(step) {
        if (step == 2 && languageGroups.isEmpty()) {
            try { viewModel.loadLanguages() } catch (e: Exception) {
                Log.w("FC.Onboarding", "loadLanguages failed", e)
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(SdkDarkBg),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(56.dp))

            // Logo circle
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .background(SdkGreen500, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text("🌱", fontSize = 36.sp)
            }

            Spacer(Modifier.height(14.dp))

            Text(
                text = "FarmChat AI",
                color = Color.White,
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "Smart Farming Assistant",
                color = Color.White.copy(alpha = 0.65f),
                fontSize = 13.sp,
            )

            Spacer(Modifier.height(28.dp))

            if (step == 1) {
                LocationStep(
                    locationGranted = locationGranted,
                    onRequest = {
                        try { permissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION) } catch (_: Exception) {}
                    },
                    onSkip = { step = 2 },
                )
            } else {
                LanguageStep(
                    languages     = languages,
                    selectedCode  = selectedLanguage,
                    onLangSelected = { language ->
                        try { viewModel.setPreferredLanguage(language) } catch (e: Exception) {
                            Log.w("FC.Onboarding", "setPreferredLanguage failed", e)
                        }
                    },
                )
            }

            Spacer(Modifier.weight(1f))
            Spacer(Modifier.height(12.dp))

            // Continue / Get Started button
            Button(
                onClick = {
                    try {
                        if (step == 1) {
                            step = 2
                        } else {
                            viewModel.navigateTo(ChatViewModel.Screen.Chat)
                        }
                    } catch (e: Exception) {
                        Log.w("FC.Onboarding", "Continue button failed", e)
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(26.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = SdkGreen500,
                    disabledContainerColor = SdkGreen500.copy(alpha = 0.35f),
                ),
                enabled = step == 1 || selectedLanguage.isNotEmpty(),
            ) {
                Text(
                    text = if (step == 1) "Continue" else "Get Started",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 16.sp,
                )
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

// ── Location step ─────────────────────────────────────────────────────────────

@Composable
private fun LocationStep(
    locationGranted: Boolean,
    onRequest: () -> Unit,
    onSkip: () -> Unit,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .background(SdkDarkSurface, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.LocationOn, contentDescription = null, tint = SdkGreen500, modifier = Modifier.size(40.dp))
        }

        Spacer(Modifier.height(20.dp))

        Text(
            text = "Share your location so we can provide farming advice relevant to your area.",
            color = SdkTextSecondary,
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
            lineHeight = 20.sp,
        )

        Spacer(Modifier.height(24.dp))

        if (locationGranted) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Check, contentDescription = null, tint = SdkGreen500, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text("Location permission granted", color = SdkGreen500, fontSize = 14.sp)
            }
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .clip(RoundedCornerShape(26.dp))
                    .background(SdkDarkSurface2)
                    .border(1.dp, SdkGreen500, RoundedCornerShape(26.dp))
                    .clickable(onClick = onRequest),
                contentAlignment = Alignment.Center,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(Icons.Default.LocationOn, contentDescription = null, tint = SdkGreen500, modifier = Modifier.size(20.dp))
                    Text("Share Location", color = Color.White, fontWeight = FontWeight.Medium)
                }
            }

            Spacer(Modifier.height(12.dp))

            Text(
                text = "Skip for now",
                color = SdkTextMuted,
                fontSize = 13.sp,
                modifier = Modifier.clickable(onClick = onSkip).padding(8.dp),
            )
        }
    }
}

// ── Language step ─────────────────────────────────────────────────────────────

@Composable
private fun LanguageStep(
    languages: List<SupportedLanguage>,
    selectedCode: String,
    onLangSelected: (SupportedLanguage) -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "SELECT YOUR LANGUAGE",
            color = SdkGreen500,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.8.sp,
        )

        Spacer(Modifier.height(12.dp))

        if (languages.isEmpty()) {
            Box(modifier = Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = SdkGreen500)
            }
            return@Column
        }

        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(languages, key = { it.id }) { language ->
                LanguageCard(
                    language     = language,
                    isSelected   = language.code == selectedCode,
                    onSelect     = { onLangSelected(language) },
                )
            }
        }
    }
}

// ── Language card ─────────────────────────────────────────────────────────────

@Composable
private fun LanguageCard(
    language: SupportedLanguage,
    isSelected: Boolean,
    onSelect: () -> Unit,
) {
    val bgColor    = if (isSelected) Color(0xFF1A3A0D).copy(alpha = 0.70f)
                     else Color.Black.copy(alpha = 0.40f)
    val borderColor = if (isSelected) SdkGreen500 else Color.White.copy(alpha = 0.12f)
    val borderWidth = if (isSelected) 1.5.dp else 1.dp

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(bgColor)
            .border(borderWidth, borderColor, RoundedCornerShape(14.dp))
            .clickable(onClick = onSelect)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Default.VolumeUp,
            contentDescription = null,
            tint = if (isSelected) SdkGreen500 else Color(0xFF6B7C69),
            modifier = Modifier.size(18.dp),
        )

        Spacer(Modifier.width(8.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text       = language.displayName.ifBlank { language.name },
                color      = Color.White,
                fontSize   = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )
            if (language.name != language.displayName && language.name.isNotBlank()) {
                Text(
                    text   = language.name,
                    color  = Color.White.copy(alpha = 0.55f),
                    fontSize = 11.sp,
                )
            }
        }

        if (isSelected) {
            Box(
                modifier = Modifier
                    .size(20.dp)
                    .background(SdkGreen500, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(12.dp))
            }
        } else {
            Spacer(Modifier.size(20.dp))
        }
    }
}
