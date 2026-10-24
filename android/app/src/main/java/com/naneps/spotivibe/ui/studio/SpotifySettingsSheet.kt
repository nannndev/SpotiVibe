package com.naneps.spotivibe.ui.studio

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.naneps.spotivibe.service.SpotifyAuthService
import com.naneps.spotivibe.service.SpotifyPlayerService
import com.naneps.spotivibe.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SpotifySettingsSheet(
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val authService = remember { SpotifyAuthService.getInstance(context) }
    val playerService = remember { SpotifyPlayerService.getInstance(context) }

    val isAuthenticated by authService.isAuthenticated.collectAsState()
    val isAuthenticating by authService.isAuthenticating.collectAsState()
    val errorMessage by authService.errorMessage.collectAsState()
    val clientId by authService.clientId.collectAsState()
    val redirectUri by authService.redirectUri.collectAsState()

    var inputClientId by remember(clientId) { mutableStateOf(clientId) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = SurfaceDark,
        dragHandle = { BottomSheetDefaults.DragHandle(color = Color.White.copy(alpha = 0.3f)) }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Spotify Settings",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp
                )
                TextButton(onClick = onDismiss) {
                    Text("Done", color = AccentPink, fontWeight = FontWeight.Bold)
                }
            }

            // Error Callout if any
            if (errorMessage != null) {
                Spacer(modifier = Modifier.height(8.dp))
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFF2E1712)),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Warning, null, tint = Color(0xFFFF9800), modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Spotify Auth Error", color = Color(0xFFFF9800), fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Spacer(modifier = Modifier.weight(1f))
                            IconButton(onClick = { authService.clearError() }, modifier = Modifier.size(24.dp)) {
                                Icon(Icons.Default.Close, null, tint = TextSecondary, modifier = Modifier.size(16.dp))
                            }
                        }
                        Text(
                            text = errorMessage ?: "",
                            color = Color.White,
                            fontSize = 12.sp,
                            modifier = Modifier.padding(vertical = 4.dp)
                        )
                        Text(
                            text = "💡 Tip: If you see 'Invalid client' or 'User not registered', Spotify requires accounts to either be added to User Management in Developer Dashboard, or you can paste your own Spotify Client ID below.",
                            color = TextSecondary,
                            fontSize = 11.sp
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // 1. Connection Status Card
            Card(
                colors = CardDefaults.cardColors(containerColor = ElevatedDark),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Text("Connection Status", color = TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .clip(RoundedCornerShape(5.dp))
                                .background(if (isAuthenticated) OnlineGreen else Color.Gray)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = if (isAuthenticated) "Connected to Spotify" else "Demo Mode (Sample Data)",
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    if (isAuthenticated) {
                        Button(
                            onClick = {
                                playerService.poll()
                                Toast.makeText(context, "Refreshed currently playing track!", Toast.LENGTH_SHORT).show()
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.12f)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Refresh Currently Playing", color = Color.White, fontSize = 13.sp)
                        }
                        Spacer(modifier = Modifier.height(6.dp))
                        TextButton(
                            onClick = { authService.logout() },
                            modifier = Modifier.align(Alignment.CenterHorizontally)
                        ) {
                            Text("Log Out", color = Color(0xFFFF5252), fontSize = 13.sp)
                        }
                    } else {
                        Button(
                            onClick = { authService.startAuthFlow(context) },
                            enabled = !isAuthenticating,
                            colors = ButtonDefaults.buttonColors(containerColor = SpotifyGreen),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = if (isAuthenticating) "Connecting..." else "Connect Spotify Account",
                                color = Color.Black,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // 2. Client ID Config
            Card(
                colors = CardDefaults.cardColors(containerColor = ElevatedDark),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Text("Spotify Client ID", color = TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedTextField(
                        value = inputClientId,
                        onValueChange = {
                            inputClientId = it
                            authService.setClientId(it)
                        },
                        textStyle = LocalTextStyle.current.copy(
                            color = Color.White,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 13.sp
                        ),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = AccentPink,
                            unfocusedBorderColor = OutlineColor
                        ),
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        TextButton(onClick = {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                            val clipText = clipboard?.primaryClip?.getItemAt(0)?.text?.toString()?.trim()
                            if (!clipText.isNullOrEmpty()) {
                                inputClientId = clipText
                                authService.setClientId(clipText)
                                Toast.makeText(context, "Client ID pasted!", Toast.LENGTH_SHORT).show()
                            }
                        }) {
                            Icon(Icons.Default.ContentPaste, null, tint = AccentPink, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Paste", color = AccentPink, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }

                        TextButton(onClick = {
                            authService.resetToDefaults()
                            inputClientId = SpotifyAuthService.DEFAULT_CLIENT_ID
                            Toast.makeText(context, "Reset to default Client ID!", Toast.LENGTH_SHORT).show()
                        }) {
                            Text("Reset to Default", color = TextSecondary, fontSize = 12.sp)
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Redirect URI", color = TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(modifier = Modifier.height(4.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(6.dp))
                            .background(Color.Black.copy(alpha = 0.3f))
                            .padding(horizontal = 10.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = redirectUri,
                            color = TextSecondary,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 12.sp
                        )
                        IconButton(
                            onClick = {
                                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                                val clip = ClipData.newPlainText("Redirect URI", redirectUri)
                                clipboard?.setPrimaryClip(clip)
                                Toast.makeText(context, "Redirect URI copied!", Toast.LENGTH_SHORT).show()
                            },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(Icons.Default.ContentCopy, null, tint = Color.White, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // 3. Quick Guide
            Card(
                colors = CardDefaults.cardColors(containerColor = ElevatedDark),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Text("How to create your own Spotify App", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    Spacer(modifier = Modifier.height(6.dp))
                    Text("1. Open developer.spotify.com/dashboard", color = TextSecondary, fontSize = 12.sp)
                    Text("2. Click 'Create app' and enter any name (e.g. SpotiVibe)", color = TextSecondary, fontSize = 12.sp)
                    Text("3. Add Redirect URI: opennotchi://spotify-callback", color = TextSecondary, fontSize = 12.sp)
                    Text("4. Select 'Web API' checkbox, then save", color = TextSecondary, fontSize = 12.sp)
                    Text("5. Copy your Client ID and paste it above!", color = TextSecondary, fontSize = 12.sp)
                }
            }

            Spacer(modifier = Modifier.height(28.dp))
        }
    }
}
