package com.naneps.spotivibe.service

import com.naneps.spotivibe.model.LyricLine
import com.naneps.spotivibe.model.Lyrics
import com.naneps.spotivibe.model.Track
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.util.regex.Pattern

class LyricsService private constructor() {

    companion object {
        val shared = LyricsService()
    }

    private val httpClient = OkHttpClient()
    private val cache = mutableMapOf<String, Lyrics>()

    private val _lyrics = MutableStateFlow<Lyrics?>(Lyrics.sample)
    val lyrics = _lyrics.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading = _isLoading.asStateFlow()

    suspend fun fetchLyrics(track: Track) = withContext(Dispatchers.IO) {
        val key = "${track.title}\u0000${track.artist}"
        cache[key]?.let {
            _lyrics.value = it
            return@withContext
        }

        _isLoading.value = true
        try {
            // 1. Try exact match from LRCLIB
            val exactUrl = HttpUrl.Builder()
                .scheme("https")
                .host("lrclib.net")
                .addPathSegment("api")
                .addPathSegment("get")
                .addQueryParameter("track_name", track.title)
                .addQueryParameter("artist_name", track.artist)
                .addQueryParameter("album_name", track.album)
                .addQueryParameter("duration", track.duration.toInt().toString())
                .build()

            val exactRecord = requestLrc(exactUrl)
            if (exactRecord != null) {
                val parsed = parseRecord(exactRecord)
                cache[key] = parsed
                _lyrics.value = parsed
                return@withContext
            }

            // 2. Try looser search from LRCLIB
            val cleanTitle = cleanTitle(track.title)
            val searchUrl = HttpUrl.Builder()
                .scheme("https")
                .host("lrclib.net")
                .addPathSegment("api")
                .addPathSegment("search")
                .addQueryParameter("track_name", cleanTitle)
                .addQueryParameter("artist_name", track.artist)
                .build()

            val searchRecords = requestLrcSearch(searchUrl)
            val best = searchRecords?.firstOrNull { it.optString("syncedLyrics", "").isNotEmpty() }
                ?: searchRecords?.firstOrNull()

            if (best != null) {
                val parsed = parseRecord(best)
                cache[key] = parsed
                _lyrics.value = parsed
                return@withContext
            }

            // Fallback to sample
            _lyrics.value = Lyrics.sample
        } catch (e: Exception) {
            _lyrics.value = Lyrics.sample
        } finally {
            _isLoading.value = false
        }
    }

    private fun cleanTitle(title: String): String {
        var cleaned = title
        val dashIndex = cleaned.indexOf(" - ")
        if (dashIndex != -1) {
            val suffix = cleaned.substring(dashIndex + 3).lowercase()
            if (suffix.contains("remaster") || suffix.contains("live") || suffix.contains("version") ||
                suffix.contains("deluxe") || suffix.contains("edit") || suffix.contains("mix")) {
                cleaned = cleaned.substring(0, dashIndex)
            }
        }
        val pattern = Regex("""\s*[([](feat|ft|with)\.?[^)]*[\)\]]""", RegexOption.IGNORE_CASE)
        return cleaned.replace(pattern, "").trim()
    }

    private fun requestLrc(url: HttpUrl): JSONObject? {
        val request = Request.Builder().url(url).build()
        return try {
            val response = httpClient.newCall(request).execute()
            if (response.isSuccessful) {
                val body = response.body?.string() ?: return null
                JSONObject(body)
            } else null
        } catch (e: Exception) {
            null
        }
    }

    private fun requestLrcSearch(url: HttpUrl): List<JSONObject>? {
        val request = Request.Builder().url(url).build()
        return try {
            val response = httpClient.newCall(request).execute()
            if (response.isSuccessful) {
                val body = response.body?.string() ?: return null
                val array = JSONArray(body)
                val list = mutableListOf<JSONObject>()
                for (i in 0 until array.length()) {
                    list.add(array.getJSONObject(i))
                }
                list
            } else null
        } catch (e: Exception) {
            null
        }
    }

    private fun parseRecord(record: JSONObject): Lyrics {
        val syncedStr = record.optString("syncedLyrics", "")
        val plainStr = record.optString("plainLyrics", "")

        val lines = mutableListOf<LyricLine>()
        if (syncedStr.isNotEmpty()) {
            val rawLines = syncedStr.split("\n")
            val pattern = Pattern.compile("\\[(\\d+):(\\d+(?:\\.\\d+)?)\\]")

            for (raw in rawLines) {
                val matcher = pattern.matcher(raw)
                var lastEnd = 0
                var parsedTime: Double? = null

                while (matcher.find()) {
                    val minutes = matcher.group(1)?.toDoubleOrNull() ?: 0.0
                    val seconds = matcher.group(2)?.toDoubleOrNull() ?: 0.0
                    parsedTime = minutes * 60.0 + seconds
                    lastEnd = matcher.end()
                }

                if (parsedTime != null) {
                    val text = raw.substring(lastEnd).trim()
                    if (text.isNotEmpty()) {
                        lines.add(LyricLine(time = parsedTime, text = text))
                    }
                }
            }
        }

        val plainLines = if (plainStr.isNotEmpty()) {
            plainStr.split("\n").map { it.trim() }.filter { it.isNotEmpty() }
        } else null

        return if (lines.isNotEmpty()) {
            Lyrics(synced = lines, plain = plainLines)
        } else if (!plainLines.isNullOrEmpty()) {
            Lyrics(synced = null, plain = plainLines)
        } else {
            Lyrics.sample
        }
    }
}
