package com.naneps.spotivibe.service

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

class DirectShareService(private val context: Context) {

    companion object {
        @Volatile
        private var instance: DirectShareService? = null

        fun getInstance(context: Context): DirectShareService {
            return instance ?: synchronized(this) {
                instance ?: DirectShareService(context.applicationContext).also { instance = it }
            }
        }
    }

    suspend fun saveToGallery(bitmap: Bitmap, title: String): Uri? = withContext(Dispatchers.IO) {
        val fileName = "SpotiVibe_${System.currentTimeMillis()}.png"
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/SpotiVibe")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val resolver = context.contentResolver
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

        val itemUri = resolver.insert(collection, values) ?: return@withContext null

        try {
            resolver.openOutputStream(itemUri)?.use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(itemUri, values, null, null)
            }
            itemUri
        } catch (e: Exception) {
            resolver.delete(itemUri, null, null)
            null
        }
    }

    suspend fun shareToInstagramStories(bitmap: Bitmap, activityContext: Context): Boolean = withContext(Dispatchers.IO) {
        val cachedUri = saveBitmapToCache(bitmap) ?: return@withContext false

        val instagramIntent = Intent("com.instagram.share.ADD_TO_STORY").apply {
            setDataAndType(cachedUri, "image/png")
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("interactive_asset_uri", cachedUri)
            putExtra("content_url", "https://open.spotify.com")
            putExtra("top_background_color", "#121212")
            putExtra("bottom_background_color", "#121212")
            setPackage("com.instagram.android")
        }

        val packageManager = activityContext.packageManager
        val canHandle = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                instagramIntent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
            ).isNotEmpty()
        } else {
            packageManager.queryIntentActivities(instagramIntent, PackageManager.MATCH_DEFAULT_ONLY).isNotEmpty()
        }

        if (canHandle) {
            activityContext.startActivity(instagramIntent)
            true
        } else {
            // Fallback to system share
            withContext(Dispatchers.Main) {
                shareSystem(bitmap, activityContext)
            }
            false
        }
    }

    suspend fun shareSystem(bitmap: Bitmap, activityContext: Context) = withContext(Dispatchers.IO) {
        val cachedUri = saveBitmapToCache(bitmap) ?: return@withContext

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, cachedUri)
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
        }

        val chooser = Intent.createChooser(shareIntent, "Share Lyric Card").apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        activityContext.startActivity(chooser)
    }

    private fun saveBitmapToCache(bitmap: Bitmap): Uri? {
        val cacheFolder = File(context.cacheDir, "shared_cards").apply { mkdirs() }
        val file = File(cacheFolder, "spotivibe_share_${System.currentTimeMillis()}.png")

        return try {
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        } catch (e: Exception) {
            null
        }
    }
}
