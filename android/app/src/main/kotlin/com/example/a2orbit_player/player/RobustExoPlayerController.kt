package com.example.a2orbit_player.player

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.Point
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import android.webkit.MimeTypeMap
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.net.toFile
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.FileDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.PlayerView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import kotlin.math.max
import kotlin.math.min

/**
 * Robust ExoPlayer Controller with proper URI handling, MIME type detection,
 * and comprehensive error handling for all Android 10-14 devices.
 */
@OptIn(UnstableApi::class)
class RobustExoPlayerController(
    private val context: Context,
    private val activity: Activity?,
    private val lifecycleOwner: LifecycleOwner?,
) : Player.Listener, DefaultLifecycleObserver {

    companion object {
        private const val TAG = "RobustExoPlayerController"
        
        // Supported video formats and their MIME types
        private val VIDEO_MIME_TYPES = mapOf(
            "mp4" to "video/mp4",
            "m4v" to "video/mp4",
            "mkv" to "video/x-matroska",
            "avi" to "video/x-msvideo",
            "mov" to "video/quicktime",
            "wmv" to "video/x-ms-wmv",
            "flv" to "video/x-flv",
            "webm" to "video/webm",
            "ts" to "video/mp2t",
            "mts" to "video/mp2t",
            "m2ts" to "video/mp2t",
            "3gp" to "video/3gpp",
            "ogv" to "video/ogg"
        )
    }

    private val mainScope = CoroutineScope(Dispatchers.Main + Job())
    private val appContext = context.applicationContext

    // ExoPlayer components
    private val trackSelector = DefaultTrackSelector(context)
    private val dataSourceFactory = DefaultDataSource.Factory(context)
    private val httpDataSourceFactory = DefaultHttpDataSource.Factory()
    
    val player: ExoPlayer = ExoPlayer.Builder(context)
        .setTrackSelector(trackSelector)
        .build()

    private var playerView: PlayerView? = null
    private var currentMediaItem: MediaItem? = null
    private var currentUri: Uri? = null
    private var reportingJob: Job? = null
    private var initializationAttempts = 0
    private val maxInitializationAttempts = 3

    // Event flow for communication with Flutter
    private val _events = MutableSharedFlow<PlayerEvent>(extraBufferCapacity = 32)
    val events: SharedFlow<PlayerEvent> = _events

    // Gesture control state
    private var brightnessBeforeGesture: Float = -1f
    private var volumeBeforeGesture: Int = 0
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
    private val maxVolume = audioManager?.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC) ?: 15
    private var pendingSeekPosition: Long? = null

    init {
        player.addListener(this)
        lifecycleOwner?.lifecycle?.addObserver(this)
        Log.d(TAG, "RobustExoPlayerController initialized")
    }

    /**
     * Attach PlayerView for surface rendering
     */
    fun attachPlayerView(view: PlayerView) {
        playerView = view
        view.player = player
        view.useController = false // We use custom controls
        playerView?.resizeMode = androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FIT
        Log.d(TAG, "PlayerView attached to ExoPlayer")
    }

    /**
     * Set video source with robust URI handling and MIME type detection
     */
    fun setVideoSource(videoPath: String, subtitlePaths: List<String> = emptyList()) {
        Log.d(TAG, "Setting video source: $videoPath")
        
        if (videoPath.isBlank()) {
            emitError("INVALID_SOURCE", "Video path is empty")
            return
        }

        // Check permissions first
        if (!hasStoragePermission()) {
            emitError("PERMISSION_DENIED", "Storage permission is required to play this file")
            return
        }

        // Resolve URI with fallback strategies
        val resolvedUri = resolveVideoUri(videoPath)
        if (resolvedUri == null) {
            emitError("URI_RESOLUTION_FAILED", "Unable to resolve URI for: $videoPath")
            return
        }

        currentUri = resolvedUri
        initializationAttempts = 0
        
        // Initialize with proper error handling
        initializePlayback(resolvedUri, videoPath, subtitlePaths)
    }

    /**
     * Initialize playback with multiple fallback strategies
     */
    private fun initializePlayback(uri: Uri, originalPath: String, subtitlePaths: List<String>) {
        if (initializationAttempts >= maxInitializationAttempts) {
            emitError("INITIALIZATION_FAILED", "Failed to initialize player after $maxInitializationAttempts attempts")
            return
        }

        initializationAttempts++
        Log.d(TAG, "Initialization attempt $initializationAttempts for URI: $uri")

        try {
            // Detect MIME type
            val mimeType = detectMimeType(uri, originalPath)
            if (mimeType == null) {
                emitError("MIME_TYPE_UNKNOWN", "Unable to determine MIME type for: $originalPath")
                return
            }

            Log.d(TAG, "Detected MIME type: $mimeType for URI: $uri")

            // Grant URI permissions
            grantUriPermissions(uri)

            // Build MediaItem with explicit MIME type
            val mediaItemBuilder = MediaItem.Builder()
                .setUri(uri)
                .setMediaId(originalPath)
                .setMimeType(mimeType)

            // Add metadata
            val file = File(originalPath)
            if (file.exists()) {
                val metadata = MediaMetadata.Builder()
                    .setTitle(file.nameWithoutExtension)
                    .setDisplayTitle(file.name)
                    .build()
                mediaItemBuilder.setMediaMetadata(metadata)
            }

            // Add subtitles if provided
            if (subtitlePaths.isNotEmpty()) {
                val subtitleConfigs = subtitlePaths.mapNotNull { subtitlePath ->
                    createSubtitleConfiguration(subtitlePath)
                }
                mediaItemBuilder.setSubtitleConfigurations(subtitleConfigs)
            }

            val mediaItem = mediaItemBuilder.build()
            currentMediaItem = mediaItem

            // Create MediaSource with fallback
            val mediaSource = createMediaSource(mediaItem, mimeType)
            
            // Set up player
            player.setMediaSource(mediaSource)
            player.prepare()
            
            Log.d(TAG, "Player prepared successfully for: $uri")

        } catch (e: Exception) {
            Log.e(TAG, "Error during initialization attempt $initializationAttempts", e)
            
            // Try fallback strategies
            when {
                initializationAttempts == 1 && uri.scheme == "file" -> {
                    // Try FileProvider fallback
                    val fileProviderUri = createFileProviderUri(File(uri.path ?: return))
                    if (fileProviderUri != null) {
                        initializePlayback(fileProviderUri, originalPath, subtitlePaths)
                    } else {
                        emitError("FALLBACK_FAILED", "FileProvider fallback failed: ${e.message}")
                    }
                }
                initializationAttempts == 2 -> {
                    // Try MediaStore lookup
                    val mediaStoreUri = findMediaStoreUri(File(originalPath))
                    if (mediaStoreUri != null) {
                        initializePlayback(mediaStoreUri, originalPath, subtitlePaths)
                    } else {
                        emitError("MEDIASTORE_FAILED", "MediaStore lookup failed: ${e.message}")
                    }
                }
                else -> {
                    emitError("INITIALIZATION_ERROR", "Initialization failed: ${e.message}")
                }
            }
        }
    }

    /**
     * Create MediaSource with appropriate factory
     */
    private fun createMediaSource(mediaItem: MediaItem, mimeType: String): MediaSource {
        return try {
            when {
                mimeType.startsWith("video/") -> {
                    ProgressiveMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
                }
                else -> {
                    // Fallback to default
                    ProgressiveMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error creating media source", e)
            // Last resort fallback
            ProgressiveMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
        }
    }

    /**
     * Resolve video URI with multiple strategies
     */
    private fun resolveVideoUri(videoPath: String): Uri? {
        val trimmedPath = videoPath.trim()
        
        // Try parsing as URI first
        val parsedUri = runCatching { Uri.parse(trimmedPath) }.getOrNull()
        if (parsedUri != null && (parsedUri.scheme == "content" || parsedUri.scheme == "file")) {
            return if (parsedUri.scheme == "content") {
                parsedUri
            } else {
                // Convert file:// to proper URI
                val file = File(parsedUri.path ?: return null)
                if (file.exists()) {
                    createFileProviderUri(file) ?: parsedUri
                } else {
                    null
                }
            }
        }

        // Treat as file path
        val file = File(trimmedPath)
        if (!file.exists()) {
            Log.w(TAG, "File does not exist: $trimmedPath")
            return null
        }

        // Try MediaStore first for better compatibility
        findMediaStoreUri(file)?.let { return it }

        // Fallback to FileProvider
        return createFileProviderUri(file)
    }

    /**
     * Create FileProvider URI for file access
     */
    private fun createFileProviderUri(file: File): Uri? {
        return try {
            FileProvider.getUriForFile(
                appContext,
                "${appContext.packageName}.fileprovider",
                file
            )
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "FileProvider failed for ${file.path}", e)
            // Fallback to file:// URI
            runCatching { Uri.fromFile(file) }.getOrNull()
        }
    }

    /**
     * Find MediaStore URI for file
     */
    @SuppressLint("Range")
    private fun findMediaStoreUri(file: File): Uri? {
        if (!file.exists()) return null

        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.MIME_TYPE
        )
        val selection = "${MediaStore.Video.Media.DATA} = ?"
        val selectionArgs = arrayOf(file.absolutePath)

        return try {
            appContext.contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID))
                    ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "MediaStore lookup failed for ${file.path}", e)
            null
        }
    }

    /**
     * Detect MIME type from URI and file extension
     */
    private fun detectMimeType(uri: Uri, fallbackPath: String?): String? {
        // Try ContentResolver first
        val resolverType = appContext.contentResolver.getType(uri)
        if (!resolverType.isNullOrBlank()) {
            return resolverType
        }

        // Try file extension
        val extension = getFileExtension(uri, fallbackPath)
        if (!extension.isNullOrBlank()) {
            // Try MimeTypeMap
            MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase())?.let { return it }
            
            // Use our predefined mapping
            VIDEO_MIME_TYPES[extension.lowercase()]?.let { return it }
        }

        return null
    }

    /**
     * Get file extension from URI or path
     */
    private fun getFileExtension(uri: Uri, fallbackPath: String?): String? {
        return when {
            !uri.path.isNullOrBlank() -> {
                val uriString = uri.toString()
                val lastDot = uriString.lastIndexOf('.')
                if (lastDot != -1) uriString.substring(lastDot + 1) else null
            }
            !fallbackPath.isNullOrBlank() -> {
                val lastDot = fallbackPath.lastIndexOf('.')
                if (lastDot != -1) fallbackPath.substring(lastDot + 1) else null
            }
            else -> null
        }
    }

    /**
     * Create subtitle configuration
     */
    private fun createSubtitleConfiguration(subtitlePath: String): MediaItem.SubtitleConfiguration? {
        return try {
            val subtitleUri = resolveVideoUri(subtitlePath) ?: return null
            grantUriPermissions(subtitleUri)
            
            MediaItem.SubtitleConfiguration.Builder(subtitleUri)
                .setMimeType("application/x-subrip")
                .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                .build()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to create subtitle configuration for: $subtitlePath", e)
            null
        }
    }

    /**
     * Grant URI permissions for access
     */
    private fun grantUriPermissions(uri: Uri) {
        try {
            appContext.grantUriPermission(
                appContext.packageName,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (e: SecurityException) {
            Log.w(TAG, "Failed to grant URI permission for: $uri", e)
        }
    }

    /**
     * Check storage permissions
     */
    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.READ_MEDIA_VIDEO
            ) == PackageManager.PERMISSION_GRANTED || Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED || Environment.isExternalStorageManager()
        }
    }

    // Player control methods
    fun play() {
        try {
            player.play()
            Log.d(TAG, "Play command sent")
        } catch (e: Exception) {
            Log.e(TAG, "Error playing", e)
            emitError("PLAY_ERROR", "Failed to start playback: ${e.message}")
        }
    }

    fun pause() {
        try {
            player.pause()
            Log.d(TAG, "Pause command sent")
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing", e)
            emitError("PAUSE_ERROR", "Failed to pause playback: ${e.message}")
        }
    }

    fun seekTo(positionMs: Long) {
        try {
            player.seekTo(positionMs)
            Log.d(TAG, "Seek to: ${positionMs}ms")
        } catch (e: Exception) {
            Log.e(TAG, "Error seeking", e)
            emitError("SEEK_ERROR", "Failed to seek: ${e.message}")
        }
    }

    fun setPlaybackSpeed(speed: Float) {
        try {
            player.playbackParameters = PlaybackParameters(speed.coerceIn(0.25f, 3.0f))
            Log.d(TAG, "Playback speed set to: $speed")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting playback speed", e)
            emitError("SPEED_ERROR", "Failed to set playback speed: ${e.message}")
        }
    }

    fun setAspectRatio(resizeMode: Int) {
        try {
            player.videoScalingMode = resizeMode
            playerView?.resizeMode = resizeMode
            Log.d(TAG, "Aspect ratio set to: $resizeMode")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting aspect ratio", e)
            emitError("ASPECT_ERROR", "Failed to set aspect ratio: ${e.message}")
        }
    }

    // Player.Listener implementation
    override fun onEvents(player: Player, events: Player.Events) {
        if (events.containsAny(Player.EVENT_PLAYBACK_STATE_CHANGED, Player.EVENT_PLAY_WHEN_READY_CHANGED)) {
            handlePlaybackStateChange(player.isPlaying, player.playbackState)
        }
        
        if (events.contains(Player.EVENT_TRACKS_CHANGED)) {
            mainScope.launch {
                _events.emit(PlayerEvent.TracksChanged(player.currentTracks))
            }
        }
        
        if (events.contains(Player.EVENT_PLAYER_ERROR)) {
            val error = player.playerError
            if (error != null) {
                Log.e(TAG, "Player error: ${error.errorCodeName} - ${error.message}")
                emitError(error.errorCodeName, error.message ?: "Unknown playback error")
            }
        }
        
        if (events.contains(Player.EVENT_IS_PLAYING_CHANGED)) {
            handlePlaybackStateChange(player.isPlaying, player.playbackState)
        }
    }

    private fun handlePlaybackStateChange(isPlaying: Boolean, playbackState: Int) {
        val state = when (playbackState) {
            Player.STATE_IDLE -> 0
            Player.STATE_BUFFERING -> 1
            Player.STATE_READY -> 2
            Player.STATE_ENDED -> 3
            else -> 0
        }
        
        mainScope.launch {
            _events.emit(
                PlayerEvent.PlaybackState(
                    state = state,
                    isPlaying = isPlaying,
                    isBuffering = playbackState == Player.STATE_BUFFERING,
                    isEnded = playbackState == Player.STATE_ENDED
                )
            )
        }

        if (isPlaying) {
            startPositionReporting()
        } else {
            reportingJob?.cancel()
        }
    }

    private fun startPositionReporting() {
        reportingJob?.cancel()
        reportingJob = mainScope.launch {
            while (true) {
                _events.emit(
                    PlayerEvent.Position(
                        positionMs = player.currentPosition,
                        durationMs = player.duration
                    )
                )
                delay(500)
            }
        }
    }

    private fun emitError(code: String, message: String) {
        Log.e(TAG, "Error emitted: $code - $message")
        mainScope.launch {
            _events.emit(PlayerEvent.Error(code, message))
        }
    }

    // Lifecycle management
    override fun onStop(owner: LifecycleOwner) {
        pause()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        release()
    }

    /**
     * Clean up resources
     */
    fun release() {
        Log.d(TAG, "Releasing player resources")
        reportingJob?.cancel()
        player.removeListener(this)
        player.release()
        playerView?.player = null
    }

    // Event definitions
    sealed interface PlayerEvent {
        data class PlaybackState(
            val state: Int,
            val isPlaying: Boolean,
            val isBuffering: Boolean,
            val isEnded: Boolean
        ) : PlayerEvent
        
        data class Error(val code: String, val message: String) : PlayerEvent
        data class Position(val positionMs: Long, val durationMs: Long) : PlayerEvent
        data class TracksChanged(val tracks: Tracks) : PlayerEvent
        data class Gesture(val action: String, val value: String = "") : PlayerEvent
    }

    // Additional utility methods can be added here as needed
    fun getVideoInformation(): Map<String, Any?> {
        val videoFormat = player.videoFormat
        val audioFormat = player.audioFormat
        val duration = player.duration
        
        return mapOf(
            "videoCodec" to videoFormat?.codecs,
            "width" to videoFormat?.width,
            "height" to videoFormat?.height,
            "frameRate" to videoFormat?.frameRate,
            "audioCodec" to audioFormat?.codecs,
            "audioChannels" to audioFormat?.channelCount,
            "audioSampleRate" to audioFormat?.sampleRate,
            "duration" to duration,
            "path" to currentUri?.toString(),
            "mimeType" to currentMediaItem?.localConfiguration?.mimeType
        )
    }
}
