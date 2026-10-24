package com.naneps.spotivibe.model

enum class LyricCardStyle(
    val title: String,
    val subtitle: String,
    val iconName: String
) {
    AURA("Aura", "Blurred ambient glow", "sparkles"),
    PLAYER("Player", "Now Playing card", "play_circle"),
    VHS("VHS 90s", "Camcorder retro vibes", "videocam"),
    CASSETTE("Cassette", "Vintage cassette tape", "album"),
    VINYL("Vinyl", "Spinning record album", "disc"),
    GLASS("Glass", "Frosted glassmorphism", "layers"),
    POLAROID("Polaroid", "Vintage retro frame", "photo_camera"),
    PAPER("Paper", "Editorial serif parchment", "description"),
    RECEIPT("Receipt", "Archive printed receipt", "receipt_long"),
    SOLID("Solid", "Vibrant album color", "crop_square");
}
