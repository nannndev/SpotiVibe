package com.naneps.spotivibe.ui.card

import android.graphics.Bitmap
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.naneps.spotivibe.model.CardAspectRatio
import com.naneps.spotivibe.model.LyricCardStyle
import com.naneps.spotivibe.model.Track
import com.naneps.spotivibe.ui.theme.AccentOrange
import com.naneps.spotivibe.ui.theme.AccentPink
import com.naneps.spotivibe.ui.theme.ElevatedDark
import com.naneps.spotivibe.ui.theme.SpotifyGreen

@Composable
fun LyricCardView(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int = 0,
    style: LyricCardStyle = LyricCardStyle.AURA,
    aspectRatio: CardAspectRatio = CardAspectRatio.STORY,
    customArtwork: Bitmap? = null,
    customBackdrop: Bitmap? = null,
    backdropBlur: Float = 14f,
    modifier: Modifier = Modifier
) {
    val cardShape = RoundedCornerShape(20.dp)

    Box(
        modifier = modifier
            .aspectRatio(aspectRatio.aspectRatio)
            .clip(cardShape)
            .background(Color(0xFF0F0F14))
    ) {
        // 1. Background Layer
        CardBackground(
            style = style,
            customBackdrop = customBackdrop,
            backdropBlur = backdropBlur
        )

        // 2. Card Content Layout by Style
        when (style) {
            LyricCardStyle.PLAYER -> PlayerCardContent(track, lines, activeLineIndex, customArtwork)
            LyricCardStyle.POLAROID -> PolaroidCardContent(track, lines, activeLineIndex, customArtwork)
            LyricCardStyle.VHS -> VhsCardContent(track, lines, activeLineIndex, customArtwork)
            LyricCardStyle.CASSETTE -> CassetteCardContent(track, lines, activeLineIndex, customArtwork)
            LyricCardStyle.VINYL -> VinylCardContent(track, lines, activeLineIndex, customArtwork)
            LyricCardStyle.GLASS -> GlassCardContent(track, lines, activeLineIndex, customArtwork)
            LyricCardStyle.RECEIPT -> ReceiptCardContent(track, lines, activeLineIndex, customArtwork)
            LyricCardStyle.PAPER -> PaperCardContent(track, lines, activeLineIndex, customArtwork)
            LyricCardStyle.SOLID -> SolidCardContent(track, lines, activeLineIndex, customArtwork)
            LyricCardStyle.AURA -> AuraCardContent(track, lines, activeLineIndex, customArtwork)
        }
    }
}

@Composable
private fun CardBackground(
    style: LyricCardStyle,
    customBackdrop: Bitmap?,
    backdropBlur: Float
) {
    if (customBackdrop != null) {
        Box(modifier = Modifier.fillMaxSize()) {
            Image(
                bitmap = customBackdrop.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .blur(backdropBlur.dp)
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Black.copy(alpha = 0.4f), Color.Black.copy(alpha = 0.8f))
                        )
                    )
            )
        }
    } else {
        when (style) {
            LyricCardStyle.AURA, LyricCardStyle.GLASS -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                listOf(Color(0xFF1E1026), Color(0xFF0A0710))
                            )
                        )
                ) {
                    Box(
                        modifier = Modifier
                            .size(300.dp)
                            .align(Alignment.Center)
                            .blur(70.dp)
                            .background(Brush.radialGradient(listOf(AccentPink.copy(alpha = 0.45f), Color.Transparent)), CircleShape)
                    )
                }
            }
            LyricCardStyle.PLAYER -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                listOf(Color(0xFF181824), Color(0xFF0B0B0F))
                            )
                        )
                )
            }
            LyricCardStyle.VHS -> {
                Box(modifier = Modifier.fillMaxSize().background(Color.Black))
            }
            LyricCardStyle.CASSETTE -> {
                Box(modifier = Modifier.fillMaxSize().background(Color(0xFF141418)))
            }
            LyricCardStyle.VINYL -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                listOf(Color(0xFF1C1B20), Color(0xFF09090C))
                            )
                        )
                )
            }
            LyricCardStyle.POLAROID -> {
                Box(modifier = Modifier.fillMaxSize().background(Color(0xFF18181C)))
            }
            LyricCardStyle.PAPER -> {
                Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF6F3EC)))
            }
            LyricCardStyle.RECEIPT -> {
                Box(modifier = Modifier.fillMaxSize().background(Color(0xFF1F1F24)))
            }
            LyricCardStyle.SOLID -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                listOf(AccentPink, Color(0xFF8A143A))
                            )
                        )
                )
            }
        }
    }
}

// -------------------------------------------------------------
// STYLES IMPLEMENTATION
// -------------------------------------------------------------

@Composable
private fun AuraCardContent(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int,
    customArtwork: Bitmap?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(22.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // Track Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            TrackArtworkThumbnail(track, customArtwork, size = 48)
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = track.title,
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = track.artist,
                    color = Color.White.copy(alpha = 0.65f),
                    fontWeight = FontWeight.Medium,
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Icon(
                imageVector = Icons.Default.GraphicEq,
                contentDescription = null,
                tint = AccentPink,
                modifier = Modifier.size(20.dp)
            )
        }

        // Lyrics Area
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            verticalArrangement = Arrangement.Center
        ) {
            lines.forEachIndexed { index, line ->
                val isActive = index == activeLineIndex
                val textColor by animateColorAsState(
                    targetValue = if (isActive) Color.White else Color.White.copy(alpha = 0.4f),
                    animationSpec = tween(250),
                    label = "textColor"
                )
                Text(
                    text = line,
                    color = textColor,
                    fontWeight = if (isActive) FontWeight.ExtraBold else FontWeight.Bold,
                    fontSize = if (lines.size > 5) 18.sp else 22.sp,
                    lineHeight = if (lines.size > 5) 24.sp else 30.sp,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }
        }

        // Footer Brand
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "SpotiVibe",
                color = Color.White.copy(alpha = 0.4f),
                fontWeight = FontWeight.Bold,
                fontSize = 11.sp,
                letterSpacing = 1.sp
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(SpotifyGreen)
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = "Spotify",
                    color = Color.White.copy(alpha = 0.6f),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

@Composable
private fun PlayerCardContent(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int,
    customArtwork: Bitmap?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.SpaceBetween,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Large Artwork
        TrackArtworkThumbnail(
            track = track,
            customArtwork = customArtwork,
            size = 140,
            cornerRadius = 16
        )

        // Track Info
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = track.title,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                textAlign = TextAlign.Center,
                maxLines = 1
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = track.artist,
                color = Color.White.copy(alpha = 0.6f),
                fontWeight = FontWeight.Medium,
                fontSize = 13.sp,
                textAlign = TextAlign.Center,
                maxLines = 1
            )
        }

        // Focused Lyrics
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(horizontal = 8.dp)
        ) {
            lines.take(4).forEachIndexed { index, line ->
                val isActive = index == activeLineIndex
                Text(
                    text = line,
                    color = if (isActive) AccentPink else Color.White.copy(alpha = 0.5f),
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(vertical = 3.dp)
                )
            }
        }

        // Mock Progress & Playback Controls
        Column(modifier = Modifier.fillMaxWidth()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Color.White.copy(alpha = 0.2f))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.45f)
                        .fillMaxHeight()
                        .background(AccentPink)
                )
            }
            Spacer(modifier = Modifier.height(14.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Default.SkipPrevious, null, tint = Color.White.copy(alpha = 0.7f), modifier = Modifier.size(26.dp))
                Spacer(modifier = Modifier.width(24.dp))
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(Color.White),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.PlayArrow, null, tint = Color.Black, modifier = Modifier.size(26.dp))
                }
                Spacer(modifier = Modifier.width(24.dp))
                Icon(Icons.Default.SkipNext, null, tint = Color.White.copy(alpha = 0.7f), modifier = Modifier.size(26.dp))
            }
        }
    }
}

@Composable
private fun PolaroidCardContent(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int,
    customArtwork: Bitmap?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(18.dp)
            .background(Color(0xFFFAFAFA), RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // Photo area
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .clip(RoundedCornerShape(6.dp))
                .background(Color.Black)
        ) {
            if (customArtwork != null) {
                Image(
                    bitmap = customArtwork.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            } else if (track.artworkUrl != null) {
                AsyncImage(
                    model = track.artworkUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            }

            // Dark gradient overlay for text readability
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color.Black.copy(alpha = 0.8f))
                        )
                    )
            )

            // Overlaid Lyrics
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.Bottom
            ) {
                lines.forEachIndexed { index, line ->
                    val isActive = index == activeLineIndex
                    Text(
                        text = line,
                        color = if (isActive) Color.White else Color.White.copy(alpha = 0.6f),
                        fontWeight = FontWeight.Bold,
                        fontSize = 17.sp,
                        lineHeight = 22.sp
                    )
                }
            }
        }

        // Polaroid Bottom Chin with handwritten feel
        Spacer(modifier = Modifier.height(12.dp))
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = track.title,
                color = Color(0xFF1A1A1A),
                fontWeight = FontWeight.Bold,
                fontSize = 16.sp
            )
            Text(
                text = "${track.artist} — ${track.album}",
                color = Color(0xFF666666),
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
private fun VhsCardContent(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int,
    customArtwork: Bitmap?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // VHS OSD Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "PLAY ▶ SP",
                color = Color(0xFF00FF66),
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp
            )
            Text(
                text = "00:04:22",
                color = Color(0xFF00FF66),
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp
            )
        }

        // Lyrics Area with Retro Neon Font
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            verticalArrangement = Arrangement.Center
        ) {
            lines.forEachIndexed { index, line ->
                val isActive = index == activeLineIndex
                Text(
                    text = line,
                    color = if (isActive) Color.Yellow else Color.White,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 19.sp,
                    lineHeight = 26.sp,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }
        }

        // Footer Track Info
        Column {
            Text(
                text = track.title.uppercase(),
                color = Color.Cyan,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp
            )
            Text(
                text = track.artist.uppercase(),
                color = Color.White.copy(alpha = 0.7f),
                fontFamily = FontFamily.Monospace,
                fontSize = 11.sp
            )
        }
    }
}

@Composable
private fun CassetteCardContent(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int,
    customArtwork: Bitmap?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        // Cassette Shell Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(Color(0xFF23232A))
                .padding(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TrackArtworkThumbnail(track, customArtwork, size = 36, cornerRadius = 6)
            Spacer(modifier = Modifier.width(10.dp))
            Column {
                Text(
                    text = "SIDE A • ${track.title}",
                    color = AccentOrange,
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp
                )
                Text(
                    text = track.artist,
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 11.sp
                )
            }
        }

        // Lyrics
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            verticalArrangement = Arrangement.Center
        ) {
            lines.forEachIndexed { index, line ->
                val isActive = index == activeLineIndex
                Text(
                    text = line,
                    color = if (isActive) AccentOrange else Color.White.copy(alpha = 0.5f),
                    fontWeight = FontWeight.Bold,
                    fontSize = 20.sp,
                    lineHeight = 26.sp,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }
        }

        // Cassette Spools representation
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceAround
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .border(2.dp, Color.White.copy(alpha = 0.3f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Box(modifier = Modifier.size(14.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.5f)))
            }
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .border(2.dp, Color.White.copy(alpha = 0.3f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Box(modifier = Modifier.size(14.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.5f)))
            }
        }
    }
}

@Composable
private fun VinylCardContent(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int,
    customArtwork: Bitmap?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.SpaceBetween,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Vinyl Record
        Box(
            modifier = Modifier
                .size(130.dp)
                .clip(CircleShape)
                .background(Color(0xFF0F0F11))
                .border(2.dp, Color(0xFF2B2B33), CircleShape)
                .shadow(12.dp, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            // Grooves
            Box(modifier = Modifier.size(90.dp).border(1.dp, Color(0xFF222228), CircleShape))
            Box(modifier = Modifier.size(60.dp).border(1.dp, Color(0xFF222228), CircleShape))

            // Center Label Artwork
            TrackArtworkThumbnail(track, customArtwork, size = 48, cornerRadius = 24)
        }

        // Lyrics
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.Center
        ) {
            lines.forEachIndexed { index, line ->
                val isActive = index == activeLineIndex
                Text(
                    text = line,
                    color = if (isActive) Color.White else Color.White.copy(alpha = 0.4f),
                    fontWeight = FontWeight.Bold,
                    fontSize = 20.sp,
                    textAlign = TextAlign.Center,
                    lineHeight = 26.sp,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }
        }

        // Track Details
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(track.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Text(track.artist, color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
        }
    }
}

@Composable
private fun GlassCardContent(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int,
    customArtwork: Bitmap?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(18.dp)
            .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(16.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TrackArtworkThumbnail(track, customArtwork, size = 44)
            Spacer(modifier = Modifier.width(10.dp))
            Column {
                Text(track.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Text(track.artist, color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
            }
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.Center
        ) {
            lines.forEachIndexed { index, line ->
                val isActive = index == activeLineIndex
                Text(
                    text = line,
                    color = if (isActive) Color.White else Color.White.copy(alpha = 0.45f),
                    fontWeight = FontWeight.Bold,
                    fontSize = 21.sp,
                    lineHeight = 28.sp,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }
        }

        Text(
            text = "SpotiVibe Glass",
            color = Color.White.copy(alpha = 0.4f),
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun ReceiptCardContent(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int,
    customArtwork: Bitmap?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .background(Color(0xFFFAFAFA), RoundedCornerShape(4.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            Text("★ SPOTIVIBE ARCHIVE ★", color = Color.Black, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            Text("ORDER #4892 — NOW PLAYING", color = Color.Gray, fontFamily = FontFamily.Monospace, fontSize = 10.sp)
            Spacer(modifier = Modifier.height(6.dp))
            Text("---------------------------------", color = Color.LightGray, fontFamily = FontFamily.Monospace, fontSize = 10.sp)
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.Center
        ) {
            lines.forEachIndexed { index, line ->
                Text(
                    text = line.uppercase(),
                    color = if (index == activeLineIndex) Color.Black else Color(0xFF666666),
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                    modifier = Modifier.padding(vertical = 3.dp)
                )
            }
        }

        Column {
            Text("---------------------------------", color = Color.LightGray, fontFamily = FontFamily.Monospace, fontSize = 10.sp)
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(track.title.uppercase(), color = Color.Black, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                Text("100% OK", color = Color.Black, fontFamily = FontFamily.Monospace, fontSize = 11.sp)
            }
            Text(track.artist.uppercase(), color = Color.Gray, fontFamily = FontFamily.Monospace, fontSize = 10.sp)
        }
    }
}

@Composable
private fun PaperCardContent(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int,
    customArtwork: Bitmap?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(22.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Text("“", color = Color(0xFF1E1E1E), fontSize = 42.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Serif)

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.Center
        ) {
            lines.forEachIndexed { index, line ->
                val isActive = index == activeLineIndex
                Text(
                    text = line,
                    color = if (isActive) Color(0xFF111111) else Color(0xFF6B675E),
                    fontFamily = FontFamily.Serif,
                    fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
                    fontSize = 21.sp,
                    lineHeight = 28.sp,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }
        }

        Column {
            Text(track.title, color = Color(0xFF111111), fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Text(track.artist, color = Color(0xFF777777), fontFamily = FontFamily.Serif, fontSize = 12.sp)
        }
    }
}

@Composable
private fun SolidCardContent(
    track: Track,
    lines: List<String>,
    activeLineIndex: Int,
    customArtwork: Bitmap?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(22.dp),
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TrackArtworkThumbnail(track, customArtwork, size = 44)
            Spacer(modifier = Modifier.width(10.dp))
            Column {
                Text(track.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Text(track.artist, color = Color.White.copy(alpha = 0.7f), fontSize = 12.sp)
            }
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.Center
        ) {
            lines.forEachIndexed { index, line ->
                val isActive = index == activeLineIndex
                Text(
                    text = line,
                    color = if (isActive) Color.White else Color.White.copy(alpha = 0.5f),
                    fontWeight = FontWeight.Black,
                    fontSize = 23.sp,
                    lineHeight = 30.sp,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }
        }

        Text("SpotiVibe", color = Color.White.copy(alpha = 0.5f), fontWeight = FontWeight.Bold, fontSize = 12.sp)
    }
}

@Composable
private fun TrackArtworkThumbnail(
    track: Track,
    customArtwork: Bitmap?,
    size: Int,
    cornerRadius: Int = 8
) {
    val shape = RoundedCornerShape(cornerRadius.dp)
    Box(
        modifier = Modifier
            .size(size.dp)
            .clip(shape)
            .background(ElevatedDark),
        contentAlignment = Alignment.Center
    ) {
        if (customArtwork != null) {
            Image(
                bitmap = customArtwork.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        } else if (track.artworkUrl != null) {
            AsyncImage(
                model = track.artworkUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}
