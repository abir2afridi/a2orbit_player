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
import androidx.media3.common.Format
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.FileDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.text.TextOutput
import androidx.media3.exoplayer.text.TextRenderer
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.PlayerView
import android.view.View
import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.util.Rational
import android.graphics.Bitmap
import java.io.FileOutputStream
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
import kotlin.math.roundToInt
import java.util.Locale

/**
 * Repeat modes for A-B repeat functionality
 */
enum class RepeatMode {
    NONE,
    REPEAT_AB,
    REPEAT_ONE
}

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
        
        private const val DEFAULT_BRIGHTNESS = 0.5f
        private const val MIN_BRIGHTNESS = 0.05f

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
    
    // Subtitle support
    private var subtitleSources: List<MediaSource> = emptyList()
    private var currentSubtitleIndex: Int = -1
    private var subtitlesEnabled: Boolean = true
    
    // Audio track support
    private var currentAudioGroupIndex: Int = -1
    private var currentAudioTrackIndex: Int = -1
    private var availableAudioTracks: List<Map<String, Any?>> = emptyList()
    
    // PiP support
    private var isInPiPMode: Boolean = false
    private var pipAspectRatio: Rational? = null
    
    // Background audio support
    private var isBackgroundPlaybackEnabled: Boolean = false
    private var wasPlayingBeforeBackground: Boolean = false
    
    // Screenshot capture support
    private var lastScreenshotPath: String? = null
    
    // A-B repeat support
    private var repeatMode: RepeatMode = RepeatMode.NONE
    private var repeatStartPosition: Long = -1L
    private var repeatEndPosition: Long = -1L
    private var isSettingRepeatStart: Boolean = false
    private var isSettingRepeatEnd: Boolean = false
    
    // Kids lock support
    private var isKidsLockEnabled: Boolean = false
    private var kidsLockPin: String = "0000" // Default PIN
    
    // Device rotation support
    private var currentOrientation: Int = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
    private var isAutoRotateEnabled: Boolean = true
    private var isOrientationLocked: Boolean = false

    // Event flow for communication with Flutter
    private val _events = MutableSharedFlow<PlayerEvent>(extraBufferCapacity = 32)
    val events: SharedFlow<PlayerEvent> = _events
    
    /**
     * Emit event from external sources (like gesture handlers)
     */
    fun emitEvent(event: PlayerEvent) {
        mainScope.launch {
            _events.emit(event)
        }
    }

    // Gesture control state
    private var playerBrightness: Float = DEFAULT_BRIGHTNESS
    private var volumeBeforeGesture: Int? = null
    private var lastVolumeApplied: Int? = null
    private var maxVolumeCached: Int? = null
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
    private val maxVolume: Int
        get() {
            val cached = maxVolumeCached
            if (cached != null) return cached
            val resolved = audioManager?.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC) ?: 15
            maxVolumeCached = resolved
            return resolved
        }
    private var pendingSeekPosition: Long? = null
    
    init {
        player.addListener(this)
        lifecycleOwner?.lifecycle?.addObserver(this)
        Log.d(TAG, "RobustExoPlayerController initialized")
        applyWindowBrightness(playerBrightness)
    }
    
    fun setPlayerBrightness(value: Float): Float {
        val clamped = value.coerceIn(MIN_BRIGHTNESS, 1.0f)
        playerBrightness = clamped

        applyWindowBrightness(clamped)

        mainScope.launch {
            _events.emit(PlayerEvent.BrightnessChanged(clamped))
        }

        return clamped
    }

    fun getPlayerBrightness(): Float = playerBrightness

    fun prepareVolumeGesture(): Map<String, Int>? {
        return try {
            val audioManager = audioManager ?: return null
            val currentVolume = audioManager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)
            volumeBeforeGesture = currentVolume
            lastVolumeApplied = currentVolume
            mapOf(
                "current" to currentVolume,
                "max" to maxVolume
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error preparing volume gesture", e)
            null
        }
    }

    fun applyVolumeLevel(level: Float): Map<String, Int>? {
        return try {
            val audioManager = audioManager ?: return null
            val resolvedLevel = level.coerceIn(0f, 1f)
            val targetVolume = (resolvedLevel * maxVolume).roundToInt().coerceIn(0, maxVolume)

            if (lastVolumeApplied != targetVolume) {
                audioManager.setStreamVolume(
                    android.media.AudioManager.STREAM_MUSIC,
                    targetVolume,
                    android.media.AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE
                )
                lastVolumeApplied = targetVolume
            }

            mainScope.launch {
                _events.emit(PlayerEvent.VolumeChanged(targetVolume, maxVolume))
            }

            mapOf(
                "current" to targetVolume,
                "max" to maxVolume
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error applying volume level", e)
            null
        }
    }

    fun finalizeVolumeGesture(level: Float?): Map<String, Int>? {
        return try {
            val audioManager = audioManager ?: return null
            val resolvedLevel = (level ?: (lastVolumeApplied?.toFloat()?.div(maxVolume) ?: volumeBeforeGesture?.toFloat()?.div(maxVolume) ?: 0f)).coerceIn(0f, 1f)
            val targetVolume = (resolvedLevel * maxVolume).roundToInt().coerceIn(0, maxVolume)

            if (lastVolumeApplied != targetVolume) {
                audioManager.setStreamVolume(
                    android.media.AudioManager.STREAM_MUSIC,
                    targetVolume,
                    android.media.AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE
                )
                lastVolumeApplied = targetVolume
            }

            volumeBeforeGesture = null

            mainScope.launch {
                _events.emit(PlayerEvent.VolumeChanged(targetVolume, maxVolume))
            }

            mapOf(
                "current" to targetVolume,
                "max" to maxVolume
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error finalizing volume gesture", e)
            null
        }
    }
    
    /**
     * Handle seek gesture
     */
    fun handleSeekGesture(delta: Float) {
        try {
            val duration = player.duration
            if (duration <= 0) return
            
            // Calculate seek position
            val seekDeltaMs = (delta * 1000).toLong() // Convert to milliseconds
            val currentPosition = player.currentPosition
            val newPosition = (currentPosition + seekDeltaMs).coerceIn(0, duration)
            
            // Store pending seek position
            pendingSeekPosition = newPosition
            
            // Seek to new position
            player.seekTo(newPosition)
            
            // Emit seek event
            mainScope.launch {
                _events.emit(
                    PlayerEvent.Seek(newPosition, duration)
                )
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling seek gesture", e)
        }
    }
    
    /**
     * Handle zoom gesture
     */
    fun handleZoomGesture(scale: Float) {
        try {
            // Emit zoom event for Flutter to handle UI updates
            mainScope.launch {
                _events.emit(
                    PlayerEvent.Zoom(scale)
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling zoom gesture", e)
        }
    }
    
    /**
     * Reset gesture states
     */
    fun resetGestureStates() {
        try {
            volumeBeforeGesture = null
            lastVolumeApplied = null
            pendingSeekPosition = null
            
        } catch (e: Exception) {
            Log.e(TAG, "Error resetting gesture states", e)
        }
    }

    private fun applyWindowBrightness(value: Float) {
        val activity = activity ?: return
        val clamped = value.coerceIn(MIN_BRIGHTNESS, 1.0f)
        activity.runOnUiThread {
            val params = activity.window.attributes
            params.screenBrightness = clamped
            activity.window.attributes = params
        }
    }
    
    /**
     * Load subtitle files
     */
    fun loadSubtitles(subtitlePaths: List<String>) {
        try {
            subtitleSources = subtitlePaths.mapNotNull { path ->
                loadSubtitleSource(path)
            }
            Log.d(TAG, "Loaded ${subtitleSources.size} subtitle sources")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading subtitles", e)
        }
    }
    
    /**
     * Load individual subtitle source
     */
    private fun loadSubtitleSource(subtitlePath: String): MediaSource? {
        return try {
            val subtitleUri = resolveSubtitleUri(subtitlePath) ?: return null
            val mimeType = detectSubtitleMimeType(subtitlePath)
            
            ProgressiveMediaSource.Factory(dataSourceFactory)
                .createMediaSource(MediaItem.Builder()
                    .setUri(subtitleUri)
                    .setMimeType(mimeType)
                    .build())
        } catch (e: Exception) {
            Log.e(TAG, "Error loading subtitle source: $subtitlePath", e)
            null
        }
    }
    
    /**
     * Resolve subtitle URI
     */
    private fun resolveSubtitleUri(subtitlePath: String): Uri? {
        return try {
            val file = File(subtitlePath)
            if (file.exists()) {
                // Try FileProvider first
                FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            } else {
                // Fallback to direct file path
                Uri.parse(subtitlePath)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error resolving subtitle URI: $subtitlePath", e)
            null
        }
    }
    
    /**
     * Detect subtitle MIME type
     */
    private fun detectSubtitleMimeType(subtitlePath: String): String {
        val extension = subtitlePath.substringAfterLast('.', "").lowercase()
        return when (extension) {
            "srt" -> "application/x-subrip"
            "ass", "ssa" -> "text/x-ssa"
            "vtt" -> "text/vtt"
            else -> "application/x-subrip" // Default to SRT
        }
    }
    
    /**
     * Enable/disable subtitles
     */
    fun setSubtitlesEnabled(enabled: Boolean) {
        subtitlesEnabled = enabled
        playerView?.subtitleView?.visibility = if (enabled) View.VISIBLE else View.GONE
        
        mainScope.launch {
            _events.emit(
                PlayerEvent.SubtitleStateChanged(enabled)
            )
        }
    }
    
    /**
     * Select subtitle track by index
     */
    fun selectSubtitleTrack(index: Int) {
        if (index < 0 || index >= subtitleSources.size) {
            Log.w(TAG, "Invalid subtitle track index: $index")
            return
        }
        
        currentSubtitleIndex = index
        
        // Rebuild media source with selected subtitle
        currentUri?.let { uri ->
            rebuildMediaSourceWithSubtitles(uri)
        }
        
        mainScope.launch {
            _events.emit(
                PlayerEvent.SubtitleTrackChanged(index)
            )
        }
    }
    
    /**
     * Get available subtitle tracks
     */
    fun getSubtitleTracks(): List<Map<String, Any>> {
        return subtitleSources.indices.map { index ->
            mapOf(
                "index" to index,
                "name" to "Subtitle ${index + 1}",
                "language" to "unknown",
                "selected" to (index == currentSubtitleIndex)
            )
        }
    }
    
    /**
     * Rebuild media source with subtitles
     */
    private fun rebuildMediaSourceWithSubtitles(videoUri: Uri) {
        try {
            val mimeType = detectMimeType(videoUri, currentUri?.toString() ?: "")
            val videoMediaItem = MediaItem.Builder()
                .setUri(videoUri)
                .setMediaId(currentUri?.toString() ?: "")
                .setMimeType(mimeType)
                .build()
            
            val videoSource = ProgressiveMediaSource.Factory(dataSourceFactory)
                .createMediaSource(videoMediaItem)
            
            // Combine with subtitle sources if enabled
            val mediaSource = if (subtitlesEnabled && subtitleSources.isNotEmpty()) {
                // Note: ExoPlayer doesn't directly support combining sources like this
                // This is a simplified approach - in production, you'd use MergingMediaSource
                videoSource
            } else {
                videoSource
            }
            
            player.setMediaSource(mediaSource)
            player.prepare()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error rebuilding media source with subtitles", e)
            emitError("SUBTITLE_ERROR", "Failed to load subtitles: ${e.message}")
        }
    }
    
    /**
     * Get available audio tracks
     */
    fun getAudioTracks(): List<Map<String, Any?>> {
        val audioTracks = mutableListOf<MutableMap<String, Any?>>()
        var fallbackIndex = 1
        var selectedGroup = -1
        var selectedTrack = -1

        try {
            val tracks = player.currentTracks
            tracks.groups.forEachIndexed { groupIndex, group ->
                if (group.type != C.TRACK_TYPE_AUDIO) return@forEachIndexed

                val trackGroup = group.mediaTrackGroup
                for (trackIndex in 0 until trackGroup.length) {
                    val format = trackGroup.getFormat(trackIndex)

                    val languageCode = format.language?.takeIf { it.isNotBlank() } ?: "und"
                    val languageDisplay = resolveLanguageDisplay(languageCode)
                    val channelCount = format.channelCount ?: 0
                    val channelDescription = describeChannelCount(channelCount)

                    val baseLabel = format.label?.takeIf { it.isNotBlank() }
                        ?: languageDisplay
                        ?: "Track ${fallbackIndex++}"

                    val displayName = buildString {
                        append(baseLabel)
                        if (!channelDescription.isNullOrBlank()) {
                            append(" (")
                            append(channelDescription)
                            append(")")
                        }
                    }

                    val isSelected = runCatching { group.isTrackSelected(trackIndex) }.getOrDefault(false)
                    if (isSelected) {
                        selectedGroup = groupIndex
                        selectedTrack = trackIndex
                    }

                    val trackInfo = mutableMapOf<String, Any?>(
                        "groupIndex" to groupIndex,
                        "trackIndex" to trackIndex,
                        "id" to (format.id ?: "track_${groupIndex}_$trackIndex"),
                        "language" to languageCode,
                        "languageDisplay" to (languageDisplay ?: "Unknown"),
                        "label" to baseLabel,
                        "displayName" to displayName,
                        "mimeType" to (format.sampleMimeType ?: ""),
                        "channelCount" to channelCount,
                        "channelDescription" to channelDescription,
                        "selected" to isSelected
                    )

                    val bitrate = format.bitrate
                    if (bitrate != Format.NO_VALUE) {
                        trackInfo["bitrate"] = bitrate
                    }

                    val sampleRate = format.sampleRate
                    if (sampleRate != Format.NO_VALUE) {
                        trackInfo["sampleRate"] = sampleRate
                    }

                    audioTracks.add(trackInfo)
                }
            }

            if (selectedGroup == -1 && audioTracks.isNotEmpty()) {
                val first = audioTracks.first()
                selectedGroup = first["groupIndex"] as Int
                selectedTrack = first["trackIndex"] as Int
                first["selected"] = true
            }

            currentAudioGroupIndex = selectedGroup
            currentAudioTrackIndex = selectedTrack

            val finalTracks = audioTracks.map { it.toMap() }
            availableAudioTracks = finalTracks
            Log.d(TAG, "Found ${audioTracks.size} audio tracks")

        } catch (e: Exception) {
            Log.e(TAG, "Error getting audio tracks", e)
        }

        return availableAudioTracks
    }

    private fun resolveLanguageDisplay(code: String?): String? {
        if (code.isNullOrBlank() || code == "und") return null
        return try {
            val locale = if (code.contains("-")) {
                val parts = code.split("-")
                when (parts.size) {
                    1 -> Locale(parts[0])
                    2 -> Locale(parts[0], parts[1])
                    else -> Locale(parts[0], parts[1], parts[2])
                }
            } else {
                Locale(code)
            }
            val display = locale.displayLanguage
            display.takeIf { it.isNotBlank() }
        } catch (_: Exception) {
            null
        }
    }

    private fun describeChannelCount(count: Int): String? {
        return when {
            count <= 0 -> null
            count == 1 -> "Mono"
            count == 2 -> "Stereo"
            count == 6 -> "5.1"
            count == 8 -> "7.1"
            count >= 6 -> "${count}-channel"
            else -> "${count}-channel"
        }
    }
    
    /**
     * Select audio track by index
     */
    fun selectAudioTrack(groupIndex: Int, trackIndex: Int): Boolean {
        val tracks = player.currentTracks
        val audioGroup = tracks.groups.getOrNull(groupIndex)

        if (audioGroup?.type != C.TRACK_TYPE_AUDIO) {
            Log.w(TAG, "Invalid audio track selection: group=$groupIndex, track=$trackIndex")
            return false
        }

        val previousGroup = currentAudioGroupIndex
        val previousTrack = currentAudioTrackIndex

        return try {
            val override = TrackSelectionOverride(
                audioGroup.mediaTrackGroup,
                listOf(trackIndex)
            )

            val parametersBuilder = trackSelector.parameters.buildUpon()
            parametersBuilder.clearOverridesOfType(C.TRACK_TYPE_AUDIO)
            parametersBuilder.setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, false)
            parametersBuilder.addOverride(override)

            trackSelector.setParameters(parametersBuilder)

            currentAudioGroupIndex = groupIndex
            currentAudioTrackIndex = trackIndex

            mainScope.launch {
                _events.emit(
                    PlayerEvent.AudioTrackChanged(groupIndex, trackIndex)
                )
            }

            updateAudioTracks()
            Log.d(TAG, "Selected audio track: group=$groupIndex, track=$trackIndex")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error selecting audio track", e)
            restoreAudioOverride(previousGroup, previousTrack)
            currentAudioGroupIndex = previousGroup
            currentAudioTrackIndex = previousTrack
            updateAudioTracks()
            emitError("AUDIO_TRACK_ERROR", "Failed to select audio track: ${e.message}")
            false
        }
    }

    private fun restoreAudioOverride(groupIndex: Int, trackIndex: Int) {
        if (groupIndex == -1 || trackIndex == -1) return
        val tracks = player.currentTracks
        val audioGroup = tracks.groups.getOrNull(groupIndex) ?: return
        if (audioGroup.type != C.TRACK_TYPE_AUDIO) return

        val override = TrackSelectionOverride(
            audioGroup.mediaTrackGroup,
            listOf(trackIndex)
        )

        val parametersBuilder = trackSelector.parameters.buildUpon()
        parametersBuilder.clearOverridesOfType(C.TRACK_TYPE_AUDIO)
        parametersBuilder.setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, false)
        parametersBuilder.addOverride(override)
        trackSelector.setParameters(parametersBuilder)
    }
    
    /**
     * Get current audio track info
     */
    fun getCurrentAudioTrack(): Map<String, Any?>? {
        if (currentAudioGroupIndex == -1 || currentAudioTrackIndex == -1) return null
        return availableAudioTracks.firstOrNull { track ->
            (track["groupIndex"] as? Int == currentAudioGroupIndex) &&
            (track["trackIndex"] as? Int == currentAudioTrackIndex)
        }
    }
    
    /**
     * Update audio tracks when tracks change
     */
    private fun updateAudioTracks() {
        val tracks = getAudioTracks()
        mainScope.launch {
            _events.emit(
                PlayerEvent.AudioTracksChanged(tracks)
            )
        }
    }
    
    /**
     * Enter Picture-in-Picture mode
     */
    fun enterPictureInPicture(): Boolean {
        return try {
            val activity = activity ?: return false
            
            // Check if PiP is supported
            if (!activity.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                Log.w(TAG, "PiP not supported on this device")
                return false
            }
            
            // Get video aspect ratio
            val aspectRatio = getVideoAspectRatio()
            pipAspectRatio = aspectRatio
            
            // Build PiP parameters
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(aspectRatio)
                .setSourceRectHint(android.graphics.Rect(0, 0, 1920, 1080)) // Default source rect
                .build()
            
            // Enter PiP mode
            val result = activity.enterPictureInPictureMode(params)
            if (result) {
                isInPiPMode = true
                mainScope.launch {
                    _events.emit(PlayerEvent.PiPModeChanged(true))
                }
                Log.d(TAG, "Successfully entered PiP mode")
            } else {
                Log.w(TAG, "Failed to enter PiP mode")
            }
            
            result
        } catch (e: Exception) {
            Log.e(TAG, "Error entering PiP mode", e)
            emitError("PIP_ERROR", "Failed to enter PiP mode: ${e.message}")
            false
        }
    }
    
    /**
     * Exit Picture-in-Picture mode
     */
    fun exitPictureInPicture() {
        try {
            val activity = activity ?: return
            
            // Note: There's no direct API to exit PiP mode
            // The system handles exiting PiP when user returns to app
            // We just update our state
            isInPiPMode = false
            mainScope.launch {
                _events.emit(PlayerEvent.PiPModeChanged(false))
            }
            Log.d(TAG, "PiP mode exit requested")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error exiting PiP mode", e)
        }
    }
    
    /**
     * Check if currently in PiP mode
     */
    fun isInPictureInPictureMode(): Boolean {
        return isInPiPMode
    }
    
    /**
     * Get video aspect ratio for PiP
     */
    private fun getVideoAspectRatio(): Rational {
        return try {
            val videoFormat = player.videoFormat
            if (videoFormat != null) {
                val width = videoFormat.width
                val height = videoFormat.height
                if (width > 0 && height > 0) {
                    Rational(width, height)
                } else {
                    Rational(16, 9) // Default to 16:9
                }
            } else {
                Rational(16, 9) // Default to 16:9
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting video aspect ratio", e)
            Rational(16, 9) // Default to 16:9
        }
    }
    
    /**
     * Handle PiP mode changes
     */
    fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        isInPiPMode = isInPictureInPictureMode
        
        mainScope.launch {
            _events.emit(PlayerEvent.PiPModeChanged(isInPictureInPictureMode))
        }
        
        if (isInPictureInPictureMode) {
            Log.d(TAG, "Entered PiP mode")
            // Hide UI controls in PiP mode
            playerView?.useController = false
        } else {
            Log.d(TAG, "Exited PiP mode")
            // Restore UI controls
            playerView?.useController = false // Keep custom controls
        }
    }
    
    /**
     * Enable/disable background audio playback
     */
    fun setBackgroundPlaybackEnabled(enabled: Boolean) {
        isBackgroundPlaybackEnabled = enabled
        mainScope.launch {
            _events.emit(PlayerEvent.BackgroundPlaybackChanged(enabled))
        }
        Log.d(TAG, "Background playback ${if (enabled) "enabled" else "disabled"}")
    }
    
    /**
     * Check if background playback is enabled
     */
    fun isBackgroundPlaybackEnabled(): Boolean {
        return isBackgroundPlaybackEnabled
    }
    
    /**
     * Handle app background/foreground state changes
     */
    fun onAppBackgrounded() {
        if (isBackgroundPlaybackEnabled && player.isPlaying) {
            wasPlayingBeforeBackground = true
            // Continue audio playback in background
            Log.d(TAG, "Continuing audio playback in background")
        }
    }
    
    /**
     * Handle app returning to foreground
     */
    fun onAppForegrounded() {
        if (isBackgroundPlaybackEnabled && wasPlayingBeforeBackground) {
            wasPlayingBeforeBackground = false
            Log.d(TAG, "App returned to foreground, audio playback continuing")
        }
    }
    
    /**
     * Extract audio from video for background playback
     */
    fun enableAudioOnlyMode() {
        try {
            // Hide video surface but keep audio playing
            playerView?.visibility = View.GONE
            playerView?.player = null
            
            // Create a simple audio-only player
            val audioPlayer = ExoPlayer.Builder(context).build()
            audioPlayer.setMediaSource(player.currentMediaItem?.let { mediaItem ->
                ProgressiveMediaSource.Factory(dataSourceFactory)
                    .createMediaSource(mediaItem)
            } ?: return)
            audioPlayer.prepare()
            audioPlayer.playWhenReady = player.playWhenReady
            
            // Replace current player temporarily
            val currentPlayer = player
            // Note: This is a simplified approach - in production, you'd manage player lifecycle better
            
            mainScope.launch {
                _events.emit(PlayerEvent.AudioOnlyModeChanged(true))
            }
            
            Log.d(TAG, "Audio-only mode enabled")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling audio-only mode", e)
            emitError("AUDIO_ONLY_ERROR", "Failed to enable audio-only mode: ${e.message}")
        }
    }
    
    /**
     * Disable audio-only mode and restore video
     */
    fun disableAudioOnlyMode() {
        try {
            // Restore video surface
            playerView?.visibility = View.VISIBLE
            playerView?.player = player
            
            mainScope.launch {
                _events.emit(PlayerEvent.AudioOnlyModeChanged(false))
            }
            
            Log.d(TAG, "Audio-only mode disabled")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling audio-only mode", e)
        }
    }
    
    /**
     * Capture screenshot from current video frame
     */
    fun captureScreenshot(): String? {
        return try {
            val playerView = playerView ?: return null
            
            // Get the bitmap from the player view
            playerView.isDrawingCacheEnabled = true
            val bitmap = Bitmap.createBitmap(playerView.drawingCache)
            playerView.isDrawingCacheEnabled = false
            
            if (bitmap == null) {
                Log.w(TAG, "Failed to capture screenshot - bitmap is null")
                return null
            }
            
            // Create screenshots directory
            val screenshotsDir = File(context.getExternalFilesDir(null), "screenshots")
            if (!screenshotsDir.exists()) {
                screenshotsDir.mkdirs()
            }
            
            // Generate unique filename
            val timestamp = System.currentTimeMillis()
            val filename = "screenshot_$timestamp.png"
            val screenshotFile = File(screenshotsDir, filename)
            
            // Save bitmap to file
            val outputStream = FileOutputStream(screenshotFile)
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            outputStream.close()
            
            // Clean up bitmap
            bitmap.recycle()
            
            lastScreenshotPath = screenshotFile.absolutePath
            
            mainScope.launch {
                _events.emit(PlayerEvent.ScreenshotCaptured(lastScreenshotPath!!))
            }
            
            Log.d(TAG, "Screenshot saved to: ${lastScreenshotPath}")
            lastScreenshotPath
            
        } catch (e: Exception) {
            Log.e(TAG, "Error capturing screenshot", e)
            emitError("SCREENSHOT_ERROR", "Failed to capture screenshot: ${e.message}")
            null
        }
    }
    
    /**
     * Get last screenshot path
     */
    fun getLastScreenshotPath(): String? {
        return lastScreenshotPath
    }
    
    /**
     * Get all screenshot files
     */
    fun getScreenshotFiles(): List<String> {
        return try {
            val screenshotsDir = File(context.getExternalFilesDir(null), "screenshots")
            if (!screenshotsDir.exists()) {
                return emptyList()
            }
            
            screenshotsDir.listFiles()
                ?.filter { it.extension.equals("png", ignoreCase = true) }
                ?.sortedByDescending { it.lastModified() }
                ?.map { it.absolutePath }
                ?: emptyList()
                
        } catch (e: Exception) {
            Log.e(TAG, "Error getting screenshot files", e)
            emptyList()
        }
    }
    
    /**
     * Delete screenshot file
     */
    fun deleteScreenshot(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            val deleted = file.delete()
            
            if (deleted && filePath == lastScreenshotPath) {
                lastScreenshotPath = null
            }
            
            mainScope.launch {
                _events.emit(PlayerEvent.ScreenshotDeleted(filePath))
            }
            
            Log.d(TAG, "Screenshot deleted: $filePath")
            deleted
            
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting screenshot", e)
            false
        }
    }
    
    /**
     * Set A-B repeat start point
     */
    fun setRepeatStartPoint() {
        repeatStartPosition = player.currentPosition
        isSettingRepeatStart = true
        
        mainScope.launch {
            _events.emit(PlayerEvent.RepeatPointSet("start", repeatStartPosition))
        }
        
        Log.d(TAG, "Repeat start point set at: ${repeatStartPosition}ms")
        
        // If end point is already set, enable A-B repeat
        if (repeatEndPosition > 0 && repeatEndPosition > repeatStartPosition) {
            repeatMode = RepeatMode.REPEAT_AB
            mainScope.launch {
                _events.emit(PlayerEvent.RepeatModeChanged(repeatMode.name))
            }
            Log.d(TAG, "A-B repeat enabled")
        }
    }
    
    /**
     * Set A-B repeat end point
     */
    fun setRepeatEndPoint() {
        repeatEndPosition = player.currentPosition
        isSettingRepeatEnd = true
        
        mainScope.launch {
            _events.emit(PlayerEvent.RepeatPointSet("end", repeatEndPosition))
        }
        
        Log.d(TAG, "Repeat end point set at: ${repeatEndPosition}ms")
        
        // If start point is already set, enable A-B repeat
        if (repeatStartPosition >= 0 && repeatStartPosition < repeatEndPosition) {
            repeatMode = RepeatMode.REPEAT_AB
            mainScope.launch {
                _events.emit(PlayerEvent.RepeatModeChanged(repeatMode.name))
            }
            Log.d(TAG, "A-B repeat enabled")
        }
    }
    
    /**
     * Clear A-B repeat points
     */
    fun clearRepeatPoints() {
        repeatStartPosition = -1L
        repeatEndPosition = -1L
        isSettingRepeatStart = false
        isSettingRepeatEnd = false
        
        if (repeatMode == RepeatMode.REPEAT_AB) {
            repeatMode = RepeatMode.NONE
            mainScope.launch {
                _events.emit(PlayerEvent.RepeatModeChanged(repeatMode.name))
            }
        }
        
        Log.d(TAG, "A-B repeat points cleared")
    }
    
    /**
     * Set repeat mode
     */
    fun setRepeatMode(mode: String) {
        repeatMode = try {
            RepeatMode.valueOf(mode.uppercase())
        } catch (e: IllegalArgumentException) {
            RepeatMode.NONE
        }
        
        mainScope.launch {
            _events.emit(PlayerEvent.RepeatModeChanged(repeatMode.name))
        }
        
        Log.d(TAG, "Repeat mode set to: ${repeatMode.name}")
    }
    
    /**
     * Get current repeat mode
     */
    fun getRepeatMode(): String {
        return repeatMode.name
    }
    
    /**
     * Get repeat points
     */
    fun getRepeatPoints(): Map<String, Long> {
        return mapOf(
            "start" to repeatStartPosition,
            "end" to repeatEndPosition
        )
    }
    
    /**
     * Check if A-B repeat is active
     */
    fun isRepeatABActive(): Boolean {
        return repeatMode == RepeatMode.REPEAT_AB && 
               repeatStartPosition >= 0 && 
               repeatEndPosition > repeatStartPosition
    }
    
    /**
     * Handle A-B repeat logic (called from position updates)
     */
    private fun handleRepeatLogic() {
        if (repeatMode == RepeatMode.REPEAT_AB && 
            repeatStartPosition >= 0 && 
            repeatEndPosition > repeatStartPosition) {
            
            val currentPosition = player.currentPosition
            
            // If we've reached or passed the end point, seek to start
            if (currentPosition >= repeatEndPosition) {
                player.seekTo(repeatStartPosition)
                Log.d(TAG, "A-B repeat: seeking to start point")
            }
        }
    }
    
    /**
     * Enable/disable kids lock
     */
    fun setKidsLockEnabled(enabled: Boolean, pin: String = "0000") {
        if (enabled && pin.isNotEmpty()) {
            kidsLockPin = pin
        }
        
        isKidsLockEnabled = enabled
        
        mainScope.launch {
            _events.emit(PlayerEvent.KidsLockChanged(enabled))
        }
        
        Log.d(TAG, "Kids lock ${if (enabled) "enabled" else "disabled"}")
    }
    
    /**
     * Check if kids lock is enabled
     */
    fun isKidsLockEnabled(): Boolean {
        return isKidsLockEnabled
    }
    
    /**
     * Verify kids lock PIN
     */
    fun verifyKidsLockPin(pin: String): Boolean {
        return pin == kidsLockPin
    }
    
    /**
     * Disable kids lock with PIN verification
     */
    fun disableKidsLockWithPin(pin: String): Boolean {
        return if (verifyKidsLockPin(pin)) {
            setKidsLockEnabled(false)
            true
        } else {
            false
        }
    }
    
    /**
     * Handle gesture when kids lock is enabled
     */
    fun handleGestureWithKidsLock(gestureType: String): Boolean {
        if (isKidsLockEnabled) {
            // Block most gestures when kids lock is enabled
            // Only allow basic playback controls
            return when (gestureType) {
                "play", "pause", "seek" -> true
                else -> false
            }
        }
        return true
    }
    
    /**
     * Set device orientation
     */
    fun setOrientation(orientation: String) {
        val activity = activity ?: return
        
        val orientationValue = when (orientation.uppercase()) {
            "PORTRAIT" -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            "LANDSCAPE" -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            "REVERSE_PORTRAIT" -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
            "REVERSE_LANDSCAPE" -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
            "SENSOR" -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR
            "AUTO" -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            else -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        
        currentOrientation = orientationValue
        activity.requestedOrientation = orientationValue
        
        mainScope.launch {
            _events.emit(PlayerEvent.OrientationChanged(orientation))
        }
        
        Log.d(TAG, "Orientation set to: $orientation")
    }
    
    /**
     * Get current orientation
     */
    fun getCurrentOrientation(): String {
        return when (currentOrientation) {
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT -> "PORTRAIT"
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE -> "LANDSCAPE"
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT -> "REVERSE_PORTRAIT"
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE -> "REVERSE_LANDSCAPE"
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR -> "SENSOR"
            else -> "AUTO"
        }
    }
    
    /**
     * Enable/disable auto rotation
     */
    fun setAutoRotateEnabled(enabled: Boolean) {
        isAutoRotateEnabled = enabled
        
        if (enabled) {
            setOrientation("AUTO")
            isOrientationLocked = false
        } else {
            isOrientationLocked = true
        }
        
        mainScope.launch {
            _events.emit(PlayerEvent.AutoRotateChanged(enabled))
        }
        
        Log.d(TAG, "Auto rotation ${if (enabled) "enabled" else "disabled"}")
    }
    
    /**
     * Check if auto rotate is enabled
     */
    fun isAutoRotateEnabled(): Boolean {
        return isAutoRotateEnabled
    }
    
    /**
     * Lock/unlock orientation
     */
    fun setOrientationLocked(locked: Boolean) {
        isOrientationLocked = locked
        
        if (locked) {
            // Keep current orientation
            activity?.requestedOrientation = currentOrientation
        } else {
            // Allow sensor-based rotation
            activity?.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR
        }
        
        mainScope.launch {
            _events.emit(PlayerEvent.OrientationLockChanged(locked))
        }
        
        Log.d(TAG, "Orientation lock ${if (locked) "enabled" else "disabled"}")
    }
    
    /**
     * Check if orientation is locked
     */
    fun isOrientationLocked(): Boolean {
        return isOrientationLocked
    }
    
    /**
     * Toggle between portrait and landscape
     */
    fun toggleOrientation() {
        val newOrientation = when (currentOrientation) {
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT, 
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT -> "LANDSCAPE"
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE, 
            android.content.pm.ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE -> "PORTRAIT"
            else -> "LANDSCAPE"
        }
        
        setOrientation(newOrientation)
    }
    
    /**
     * Handle device rotation changes
     */
    fun onConfigurationChanged(newConfig: Configuration) {
        val newOrientation = when (newConfig.orientation) {
            Configuration.ORIENTATION_PORTRAIT -> "PORTRAIT"
            Configuration.ORIENTATION_LANDSCAPE -> "LANDSCAPE"
            else -> "UNKNOWN"
        }
        
        mainScope.launch {
            _events.emit(PlayerEvent.DeviceOrientationChanged(newOrientation))
        }
        
        Log.d(TAG, "Device orientation changed to: $newOrientation")
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
                // Also update audio tracks when tracks change
                updateAudioTracks()
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
        data class BrightnessChanged(val brightness: Float) : PlayerEvent
        data class VolumeChanged(val volume: Int, val maxVolume: Int) : PlayerEvent
        data class Seek(val position: Long, val duration: Long) : PlayerEvent
        data class Zoom(val scale: Float) : PlayerEvent
        data class SubtitleStateChanged(val enabled: Boolean) : PlayerEvent
        data class SubtitleTrackChanged(val index: Int) : PlayerEvent
        data class AudioTrackChanged(val groupIndex: Int, val trackIndex: Int) : PlayerEvent
        data class AudioTracksChanged(val tracks: List<Map<String, Any?>>) : PlayerEvent
        data class PiPModeChanged(val isInPiP: Boolean) : PlayerEvent
        data class BackgroundPlaybackChanged(val enabled: Boolean) : PlayerEvent
        data class AudioOnlyModeChanged(val enabled: Boolean) : PlayerEvent
        data class ScreenshotCaptured(val filePath: String) : PlayerEvent
        data class ScreenshotDeleted(val filePath: String) : PlayerEvent
        data class RepeatModeChanged(val mode: String) : PlayerEvent
        data class RepeatPointSet(val point: String, val position: Long) : PlayerEvent
        data class KidsLockChanged(val enabled: Boolean) : PlayerEvent
        data class OrientationChanged(val orientation: String) : PlayerEvent
        data class AutoRotateChanged(val enabled: Boolean) : PlayerEvent
        data class OrientationLockChanged(val locked: Boolean) : PlayerEvent
        data class DeviceOrientationChanged(val orientation: String) : PlayerEvent
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
