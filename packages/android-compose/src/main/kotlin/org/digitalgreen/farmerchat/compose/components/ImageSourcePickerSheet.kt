package org.digitalgreen.farmerchat.compose.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.digitalgreen.farmerchat.compose.theme.SdkDarkSurface
import org.digitalgreen.farmerchat.compose.theme.SdkGreen500
import org.digitalgreen.farmerchat.compose.theme.SdkTextMuted
import org.digitalgreen.farmerchat.compose.theme.SdkTextPrimary
import org.digitalgreen.farmerchat.compose.theme.SdkTextSecondary

/**
 * Bottom sheet letting the user choose between camera and gallery for image input.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ImageSourcePickerSheet(
    onDismiss: () -> Unit,
    onCamera: () -> Unit,
    onGallery: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SdkDarkSurface,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                Modifier
                    .width(40.dp)
                    .height(4.dp)
                    .background(SdkTextMuted.copy(alpha = 0.4f), CircleShape)
            )
            Spacer(Modifier.height(20.dp))

            Text("Add Image", color = SdkTextPrimary, fontSize = 18.sp,
                fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text("Photograph your crop for analysis",
                color = SdkTextSecondary, fontSize = 13.sp)
            Spacer(Modifier.height(24.dp))

            // Options
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color(0xFF1E2E1A)),
            ) {
                ImageSourceOption(
                    icon = Icons.Default.CameraAlt,
                    title = "Take Photo",
                    description = "Use your camera to capture the crop",
                    onClick = { onCamera(); onDismiss() },
                )
                Box(Modifier.fillMaxWidth().height(1.dp).background(SdkTextMuted.copy(alpha = 0.1f)))
                ImageSourceOption(
                    icon = Icons.Default.PhotoLibrary,
                    title = "Choose from Gallery",
                    description = "Select an existing photo",
                    onClick = { onGallery(); onDismiss() },
                )
            }

            Spacer(Modifier.height(12.dp))
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Cancel", color = SdkTextMuted, fontSize = 15.sp)
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun ImageSourceOption(
    icon: ImageVector,
    title: String,
    description: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .background(SdkGreen500.copy(alpha = 0.15f), RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = SdkGreen500,
                modifier = Modifier.size(24.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = SdkTextPrimary, fontSize = 15.sp, fontWeight = FontWeight.Medium)
            Text(description, color = SdkTextSecondary, fontSize = 12.sp)
        }
    }
}
