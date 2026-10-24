package com.naneps.spotivibe.model

import java.util.UUID

data class LyricLine(
    val id: String = UUID.randomUUID().toString(),
    val time: Double? = null,
    val text: String
)

data class Lyrics(
    val synced: List<LyricLine>? = null,
    val plain: List<String>? = null
) {
    val allLines: List<String>
        get() {
            synced?.let { if (it.isNotEmpty()) return it.map { line -> line.text } }
            plain?.let { if (it.isNotEmpty()) return it }
            return sampleLines
        }

    companion object {
        private val sampleLines = listOf(
            "Baby, please try to forgive me",
            "Stay here, don't put out the glow",
            "Hold me now, don't bother if every minute it makes me weaker",
            "You can save me from the man that I've become, oh yeah",
            "Looking back on the things I've done",
            "I was trying for the moon and I was shooting for the stars",
            "I'm here to say that I am sorry",
            "From the bottom of my broken heart"
        )

        val sample = Lyrics(
            synced = listOf(
                LyricLine(time = 15.2, text = "Baby, please try to forgive me"),
                LyricLine(time = 22.0, text = "Stay here, don't put out the glow"),
                LyricLine(time = 28.5, text = "Hold me now, don't bother if every minute it makes me weaker"),
                LyricLine(time = 37.1, text = "You can save me from the man that I've become, oh yeah"),
                LyricLine(time = 44.8, text = "Looking back on the things I've done"),
                LyricLine(time = 51.3, text = "I was trying for the moon and I was shooting for the stars"),
                LyricLine(time = 59.0, text = "I'm here to say that I am sorry"),
                LyricLine(time = 66.4, text = "From the bottom of my broken heart")
            )
        )
    }
}
