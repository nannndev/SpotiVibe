package com.naneps.spotivibe.service

import android.content.Context
import com.naneps.spotivibe.model.Track
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.UUID

class SpotifyPlayerService(private val context: Context) {

    companion object {
        @Volatile
        private var instance: SpotifyPlayerService? = null

        fun getInstance(context: Context): SpotifyPlayerService {
            return instance ?: synchronized(this) {
                instance ?: SpotifyPlayerService(context.applicationContext).also { instance = it }
            }
        }
    }

    private val authService = SpotifyAuthService.getInstance(context)
    private val httpClient = OkHttpClient()
    private val scope = CoroutineScope(Dispatchers.IO)

    private val _currentTrack = MutableStateFlow<Track>(Track.sample)
    val currentTrack = _currentTrack.asStateFlow()

    private val _isPolling = MutableStateFlow(false)
    val isPolling = _isPolling.asStateFlow()

    private var pollJob: Job? = null
    private var lastSyncTime = System.currentTimeMillis()
    private var basePosition = 45.0

    init {
        startPolling()
    }

    fun startPolling() {
        stopPolling()
        pollJob = scope.launch {
            _isPolling.value = true
            while (isActive) {
                pollInternal()
                delay(3000L)
            }
        }
    }

    fun stopPolling() {
        pollJob?.cancel()
        pollJob = null
        _isPolling.value = false
    }

    fun poll() {
        scope.launch { pollInternal() }
    }

    private suspend fun pollInternal() = withContext(Dispatchers.IO) {
        val token = authService.getAccessToken()
        if (token == null || !authService.isAuthenticated.value) {
            // Keep demo sample track
            return@withContext
        }

        val request = Request.Builder()
            .url("https://api.spotify.com/v1/me/player/currently-playing")
            .header("Authorization", "Bearer $token")
            .build()

        try {
            val response = httpClient.newCall(request).execute()
            if (response.code == 204) {
                // No track currently playing
                return@withContext
            }

            if (response.code == 401) {
                authService.refreshAccessToken()
                return@withContext
            }

            val body = response.body?.string() ?: return@withContext
            val json = JSONObject(body)

            if (!json.has("item") || json.isNull("item")) return@withContext

            val item = json.getJSONObject("item")
            val id = item.optString("id", UUID.randomUUID().toString())
            val title = item.optString("name", "Unknown Track")

            val artistsArray = item.optJSONArray("artists")
            val artistList = mutableListOf<String>()
            if (artistsArray != null) {
                for (i in 0 until artistsArray.length()) {
                    artistList.add(artistsArray.getJSONObject(i).optString("name", ""))
                }
            }
            val artists = if (artistList.isNotEmpty()) artistList.joinToString(", ") else "Unknown Artist"

            val albumObj = item.optJSONObject("album")
            val album = albumObj?.optString("name", "") ?: ""

            var artUrl: String? = null
            val images = albumObj?.optJSONArray("images")
            if (images != null && images.length() > 0) {
                val firstImg = images.getJSONObject(0)
                if (firstImg.has("url")) artUrl = firstImg.getString("url")
            }

            val durationMs = item.optLong("duration_ms", 210000L)
            val progressMs = json.optLong("progress_ms", 0L)
            val isPlaying = json.optBoolean("is_playing", false)

            val track = Track(
                id = id,
                title = title,
                artist = artists,
                album = album,
                artworkUrl = artUrl,
                duration = durationMs / 1000.0,
                isPlaying = isPlaying,
                progress = progressMs / 1000.0
            )

            _currentTrack.value = track
            basePosition = progressMs / 1000.0
            lastSyncTime = System.currentTimeMillis()
        } catch (e: Exception) {
            // Silently handle network errors
        }
    }
}
