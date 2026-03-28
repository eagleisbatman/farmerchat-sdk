package org.digitalgreen.farmerchat.compose.screens

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.digitalgreen.farmerchat.compose.viewmodel.ChatViewModel

/**
 * Onboarding screen for location + language selection.
 * Two steps: 1) Grant location permission, 2) Pick language.
 */
@Composable
internal fun OnboardingScreen(viewModel: ChatViewModel) {
    val languages by viewModel.availableLanguages.collectAsStateWithLifecycle()
    var selectedLang by remember { mutableStateOf("") }
    var step by remember { mutableIntStateOf(1) }
    var lat by remember { mutableDoubleStateOf(0.0) }
    var lng by remember { mutableDoubleStateOf(0.0) }
    var locationGranted by remember { mutableStateOf(false) }

    val context = LocalContext.current

    // Check if location permission is already granted
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
            if (granted) {
                // Move to language step on grant
                step = 2
            }
        } catch (e: Exception) {
            Log.w("FC.Onboarding", "Permission result handling failed", e)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(48.dp))

        Text(
            text = "Welcome to FarmerChat",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(8.dp))

        Text(
            text = if (step == 1) "Step 1 of 2: Share your location"
            else "Step 2 of 2: Choose your language",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(32.dp))

        if (step == 1) {
            // ── Location step ───────────────────────────────────
            LocationStep(
                locationGranted = locationGranted,
                onRequestPermission = {
                    try {
                        permissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                    } catch (e: Exception) {
                        Log.w("FC.Onboarding", "Permission launch failed", e)
                    }
                },
                onSkip = {
                    try {
                        step = 2
                    } catch (e: Exception) {
                        Log.w("FC.Onboarding", "Skip location failed", e)
                    }
                },
                onContinue = {
                    try {
                        step = 2
                    } catch (e: Exception) {
                        Log.w("FC.Onboarding", "Continue from location failed", e)
                    }
                },
            )
        } else {
            // ── Language step ────────────────────────────────────
            LanguageStep(
                languages = languages,
                selectedLang = selectedLang,
                onLangSelected = { selectedLang = it },
            )
        }

        Spacer(Modifier.weight(1f))

        // Continue / Finish button
        Button(
            onClick = {
                try {
                    if (step == 1) {
                        step = 2
                    } else if (selectedLang.isNotEmpty()) {
                        viewModel.completeOnboarding(lat, lng, selectedLang)
                    }
                } catch (e: Exception) {
                    Log.w("FC.Onboarding", "Continue button failed", e)
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = step == 1 || selectedLang.isNotEmpty(),
        ) {
            Text(
                text = if (step == 1) "Continue" else "Get Started",
                style = MaterialTheme.typography.labelLarge,
            )
        }

        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun LocationStep(
    locationGranted: Boolean,
    onRequestPermission: () -> Unit,
    onSkip: () -> Unit,
    onContinue: () -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Icon(
            Icons.Default.LocationOn,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.primary,
        )

        Spacer(Modifier.height(16.dp))

        Text(
            text = "Share your location so we can provide farming advice relevant to your area.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 16.dp),
        )

        Spacer(Modifier.height(24.dp))

        if (locationGranted) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = "Location permission granted",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        } else {
            OutlinedButton(
                onClick = onRequestPermission,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(
                    Icons.Default.LocationOn,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text("Share Location")
            }

            Spacer(Modifier.height(12.dp))

            Text(
                text = "Skip for now",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .clickable(onClick = onSkip)
                    .padding(8.dp),
            )
        }
    }
}

@Composable
private fun LanguageStep(
    languages: List<org.digitalgreen.farmerchat.compose.network.LanguageResponse>,
    selectedLang: String,
    onLangSelected: (String) -> Unit,
) {
    if (languages.isEmpty()) {
        Text(
            text = "Loading languages\u2026",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        return
    }

    LazyColumn(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(languages, key = { it.code }) { language ->
            val isSelected = language.code == selectedLang
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onLangSelected(language.code) },
                colors = CardDefaults.cardColors(
                    containerColor = if (isSelected) {
                        MaterialTheme.colorScheme.primaryContainer
                    } else {
                        MaterialTheme.colorScheme.surface
                    },
                ),
                border = if (isSelected) {
                    BorderStroke(2.dp, MaterialTheme.colorScheme.primary)
                } else {
                    BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                },
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column {
                        Text(
                            text = language.nativeName,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            color = if (isSelected) {
                                MaterialTheme.colorScheme.onPrimaryContainer
                            } else {
                                MaterialTheme.colorScheme.onSurface
                            },
                        )
                        Text(
                            text = language.name,
                            style = MaterialTheme.typography.bodySmall,
                            color = if (isSelected) {
                                MaterialTheme.colorScheme.onPrimaryContainer
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            },
                        )
                    }
                    if (isSelected) {
                        Icon(
                            Icons.Default.Check,
                            contentDescription = "Selected",
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }
        }
    }
}
