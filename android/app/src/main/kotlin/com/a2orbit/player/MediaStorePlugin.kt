package com.a2orbit.player

import android.content.ContentResolver
import android.content.Context
import android.database.Cursor
import android.os.Build
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class MediaStorePlugin : MethodCallHandler {
    private lateinit var context: Context
    private lateinit var contentResolver: ContentResolver

    companion object {
        const val CHANNEL = "a2orbit_player/mediastore"
        
        fun setup(activity: FlutterActivity, flutterEngine: FlutterEngine) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            val plugin = MediaStorePlugin()
            plugin.context = activity
            plugin.contentResolver = activity.contentResolver
            channel.setMethodCallHandler(plugin)
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "scanVideoFolders" -> {
                try {
                    val folders = scanVideoFolders()
                    result.success(folders)
                } catch (e: Exception) {
                    result.error("SCAN_ERROR", e.message, null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun scanVideoFolders(): List<Map<String, Any?>> {
        val folders = mutableMapOf<String, MutableList<Map<String, Any?>>>()
        
        try {
            val uri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            val projection = arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DATA,
                MediaStore.Video.Media.RELATIVE_PATH,
                MediaStore.Video.Media.BUCKET_ID,
                MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
                MediaStore.Video.Media.MIME_TYPE,
                MediaStore.Video.Media.SIZE,
                MediaStore.Video.Media.DATE_MODIFIED
            )

            // Build selection for supported video formats
            val selection = buildSelection()
            val sortOrder = "${MediaStore.Video.Media.BUCKET_DISPLAY_NAME} ASC, ${MediaStore.Video.Media.DISPLAY_NAME} ASC"

            val cursor: Cursor? = contentResolver.query(
                uri,
                projection,
                selection,
                null,
                sortOrder
            )

            cursor?.use { c ->
                while (c.moveToNext()) {
                    try {
                        val dataIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
                        val bucketIdIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.BUCKET_ID)
                        val bucketNameIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.BUCKET_DISPLAY_NAME)

                        val data = c.getString(dataIndex)
                        val bucketId = c.getString(bucketIdIndex)
                        val bucketName = c.getString(bucketNameIndex)

                        if (data != null && bucketId != null && bucketName != null) {
                            val file = File(data)
                            
                            // Verify file exists and is a video
                            if (file.exists() && isVideoFile(file.absolutePath)) {
                                // Use bucket path as key (folder path)
                                val folderPath = file.parent ?: continue
                                
                                if (!folders.containsKey(folderPath)) {
                                    folders[folderPath] = mutableListOf()
                                }
                                
                                folders[folderPath]?.add(mapOf(
                                    "path" to data,
                                    "bucketPath" to folderPath,
                                    "bucketName" to bucketName,
                                    "size" to c.getLong(c.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)),
                                    "dateModified" to c.getLong(c.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_MODIFIED))
                                ))
                            }
                        }
                    } catch (e: Exception) {
                        // Skip problematic entries
                        continue
                    }
                }
            }
        } catch (e: Exception) {
            // Log error but continue with empty result
        }

        // Convert to list of maps for Flutter
        return folders.flatMap { entry ->
            entry.value.map { video ->
                mapOf(
                    "path" to video["path"],
                    "bucketPath" to video["bucketPath"],
                    "bucketName" to video["bucketName"]
                )
            }
        }.groupBy({ it["bucketPath"] as String })
         .mapValues { entry ->
             entry.value.map { video ->
                 mapOf(
                     "path" to video["path"],
                     "bucketPath" to video["bucketPath"],
                     "bucketName" to video["bucketName"]
                 )
             }
         }
         .values
         .flatten()
    }

    private fun buildSelection(): String {
        val supportedFormats = listOf(
            "video/mp4", "video/mkv", "video/avi", "video/mov",
            "video/wmv", "video/flv", "video/webm", "video/m4v",
            "video/3gp", "video/ogv", "video/ts", "video/mts",
            "video/m2ts"
        )
        
        return supportedFormats.map { "${MediaStore.Video.Media.MIME_TYPE} = ?" }
            .joinToString(" OR ")
    }

    private fun isVideoFile(filePath: String): Boolean {
        val extension = File(filePath).extension.lowercase()
        val supportedExtensions = setOf(
            "mp4", "mkv", "avi", "mov", "wmv", "flv", 
            "webm", "m4v", "3gp", "ogv", "ts", "mts", "m2ts"
        )
        return supportedExtensions.contains(extension)
    }
}
