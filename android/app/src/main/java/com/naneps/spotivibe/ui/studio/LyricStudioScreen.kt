package com.naneps.spotivibe.ui.studio

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.naneps.spotivibe.model.CardAspectRatio
import com.naneps.spotivibe.model.LyricCardStyle
import com.naneps.spotivibe.service.DirectShareService
import com.naneps.spotivibe.service.LyricsService
import com.naneps.spotivibe.service.SpotifyAuthService
import com.naneps.spotivibe.service.SpotifyPlayerService
import com.naneps.spotivibe.ui.card.LyricCardView
import com.naneps.spotivibe.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class ShareMode(val title: String) {
    PHOTO("Photo"),
    VIDEO("Video")
}

enum class PhotoTarget {
    COVER,
    BACKDROP
}

@Composable
fun LyricStudioScreen(
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val authService = remember { SpotifyAuthService.getInstance(context) }
    val playerService = remember { SpotifyPlayerService.getInstance(context) }
    val lyricsService = remember { LyricsService.shared }
    val shareService = remember { DirectShareService.getInstance(context) }
    // records the live card so Share/Save send the actual card, not the raw photo
    val cardLayer = rememberGraphicsLayer()

    suspend fun renderCard(): Bitmap {
        val captured = cardLayer.toImageBitmap().asAndroidBitmap()
        // shortcut: upscales the on-screen capture to 1080px wide; render offscreen at full size if text looks soft
        val height = (1080f * captured.height / captured.width).toInt()
        return Bitmap.createScaledBitmap(captured.copy(Bitmap.Config.ARGB_8888, false), 1080, height, true)
    }

    val isAuthenticated by authService.isAuthenticated.collectAsState()
    val currentTrack by playerService.currentTrack.collectAsState()
    val lyrics by lyricsService.lyrics.collectAsState()

    var mode by remember { mutableStateOf(ShareMode.PHOTO) }
    var style by remember { mutableStateOf(LyricCardStyle.AURA) }
    var aspectRatio by remember { mutableStateOf(CardAspectRatio.STORY) }
    var selectedRange by remember { mutableStateOf(0..2) }

    var customArtwork by remember { mutableStateOf<Bitmap?>(null) }
    var customBackdrop by remember { mutableStateOf<Bitmap?>(null) }
    var backdropBlur by remember { mutableFloatStateOf(14f) }
    var photoTarget by remember { mutableStateOf(PhotoTarget.BACKDROP) }

    var isPlaying by remember { mutableStateOf(true) }
    var previewElapsed by remember { mutableFloatStateOf(0f) }
    var duration by remember { mutableFloatStateOf(15f) }
    var toastMessage by remember { mutableStateOf<String?>(null) }

    var showLinePickerSheet by remember { mutableStateOf(false) }
    var showSettingsSheet by remember { mutableStateOf(false) }
    var showAspectRatioMenu by remember { mutableStateOf(false) }

    val allLines = lyrics?.allLines ?: listOf("Shape of My Heart")
    val chosenLines = remember(selectedRange, allLines) {
        val safeStart = selectedRange.first.coerceIn(0, (allLines.size - 1).coerceAtLeast(0))
        val safeEnd = selectedRange.last.coerceIn(safeStart, (allLines.size - 1).coerceAtLeast(0))
        if (allLines.isNotEmpty()) allLines.subList(safeStart, safeEnd + 1) else listOf("Sample Lyric")
    }

    // Photo picker launcher
    val photoPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                val inputStream = context.contentResolver.openInputStream(uri)
                val bitmap = BitmapFactory.decodeStream(inputStream)
                if (bitmap != null) {
                    if (photoTarget == PhotoTarget.COVER) {
                        customArtwork = bitmap
                        toastMessage = "Custom cover art applied!"
                    } else {
                        customBackdrop = bitmap
                        toastMessage = "Custom background applied!"
                    }
                }
            }
        }
    }

    // Auto update lyrics on track change
    LaunchedEffect(currentTrack) {
        lyricsService.fetchLyrics(currentTrack)
    }

    // Video preview ticker
    LaunchedEffect(isPlaying, mode) {
        if (mode == ShareMode.VIDEO && isPlaying) {
            while (true) {
                delay(33L)
                previewElapsed += 0.033f
                if (previewElapsed >= duration) {
                    previewElapsed = 0f
                }
            }
        }
    }

    // Active line index calculation
    val activeLineOffset = remember(previewElapsed, duration, chosenLines) {
        if (chosenLines.isEmpty() || duration <= 0) 0
        else ((previewElapsed / duration) * chosenLines.size).toInt().coerceIn(0, chosenLines.size - 1)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(BgDark)
    ) {
        // Ambient glow pulled from artwork
        Box(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .size(420.dp)
                .offset(y = (-180).dp)
                .blur(90.dp)
                .background(AccentPink.copy(alpha = 0.25f), CircleShape)
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            // 1. Top Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.FormatQuote,
                        contentDescription = null,
                        tint = AccentPink,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "SpotiVibe",
                        fontWeight = FontWeight.Black,
                        fontSize = 20.sp,
                        letterSpacing = (-0.4).sp,
                        color = Color.White
                    )
                }

                // Connect Spotify Badge
                Row(
                    modifier = Modifier
                        .clip(CircleShape)
                        .border(1.dp, OutlineColor, CircleShape)
                        .clickable { showSettingsSheet = true }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (isAuthenticated) OnlineGreen else TextSecondary)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (isAuthenticated) "Connected" else "Connect",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            // 2. Track Header Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(ElevatedDark)
                        .shadow(8.dp, RoundedCornerShape(6.dp))
                ) {
                    if (customArtwork != null) {
                        Image(
                            bitmap = customArtwork!!.asImageBitmap(),
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize()
                        )
                    } else if (currentTrack.artworkUrl != null) {
                        AsyncImage(
                            model = currentTrack.artworkUrl,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                }

                Spacer(modifier = Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = currentTrack.title,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        color = Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = currentTrack.artist,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                // Line count button
                Row(
                    modifier = Modifier
                        .clip(CircleShape)
                        .border(1.dp, OutlineColor, CircleShape)
                        .clickable { showLinePickerSheet = true }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.FormatQuote,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "${chosenLines.size} lines",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(6.dp))

            // 3. Toolbar Row (Photo/Video & Aspect Ratio)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    ShareMode.values().forEach { m ->
                        val isSelected = mode == m
                        Box(
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(if (isSelected) Color.White else ElevatedDark)
                                .clickable { mode = m }
                                .padding(horizontal = 14.dp, vertical = 6.dp)
                        ) {
                            Text(
                                text = m.title,
                                color = if (isSelected) Color.Black else Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp
                            )
                        }
                    }
                }

                // Ratio dropdown
                Box {
                    Row(
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(ElevatedDark)
                            .clickable { showAspectRatioMenu = true }
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.AspectRatio, null, tint = Color.White, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(aspectRatio.label, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        Icon(Icons.Default.ArrowDropDown, null, tint = Color.White, modifier = Modifier.size(16.dp))
                    }

                    DropdownMenu(
                        expanded = showAspectRatioMenu,
                        onDismissRequest = { showAspectRatioMenu = false },
                        modifier = Modifier.background(SurfaceDark)
                    ) {
                        CardAspectRatio.values().forEach { r ->
                            DropdownMenuItem(
                                text = { Text(r.label, color = Color.White) },
                                onClick = {
                                    aspectRatio = r
                                    showAspectRatioMenu = false
                                }
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // 4. Live Card Preview Area
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                LyricCardView(
                    track = currentTrack,
                    lines = chosenLines,
                    activeLineIndex = activeLineOffset,
                    style = style,
                    aspectRatio = aspectRatio,
                    customArtwork = customArtwork,
                    customBackdrop = customBackdrop,
                    backdropBlur = backdropBlur,
                    modifier = Modifier
                        .fillMaxHeight(0.92f)
                        .shadow(24.dp, RoundedCornerShape(20.dp))
                        .drawWithContent {
                            cardLayer.record { this@drawWithContent.drawContent() }
                            drawLayer(cardLayer)
                        }
                )

                // Toast Message
                if (toastMessage != null) {
                    Text(
                        text = toastMessage ?: "",
                        color = Color.Black,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = 12.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color.White)
                            .padding(horizontal = 16.dp, vertical = 8.dp)
                    )
                    LaunchedEffect(toastMessage) {
                        delay(2500L)
                        toastMessage = null
                    }
                }
            }

            // 5. Video Timeline Scrubber (if Video mode)
            if (mode == ShareMode.VIDEO) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = { isPlaying = !isPlaying },
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(Color.White)
                    ) {
                        Icon(
                            imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                            contentDescription = null,
                            tint = Color.Black,
                            modifier = Modifier.size(20.dp)
                        )
                    }

                    Spacer(modifier = Modifier.width(10.dp))

                    Slider(
                        value = previewElapsed,
                        onValueChange = { previewElapsed = it },
                        valueRange = 0f..duration,
                        colors = SliderDefaults.colors(
                            thumbColor = Color.White,
                            activeTrackColor = Color.White,
                            inactiveTrackColor = Color.White.copy(alpha = 0.2f)
                        ),
                        modifier = Modifier.weight(1f)
                    )

                    Spacer(modifier = Modifier.width(8.dp))

                    Text(
                        text = "${previewElapsed.toInt()}s / ${duration.toInt()}s",
                        color = TextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            // 6. Bottom Controls Deck
            Card(
                colors = CardDefaults.cardColors(containerColor = SurfaceDark),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Text(
                        text = "Card Style",
                        color = TextSecondary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Style horizontal picker
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(LyricCardStyle.values()) { s ->
                            val isSelected = style == s
                            Box(
                                modifier = Modifier
                                    .clip(CircleShape)
                                    .background(if (isSelected) Color.White else ElevatedDark)
                                    .clickable { style = s }
                                    .padding(horizontal = 14.dp, vertical = 6.dp)
                            ) {
                                Text(
                                    text = s.title,
                                    color = if (isSelected) Color.Black else Color.White,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    // Context controls: Duration or Media
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        if (mode == ShareMode.VIDEO) {
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                listOf(10f, 15f, 30f).forEach { d ->
                                    val isSelected = duration == d
                                    Box(
                                        modifier = Modifier
                                            .clip(CircleShape)
                                            .background(if (isSelected) Color.White else ElevatedDark)
                                            .clickable {
                                                duration = d
                                                if (previewElapsed > d) previewElapsed = 0f
                                            }
                                            .padding(horizontal = 12.dp, vertical = 5.dp)
                                    ) {
                                        Text(
                                            text = "${d.toInt()}s",
                                            color = if (isSelected) Color.Black else Color.White,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 11.sp
                                        )
                                    }
                                }
                            }
                        } else {
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                Box(
                                    modifier = Modifier
                                        .clip(CircleShape)
                                        .background(ElevatedDark)
                                        .clickable {
                                            photoTarget = PhotoTarget.BACKDROP
                                            photoPickerLauncher.launch("image/*")
                                        }
                                        .padding(horizontal = 12.dp, vertical = 5.dp)
                                ) {
                                    Text("Add Background", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                }

                                Box(
                                    modifier = Modifier
                                        .clip(CircleShape)
                                        .background(ElevatedDark)
                                        .clickable {
                                            photoTarget = PhotoTarget.COVER
                                            photoPickerLauncher.launch("image/*")
                                        }
                                        .padding(horizontal = 12.dp, vertical = 5.dp)
                                ) {
                                    Text("Add Artwork", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }

                        if (customBackdrop != null || customArtwork != null) {
                            TextButton(onClick = {
                                customBackdrop = null
                                customArtwork = null
                                toastMessage = "Reset custom media"
                            }) {
                                Text("Reset Media", color = Color(0xFFFF5252), fontSize = 11.sp)
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Action Buttons (Stories, Save, Share)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Instagram Stories Pill Button
                        Button(
                            onClick = {
                                scope.launch {
                                    // Generate sample bitmap representation
                                    val bmp = renderCard()
                                    val shared = shareService.shareToInstagramStories(bmp, context)
                                    if (shared) toastMessage = "Opening Instagram Stories..."
                                }
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
                            contentPadding = PaddingValues(0.dp),
                            modifier = Modifier
                                .weight(1f)
                                .height(48.dp)
                                .clip(CircleShape)
                                .background(BrandGradient)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.CameraAlt, null, tint = Color.White, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Share to Stories", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            }
                        }

                        // Save to Gallery Circle Button
                        IconButton(
                            onClick = {
                                scope.launch {
                                    val bmp = renderCard()
                                    val uri = shareService.saveToGallery(bmp, currentTrack.title)
                                    toastMessage = if (uri != null) "Saved to Gallery!" else "Saved to Photos"
                                }
                            },
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(ElevatedDark)
                        ) {
                            Icon(Icons.Default.Download, null, tint = Color.White, modifier = Modifier.size(20.dp))
                        }

                        // System Share Circle Button
                        IconButton(
                            onClick = {
                                scope.launch {
                                    val bmp = renderCard()
                                    shareService.shareSystem(bmp, context)
                                }
                            },
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(ElevatedDark)
                        ) {
                            Icon(Icons.Default.Share, null, tint = Color.White, modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }
        }

        // Sheets
        if (showLinePickerSheet) {
            LinePickerSheet(
                lines = allLines,
                selectedRange = selectedRange,
                onRangeSelected = { selectedRange = it },
                onDismiss = { showLinePickerSheet = false }
            )
        }

        if (showSettingsSheet) {
            SpotifySettingsSheet(
                onDismiss = { showSettingsSheet = false }
            )
        }
    }
}
