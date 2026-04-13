package org.digitalgreen.farmerchat.compose.screens

import android.util.Log
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.digitalgreen.farmerchat.compose.network.SupportedLanguage
import org.digitalgreen.farmerchat.compose.network.TokenStore
import org.digitalgreen.farmerchat.compose.theme.SdkDarkBg
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface2
import org.digitalgreen.farmerchat.compose.theme.SdkGreen500
import org.digitalgreen.farmerchat.compose.theme.SdkTextMuted
import org.digitalgreen.farmerchat.compose.theme.SdkTextSecondary
import org.digitalgreen.farmerchat.compose.viewmodel.ChatViewModel

/**
 * Onboarding screen — dark theme.
 *
 * Step 1: Region detected automatically via IP-geolocation (from initialize_user response).
 *         NO live GPS / no location permission requested per WEATHER_GPS_FLOW spec.
 * Step 2: Language selection (2-col grid).
 */
@Composable
internal fun OnboardingScreen(viewModel: ChatViewModel) {
    val languageGroups by viewModel.availableLanguageGroups.collectAsStateWithLifecycle()
    val selectedLanguage by viewModel.selectedLanguage.collectAsStateWithLifecycle()

    val languages: List<SupportedLanguage> = remember(languageGroups) {
        languageGroups.flatMap { it.languages }
    }

    var step by remember { mutableStateOf(1) }
    var langLoadError by remember { mutableStateOf(false) }
    var langLoading by remember { mutableStateOf(false) }

    suspend fun fetchLanguages() {
        if (languages.isNotEmpty()) return
        langLoading = true
        langLoadError = false
        try {
            viewModel.loadLanguages()
        } catch (e: Exception) {
            Log.w("FC.Onboarding", "loadLanguages failed", e)
            langLoadError = true
        } finally {
            langLoading = false
        }
    }

    LaunchedEffect(Unit) { fetchLanguages() }
    LaunchedEffect(step) { if (step == 2) fetchLanguages() }

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
                RegionDetectedStep(onContinue = { step = 2 })
            } else {
                LanguageStep(
                    languages      = languages,
                    selectedCode   = selectedLanguage,
                    isLoading      = langLoading,
                    hasError       = langLoadError && languages.isEmpty(),
                    onLangSelected = { language ->
                        try { viewModel.setPreferredLanguage(language) } catch (e: Exception) {
                            Log.w("FC.Onboarding", "setPreferredLanguage failed", e)
                        }
                    },
                    onRetry = {
                        langLoadError = false
                        langLoading = true
                        try { viewModel.loadLanguages() } catch (_: Exception) {}
                        langLoading = false
                    },
                )
            }

            Spacer(Modifier.weight(1f))
            Spacer(Modifier.height(12.dp))

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

// ── Region detected step (replaces GPS permission step) ───────────────────────

@Composable
private fun RegionDetectedStep(onContinue: () -> Unit) {
    // IP-geolocation from initialize_user — no GPS permission needed
    val country = TokenStore.country.ifBlank { "your region" }
    val state   = TokenStore.state
    val locationLabel = if (state.isNotBlank()) "$state, $country" else country

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .background(SdkDarkSurface, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Default.LocationOn,
                contentDescription = null,
                tint = SdkGreen500,
                modifier = Modifier.size(40.dp),
            )
        }

        Spacer(Modifier.height(20.dp))

        Text(
            text = "Your Region",
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
        )

        Spacer(Modifier.height(8.dp))

        // Show IP-detected region
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .background(SdkDarkSurface2)
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(
                Icons.Default.Check,
                contentDescription = null,
                tint = SdkGreen500,
                modifier = Modifier.size(16.dp),
            )
            Text(
                text = locationLabel,
                color = SdkGreen500,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
            )
        }

        Spacer(Modifier.height(16.dp))

        Text(
            text = "Your region was automatically detected from your network. " +
                   "This helps us recommend farming advice relevant to your area.",
            color = SdkTextSecondary,
            fontSize = 13.sp,
            textAlign = TextAlign.Center,
            lineHeight = 19.sp,
        )
    }
}

// ── Language step ─────────────────────────────────────────────────────────────

@Composable
private fun LanguageStep(
    languages: List<SupportedLanguage>,
    selectedCode: String,
    isLoading: Boolean,
    hasError: Boolean,
    onLangSelected: (SupportedLanguage) -> Unit,
    onRetry: () -> Unit,
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

        if (hasError) {
            Box(modifier = Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Could not load languages", color = SdkTextSecondary, fontSize = 14.sp)
                    Spacer(Modifier.height(12.dp))
                    TextButton(onClick = onRetry) {
                        Text("Retry", color = SdkGreen500)
                    }
                }
            }
            return@Column
        }

        if (isLoading || languages.isEmpty()) {
            LanguageShimmer()
            return@Column
        }

        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            itemsIndexed(languages, key = { _, lang -> lang.id }) { idx, language ->
                LanguageCard(
                    language  = language,
                    isSelected = language.code == selectedCode,
                    animDelay  = idx * 55,
                    onSelect   = { onLangSelected(language) },
                )
            }
        }
    }
}

// ── Language shimmer ──────────────────────────────────────────────────────────

@Composable
private fun LanguageShimmer() {
    val transition = rememberInfiniteTransition(label = "langShimmer")
    val alpha by transition.animateFloat(
        initialValue = 0.08f,
        targetValue  = 0.25f,
        animationSpec = infiniteRepeatable(
            animation  = tween(900),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "shimmerAlpha",
    )
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        repeat(3) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                repeat(2) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(64.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(Color.White.copy(alpha = alpha)),
                    )
                }
            }
        }
    }
}

// ── Language card ─────────────────────────────────────────────────────────────

@Composable
private fun LanguageCard(
    language: SupportedLanguage,
    isSelected: Boolean,
    animDelay: Int = 0,
    onSelect: () -> Unit,
) {
    val bgColor     = if (isSelected) Color(0xFF1A3A0D).copy(alpha = 0.70f)
                      else Color.Black.copy(alpha = 0.40f)
    val borderColor = if (isSelected) SdkGreen500 else Color.White.copy(alpha = 0.12f)
    val borderWidth = if (isSelected) 1.5.dp else 1.dp

    val scale by animateFloatAsState(
        targetValue = if (isSelected) 1.04f else 1.0f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessMedium),
        label = "cardScale",
    )

    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(animDelay.toLong())
        visible = true
    }
    val cardAlpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(durationMillis = 250),
        label = "cardFadeIn",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { scaleX = scale; scaleY = scale; this.alpha = cardAlpha }
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
