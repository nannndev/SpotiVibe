package com.naneps.spotivibe

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.naneps.spotivibe.service.SpotifyAuthService
import com.naneps.spotivibe.ui.studio.LyricStudioScreen
import com.naneps.spotivibe.ui.theme.SpotiVibeTheme

class MainActivity : ComponentActivity() {

    private lateinit var authService: SpotifyAuthService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        authService = SpotifyAuthService.getInstance(this)
        handleSpotifyIntent(intent)

        setContent {
            SpotiVibeTheme {
                LyricStudioScreen()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleSpotifyIntent(intent)
    }

    private fun handleSpotifyIntent(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme == "opennotchi" || uri.scheme == "spotivibe") {
            authService.handleCallback(uri)
        }
    }
}
