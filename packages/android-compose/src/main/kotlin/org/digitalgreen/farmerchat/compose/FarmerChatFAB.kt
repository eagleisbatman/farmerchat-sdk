package org.digitalgreen.farmerchat.compose

import android.util.Log
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.digitalgreen.farmerchat.compose.theme.FarmerChatTheme

/**
 * Floating Action Button composable for launching the FarmerChat widget.
 *
 * Wraps itself in [FarmerChatTheme] so colors are always correct regardless
 * of where the host app places it. The [onClick] callback is wrapped in
 * try-catch so the SDK never crashes the host app.
 *
 * @param modifier Modifier applied to the FAB.
 * @param onClick Callback invoked when the FAB is tapped.
 */
@Composable
fun FarmerChatFAB(
    modifier: Modifier = Modifier,
    onClick: () -> Unit = {},
) {
    FarmerChatTheme {
        FloatingActionButton(
            onClick = {
                try {
                    onClick()
                } catch (e: Exception) {
                    Log.e("FarmerChat", "FAB click error", e)
                }
            },
            modifier = modifier
                .padding(16.dp)
                .size(56.dp),
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary,
            shape = CircleShape,
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.Chat,
                contentDescription = "Open FarmerChat",
                modifier = Modifier.size(24.dp),
            )
        }
    }
}
