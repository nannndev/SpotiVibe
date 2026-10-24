package com.naneps.spotivibe.model

enum class CardAspectRatio(
    val label: String,
    val widthRatio: Float,
    val heightRatio: Float,
    val exportWidth: Int,
    val exportHeight: Int
) {
    STORY("9:16 Story", 9f, 16f, 1080, 1920),
    PORTRAIT("4:5 Post", 4f, 5f, 1080, 1350),
    SQUARE("1:1 Square", 1f, 1f, 1080, 1080);

    val aspectRatio: Float
        get() = widthRatio / heightRatio
}
