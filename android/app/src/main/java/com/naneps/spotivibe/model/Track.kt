package com.naneps.spotivibe.model

import java.util.UUID

data class Track(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val artist: String,
    val album: String = "",
    val artworkUrl: String? = null,
    val duration: Double = 210.0, // in seconds
    val isPlaying: Boolean = false,
    val progress: Double = 0.0 // in seconds
) {
    companion object {
        val sample = Track(
            id = "sample-1",
            title = "Shape of My Heart",
            artist = "Backstreet Boys",
            album = "Black & Blue",
            artworkUrl = "https://i.scdn.co/image/ab67616d0000b273cf871e6326e334bfa92cff20",
            duration = 230.0,
            isPlaying = true,
            progress = 45.0
        )

        val sampleGoldenHour = Track(
            id = "sample-2",
            title = "golden hour",
            artist = "JVKE",
            album = "this is what ____ feels like (Vol. 1-4)",
            artworkUrl = "https://i.scdn.co/image/ab67616d0000b273c2504e80ba2f258697ab2954",
            duration = 209.0,
            isPlaying = true,
            progress = 68.0
        )
    }
}
