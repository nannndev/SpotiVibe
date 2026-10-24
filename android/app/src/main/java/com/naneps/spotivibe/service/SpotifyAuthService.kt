package com.naneps.spotivibe.service

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Base64
import androidx.browser.customtabs.CustomTabsIntent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.security.MessageDigest
import java.security.SecureRandom

class SpotifyAuthService(private val context: Context) {

    companion object {
        const val DEFAULT_CLIENT_ID = "9e2d96c8642b4f4fa2274d95cc5ef0da"
        const val DEFAULT_REDIRECT_URI = "opennotchi://spotify-callback"

        private const val PREFS_NAME = "spotivibe_spotify_prefs"
        private const val KEY_CLIENT_ID = "spotify_client_id"
        private const val KEY_REDIRECT_URI = "spotify_redirect_uri"
        private const val KEY_ACCESS_TOKEN = "spotify_access_token"
        private const val KEY_REFRESH_TOKEN = "spotify_refresh_token"
        private const val KEY_TOKEN_EXPIRY = "spotify_token_expiry"

        @Volatile
        private var instance: SpotifyAuthService? = null

        fun getInstance(context: Context): SpotifyAuthService {
            return instance ?: synchronized(this) {
                instance ?: SpotifyAuthService(context.applicationContext).also { instance = it }
            }
        }
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val httpClient = OkHttpClient()
    private val scope = CoroutineScope(Dispatchers.IO)

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated = _isAuthenticated.asStateFlow()

    private val _isAuthenticating = MutableStateFlow(false)
    val isAuthenticating = _isAuthenticating.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage = _errorMessage.asStateFlow()

    private val _clientId = MutableStateFlow(loadClientId())
    val clientId = _clientId.asStateFlow()

    private val _redirectUri = MutableStateFlow(loadRedirectUri())
    val redirectUri = _redirectUri.asStateFlow()

    private var codeVerifier: String? = null

    init {
        loadStoredToken()
    }

    private fun loadClientId(): String {
        val stored = prefs.getString(KEY_CLIENT_ID, null)?.trim()
        return if (!stored.isNullOrEmpty() && !stored.contains("your_spotify")) {
            stored
        } else {
            DEFAULT_CLIENT_ID
        }
    }

    private fun loadRedirectUri(): String {
        val stored = prefs.getString(KEY_REDIRECT_URI, null)?.trim()
        return if (!stored.isNullOrEmpty()) stored else DEFAULT_REDIRECT_URI
    }

    fun setClientId(newId: String) {
        val clean = newId.trim()
        _clientId.value = clean
        prefs.edit().putString(KEY_CLIENT_ID, clean).apply()
    }

    fun resetToDefaults() {
        _clientId.value = DEFAULT_CLIENT_ID
        _redirectUri.value = DEFAULT_REDIRECT_URI
        prefs.edit()
            .putString(KEY_CLIENT_ID, DEFAULT_CLIENT_ID)
            .putString(KEY_REDIRECT_URI, DEFAULT_REDIRECT_URI)
            .apply()
        logout()
    }

    fun clearError() {
        _errorMessage.value = null
    }

    fun getAccessToken(): String? {
        val token = prefs.getString(KEY_ACCESS_TOKEN, null)
        val expiry = prefs.getLong(KEY_TOKEN_EXPIRY, 0L)
        if (token != null && System.currentTimeMillis() < expiry) {
            return token
        }
        return null
    }

    private fun loadStoredToken() {
        val token = prefs.getString(KEY_ACCESS_TOKEN, null)
        val expiry = prefs.getLong(KEY_TOKEN_EXPIRY, 0L)
        if (token != null && System.currentTimeMillis() < expiry) {
            _isAuthenticated.value = true
        } else if (prefs.getString(KEY_REFRESH_TOKEN, null) != null) {
            scope.launch { refreshAccessToken() }
        }
    }

    fun startAuthFlow(activityContext: Context) {
        val cleanId = _clientId.value.trim()
        if (cleanId.isEmpty()) {
            _errorMessage.value = "Please enter a valid Spotify Client ID"
            return
        }

        _errorMessage.value = null
        val verifier = generateCodeVerifier()
        codeVerifier = verifier
        val challenge = generateCodeChallenge(verifier)

        val authUrl = Uri.parse("https://accounts.spotify.com/authorize").buildUpon()
            .appendQueryParameter("client_id", cleanId)
            .appendQueryParameter("response_type", "code")
            .appendQueryParameter("redirect_uri", _redirectUri.value)
            .appendQueryParameter("code_challenge_method", "S256")
            .appendQueryParameter("code_challenge", challenge)
            .appendQueryParameter("scope", "user-read-currently-playing user-read-playback-state")
            .build()

        _isAuthenticating.value = true

        try {
            val customTabsIntent = CustomTabsIntent.Builder().build()
            customTabsIntent.launchUrl(activityContext, authUrl)
        } catch (e: Exception) {
            val fallback = Intent(Intent.ACTION_VIEW, authUrl).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activityContext.startActivity(fallback)
        }
    }

    fun handleCallback(uri: Uri?) {
        _isAuthenticating.value = false
        if (uri == null) return

        val error = uri.getQueryParameter("error")
        if (error != null) {
            _errorMessage.value = "Spotify error: $error"
            return
        }

        val code = uri.getQueryParameter("code")
        if (code != null) {
            scope.launch {
                exchangeCodeForToken(code)
            }
        }
    }

    private suspend fun exchangeCodeForToken(code: String) = withContext(Dispatchers.IO) {
        val verifier = codeVerifier ?: return@withContext
        val cleanId = _clientId.value.trim()

        val requestBody = FormBody.Builder()
            .add("client_id", cleanId)
            .add("grant_type", "authorization_code")
            .add("code", code)
            .add("redirect_uri", _redirectUri.value)
            .add("code_verifier", verifier)
            .build()

        val request = Request.Builder()
            .url("https://accounts.spotify.com/api/token")
            .post(requestBody)
            .build()

        try {
            val response = httpClient.newCall(request).execute()
            val body = response.body?.string() ?: ""
            val json = JSONObject(body)

            if (json.has("error_description")) {
                _errorMessage.value = json.getString("error_description")
                return@withContext
            }

            if (json.has("access_token")) {
                val token = json.getString("access_token")
                val expiresInSec = json.optLong("expires_in", 3600L)
                val expiryMillis = System.currentTimeMillis() + (expiresInSec * 1000L)

                val editor = prefs.edit()
                    .putString(KEY_ACCESS_TOKEN, token)
                    .putLong(KEY_TOKEN_EXPIRY, expiryMillis)

                if (json.has("refresh_token")) {
                    editor.putString(KEY_REFRESH_TOKEN, json.getString("refresh_token"))
                }
                editor.apply()

                _isAuthenticated.value = true
                SpotifyPlayerService.getInstance(context).poll()
            }
        } catch (e: Exception) {
            _errorMessage.value = e.localizedMessage ?: "Failed to connect to Spotify"
        }
    }

    suspend fun refreshAccessToken() = withContext(Dispatchers.IO) {
        val refreshToken = prefs.getString(KEY_REFRESH_TOKEN, null) ?: return@withContext
        val cleanId = _clientId.value.trim()

        val requestBody = FormBody.Builder()
            .add("client_id", cleanId)
            .add("grant_type", "refresh_token")
            .add("refresh_token", refreshToken)
            .build()

        val request = Request.Builder()
            .url("https://accounts.spotify.com/api/token")
            .post(requestBody)
            .build()

        try {
            val response = httpClient.newCall(request).execute()
            val body = response.body?.string() ?: ""
            val json = JSONObject(body)

            if (json.has("access_token")) {
                val token = json.getString("access_token")
                val expiresInSec = json.optLong("expires_in", 3600L)
                val expiryMillis = System.currentTimeMillis() + (expiresInSec * 1000L)

                prefs.edit()
                    .putString(KEY_ACCESS_TOKEN, token)
                    .putLong(KEY_TOKEN_EXPIRY, expiryMillis)
                    .apply()

                _isAuthenticated.value = true
            }
        } catch (e: Exception) {
            // Silently ignore or retry
        }
    }

    fun logout() {
        prefs.edit()
            .remove(KEY_ACCESS_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .remove(KEY_TOKEN_EXPIRY)
            .apply()
        _isAuthenticated.value = false
    }

    private fun generateCodeVerifier(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    private fun generateCodeChallenge(verifier: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(verifier.toByteArray(Charsets.US_ASCII))
        return Base64.encodeToString(hash, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }
}
