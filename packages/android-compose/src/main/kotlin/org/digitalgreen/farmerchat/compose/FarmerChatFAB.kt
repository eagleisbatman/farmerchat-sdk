package org.digitalgreen.farmerchat.compose

import android.util.Log
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.FloatingActionButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.digitalgreen.farmerchat.compose.theme.FarmerChatTheme
import org.digitalgreen.farmerchat.compose.theme.SdkGreen800

/**
 * Floating Action Button that launches the FarmerChat widget.
 *
 * Spec (from UI guide):
 *  - 56dp circle, bg #2E7D32 (PRIMARY_GREEN), elevation 6dp
 *  - Emoji 💬 as label
 *
 * Wrapped in [FarmerChatTheme] so colors are always correct.
 * [onClick] is wrapped in try-catch so the SDK never crashes the host app.
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
            modifier       = modifier.size(56.dp),
            containerColor = SdkGreen800,
            contentColor   = Color.White,
            shape          = CircleShape,
            elevation      = FloatingActionButtonDefaults.elevation(
                defaultElevation  = 6.dp,
                pressedElevation  = 8.dp,
            ),
        ) {
            Text("💬", fontSize = 24.sp)
        }
    }
}
