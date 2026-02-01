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
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.launch
import java.io.File
import kotlin.math.max
import kotlin.math.min

@OptIn(UnstableApi::class)
class A2OrbitPlayerController(
    context: Context,
    private val activity: Activity?,
    lifecycleOwner: LifecycleOwner?,
) : Player.Listener, DefaultLifecycleObserver {

    private val mainScope = CoroutineScope(Dispatchers.Main + Job())
    private val appContext = context.applicationContext

    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
    private val contentResolver = context.contentResolver

    private val renderersFactory = A2OrbitRenderersFactory(context)
    private val trackSelector = DefaultTrackSelector(context)
    private val dataSourceFactory = DefaultDataSource.Factory(context)

    val player: ExoPlayer = ExoPlayer.Builder(context, renderersFactory)
        .setTrackSelector(trackSelector)
        .build()

    private var playerView: A2OrbitPlayerView? = null
    private var currentMediaItem: MediaItem? = null
    private var subtitlesDelayMs: Long = 0
    private var audioDelayMs: Long = 0
    private var reportingJob: Job? = null
    private var hasTriedProgressiveFallback = false
    private var lastSourceConfig: SourceConfig? = null

    private val _events = MutableSharedFlow<PlayerEvent>(extraBufferCapacity = 32)
    val events: SharedFlow<PlayerEvent> = _events

    private var brightnessBeforeGesture: Float = -1f
    private var volumeBeforeGesture: Int = 0
    private var maxVolume: Int = audioManager?.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC) ?: 15
    private var pendingSeekPosition: Long? = null

    init {
        player.addListener(this)
        lifecycleOwner?.lifecycle?.addObserver(this)
    }

    fun attachView(view: A2OrbitPlayerView) {
        playerView = view
        view.gestureListener = object : A2OrbitPlayerView.GestureListener {
            override fun onSingleTap() {
                mainScope.launch { _events.emit(PlayerEvent.Gesture(PlayerConstants.Events.GESTURE, "single_tap")) }
            }

            override fun onDoubleTap(onRight: Boolean) {
                val delta = if (onRight) 10000 else -10000
                val target = (player.currentPosition + delta).coerceIn(0, player.duration)
                seekTo(target)
                playerView?.showGestureOverlay(if (delta > 0) "+10s" else "-10s")
                mainScope.launch { _events.emit(PlayerEvent.Gesture(PlayerConstants.Events.GESTURE, if (delta > 0) "double_tap_forward" else "double_tap_rewind")) }
            }

            override fun onVerticalScroll(isLeftHalf: Boolean, delta: Float) {
                if (isLeftHalf) {
                    adjustBrightness(-delta)
                } else {
                    adjustVolume(-delta)
                }
            }

            override fun onHorizontalScroll(delta: Float) {
                adjustSeek(delta)
            }

            override fun onGestureEnd() {
                pendingSeekPosition?.let {
                    seekTo(it)
                    pendingSeekPosition = null
                }
                brightnessBeforeGesture = -1f
                volumeBeforeGesture = 0
                playerView?.showGestureOverlay("")
            }
        }
    }

    fun setDataSource(path: String, subtitlePaths: List<String> = emptyList()) {
        if (path.isBlank()) {
            emitError("invalid_source", "Video path is empty")
            return
        }

        if (!hasVideoReadPermission()) {
            emitError("missing_permission", "Storage permission is required to play this file")
            return
        }

        val resolvedUri = resolvePlayableUri(path)
        if (resolvedUri == null) {
            emitError("unreachable_uri", "Unable to resolve a playable URI for this file")
            return
        }

        grantReadPermission(resolvedUri)
        Log.d(TAG, "Preparing media item: uri=$resolvedUri")

        val subtitleConfigs = subtitlePaths.mapNotNull { subtitlePath ->
            runCatching {
                val subtitleUri = resolvePlayableUri(subtitlePath)
                if (subtitleUri != null) {
                    grantReadPermission(subtitleUri)
                    MediaItem.SubtitleConfiguration.Builder(subtitleUri)
                        .setMimeType("application/x-subrip")
                        .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                        .build()
                } else {
                    null
                }
            }.onFailure {
                Log.w(TAG, "Unable to load subtitle: $subtitlePath", it)
            }.getOrNull()
        }

        val mimeType = detectMimeType(resolvedUri, path)
        hasTriedProgressiveFallback = false

        val mediaItem = MediaItem.Builder()
            .setUri(resolvedUri)
            .setMediaId(path)
            .setMimeType(mimeType)
            .setSubtitleConfigurations(subtitleConfigs)
            .build()

        currentMediaItem = mediaItem
        lastSourceConfig = SourceConfig(resolvedUri, mimeType, subtitleConfigs)
        prepareAndPlay(mediaItem, useProgressive = false)
    }

    fun play() {
        player.play()
    }

    fun pause() {
        player.pause()
    }

    fun seekTo(positionMs: Long) {
        player.seekTo(positionMs)
    }

    fun setPlaybackSpeed(speed: Float) {
        player.playbackParameters = PlaybackParameters(speed)
    }

    fun setDecoder(decoder: String) {
        renderersFactory.updateDecoderPreference(decoder)
        currentMediaItem?.let {
            val currentPosition = player.currentPosition
            val playWhenReady = player.playWhenReady
            player.setMediaItem(it)
            player.prepare()
            player.seekTo(currentPosition)
            player.playWhenReady = playWhenReady
        }
    }

    fun getAudioTracks(): List<AudioTrackInfo> {
        val audioTracks = mutableListOf<AudioTrackInfo>()
        player.currentTracks.groups.forEachIndexed { groupIndex, group ->
            val trackGroup = group.mediaTrackGroup
            if (group.type == C.TRACK_TYPE_AUDIO) {
                for (i in 0 until trackGroup.length) {
                    val format = trackGroup.getFormat(i)
                    audioTracks.add(
                        AudioTrackInfo(
                            groupIndex = groupIndex,
                            trackIndex = i,
                            id = format.id ?: "track_$i",
                            language = format.language ?: "Unknown",
                            label = format.label ?: format.language ?: "Track ${i + 1}",
                        ),
                    )
                }
            }
        }
        return audioTracks
    }

    fun switchAudioTrack(groupIndex: Int, trackIndex: Int) {
        val group = player.currentTracks.groups.getOrNull(groupIndex) ?: return
        val trackGroup = group.mediaTrackGroup
        val override = TrackSelectionOverride(trackGroup, listOf(trackIndex))
        val parametersBuilder = trackSelector.parameters.buildUpon()
        parametersBuilder.clearOverridesOfType(C.TRACK_TYPE_AUDIO)
        parametersBuilder.addOverride(override)
        trackSelector.parameters = parametersBuilder.build()
    }

    fun getSubtitleTracks(): List<SubtitleInfo> {
        val subtitles = mutableListOf<SubtitleInfo>()
        player.currentTracks.groups.forEachIndexed { groupIndex, group ->
            if (group.type == C.TRACK_TYPE_TEXT) {
                val trackGroup = group.mediaTrackGroup
                for (i in 0 until trackGroup.length) {
                    val format = trackGroup.getFormat(i)
                    subtitles.add(
                        SubtitleInfo(
                            groupIndex = groupIndex,
                            trackIndex = i,
                            language = format.language ?: "Unknown",
                            label = format.label ?: "Subtitle ${i + 1}",
                        ),
                    )
                }
            }
        }
        return subtitles
    }

    fun selectSubtitle(groupIndex: Int, trackIndex: Int?) {
        val builder = trackSelector.parameters.buildUpon()
        builder.clearOverridesOfType(C.TRACK_TYPE_TEXT)
        if (trackIndex != null) {
            val group = player.currentTracks.groups.getOrNull(groupIndex) ?: return
            val trackGroup = group.mediaTrackGroup
            val override = TrackSelectionOverride(trackGroup, listOf(trackIndex))
            builder.addOverride(override)
        }
        trackSelector.parameters = builder.build()
    }

    fun setSubtitleDelay(delayMs: Long) {
        subtitlesDelayMs = delayMs
        // ExoPlayer doesn't support subtitle delay directly; placeholder for future custom renderer.
    }

    fun setAudioDelay(delayMs: Long) {
        audioDelayMs = delayMs
        // Audio delay processing not available without FFmpeg extension
    }

    fun setAspectRatio(resizeMode: Int) {
        player.videoScalingMode = resizeMode
        playerView?.setResizeMode(resizeMode)
    }

    fun enterPiP() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity?.enterPictureInPictureMode()
        }
    }

    fun lockRotation(lock: Boolean) {
        activity?.requestedOrientation = if (lock) ActivityInfo.SCREEN_ORIENTATION_LOCKED else ActivityInfo.SCREEN_ORIENTATION_SENSOR
    }

    fun getVideoInformation(): Map<String, Any?> {
        val videoFormat = player.videoFormat
        val audioFormat = player.audioFormat
        val duration = player.duration
        val file = currentMediaItem?.localConfiguration?.uri?.path?.let { File(it) }
        return mapOf(
            "videoCodec" to videoFormat?.codecs,
            "width" to videoFormat?.width,
            "height" to videoFormat?.height,
            "frameRate" to videoFormat?.frameRate,
            "audioCodec" to audioFormat?.codecs,
            "audioChannels" to audioFormat?.channelCount,
            "audioSampleRate" to audioFormat?.sampleRate,
            "duration" to duration,
            "size" to file?.length(),
            "path" to file?.absolutePath,
        )
    }

    fun release() {
        reportingJob?.cancel()
        player.removeListener(this)
        player.release()
    }

    // Player.Listener implementation
    override fun onEvents(player: Player, events: Player.Events) {
        if (events.containsAny(Player.EVENT_PLAYBACK_STATE_CHANGED, Player.EVENT_PLAY_WHEN_READY_CHANGED)) {
            handlePlaybackState(player.isPlaying)
        }
        if (events.contains(Player.EVENT_TRACKS_CHANGED)) {
            mainScope.launch { _events.emit(PlayerEvent.TracksChanged(player.currentTracks)) }
        }
        if (events.contains(Player.EVENT_PLAYER_ERROR)) {
            val error = player.playerError
            if (error != null && retryWithProgressiveSource("error:${error.errorCodeName}")) {
                return
            }
            emitError(error?.errorCodeName ?: "unknown", error?.message ?: "Playback failed")
        }
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        Log.d(TAG, "onPlaybackStateChanged: state=$playbackState")
        if (playbackState == Player.STATE_IDLE) {
            retryWithProgressiveSource("state_idle")
        }
    }

    private fun handlePlaybackState(isPlaying: Boolean) {
        if (isPlaying) {
            startPositionReporting()
        } else {
            reportingJob?.cancel()
        }
    }

    private fun resolvePlayableUri(path: String): Uri? {
        val trimmed = path.trim()
        if (trimmed.isBlank()) return null
        val parsed = runCatching { Uri.parse(trimmed) }.getOrNull()
        if (parsed != null && ("content" == parsed.scheme || "file" == parsed.scheme)) {
            return if ("content" == parsed.scheme) parsed else buildFileProviderUri(File(parsed.path ?: return null))
        }

        val file = File(trimmed)
        if (!file.exists()) {
            Log.w(TAG, "File does not exist: $trimmed")
            return parsed
        }

        findMediaStoreUri(file)?.let { return it }
        return buildFileProviderUri(file)
    }

    private fun buildFileProviderUri(file: File): Uri? {
        return try {
            FileProvider.getUriForFile(appContext, "${appContext.packageName}.fileprovider", file)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "FileProvider failed for ${file.path}", e)
            Uri.fromFile(file)
        }
    }

    @SuppressLint("ObsoleteSdkInt", "Range")
    private fun findMediaStoreUri(file: File): Uri? {
        if (!file.exists()) return null
        val projection = arrayOf(MediaStore.Video.Media._ID, MediaStore.Video.Media.DATA)
        val selection = "${MediaStore.Video.Media.DATA} = ?"
        val selectionArgs = arrayOf(file.absolutePath)
        return try {
            contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null,
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

    private fun detectMimeType(uri: Uri, fallbackPath: String?): String? {
        val resolverType = contentResolver.getType(uri)
        if (!resolverType.isNullOrBlank()) return resolverType

        val extension = when {
            !uri.path.isNullOrBlank() -> MimeTypeMap.getFileExtensionFromUrl(uri.toString())
            !fallbackPath.isNullOrBlank() -> MimeTypeMap.getFileExtensionFromUrl(fallbackPath)
            else -> null
        }
        if (!extension.isNullOrBlank()) {
            MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase())?.let { return it }
        }

        return when (extension?.lowercase()) {
            "mkv" -> "video/x-matroska"
            "mp4", "m4v" -> "video/mp4"
            "avi" -> "video/x-msvideo"
            "mov" -> "video/quicktime"
            "wmv" -> "video/x-ms-wmv"
            "flv" -> "video/x-flv"
            "ts", "mts", "m2ts" -> "video/mp2t"
            else -> null
        }
    }

    private fun prepareAndPlay(mediaItem: MediaItem, useProgressive: Boolean) {
        try {
            Log.d(TAG, "prepareAndPlay: useProgressive=$useProgressive uri=${mediaItem.localConfiguration?.uri}")
            if (useProgressive) {
                val mediaSource = ProgressiveMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
                player.setMediaSource(mediaSource)
            } else {
                player.setMediaItem(mediaItem)
            }
            player.prepare()
            Log.d(TAG, "prepareAndPlay: prepare() called, state=${player.playbackState}, playWhenReady=${player.playWhenReady}")
            player.playWhenReady = true
            Log.d(TAG, "prepareAndPlay: playWhenReady set to true")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to prepare media item", e)
            if (!useProgressive && retryWithProgressiveSource("prepare_exception")) {
                return
            }
            emitError("prepare_failed", e.message ?: "Unable to start playback")
        }
    }

    private fun retryWithProgressiveSource(reason: String): Boolean {
        val config = lastSourceConfig ?: return false
        if (hasTriedProgressiveFallback) {
            return false
        }
        hasTriedProgressiveFallback = true
        Log.w(TAG, "Retrying playback with ProgressiveMediaSource fallback due to $reason")
        val fallbackItem = MediaItem.Builder()
            .setUri(config.uri)
            .setMimeType(config.mimeType)
            .setSubtitleConfigurations(config.subtitleConfigs)
            .build()
        prepareAndPlay(fallbackItem, useProgressive = true)
        return true
    }

    private fun hasVideoReadPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(appContext, Manifest.permission.READ_MEDIA_VIDEO) == PackageManager.PERMISSION_GRANTED || Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(appContext, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED || Environment.isExternalStorageManager()
        }
    }

    private fun grantReadPermission(uri: Uri) {
        try {
            appContext.grantUriPermission(appContext.packageName, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (e: SecurityException) {
            Log.w(TAG, "Unable to grant uri permission for $uri", e)
        }
    }

    private fun emitError(code: String, message: String) {
        mainScope.launch {
            _events.emit(PlayerEvent.Error(code, message))
        }
    }

    private fun startPositionReporting() {
        reportingJob?.cancel()
        reportingJob = mainScope.launch {
            while (true) {
                _events.emit(PlayerEvent.Position(player.currentPosition, player.duration))
                delay(500)
            }
        }
    }

    override fun onStop(owner: LifecycleOwner) {
        pause()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        release()
    }

    data class AudioTrackInfo(val groupIndex: Int, val trackIndex: Int, val id: String, val language: String, val label: String)
    data class SubtitleInfo(val groupIndex: Int, val trackIndex: Int, val language: String, val label: String)

    sealed interface PlayerEvent {
        data class PlaybackState(val state: Int, val playWhenReady: Boolean) : PlayerEvent
        data class Error(val code: String, val message: String) : PlayerEvent
        data class Position(val positionMs: Long, val durationMs: Long) : PlayerEvent
        data class TracksChanged(val tracks: Tracks) : PlayerEvent
        data class Gesture(val eventType: String, val action: String) : PlayerEvent
    }

    private fun adjustBrightness(delta: Float) {
        val activity = activity ?: return
        val attributes = activity.window.attributes
        if (brightnessBeforeGesture < 0) {
            brightnessBeforeGesture = if (attributes.screenBrightness >= 0) attributes.screenBrightness else getSystemBrightness()
        }
        var newBrightness = brightnessBeforeGesture + delta / height
        newBrightness = newBrightness.coerceIn(0.05f, 1f)
        attributes.screenBrightness = newBrightness
        activity.window.attributes = attributes
        playerView?.showGestureOverlay("Brightness ${(newBrightness * 100).toInt()}%")
        mainScope.launch { _events.emit(PlayerEvent.Gesture(PlayerConstants.Events.GESTURE, "brightness")) }
    }

    private fun adjustVolume(delta: Float) {
        val audioManager = audioManager ?: return
        if (volumeBeforeGesture == 0) {
            volumeBeforeGesture = audioManager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)
        }
        val newVolume = (volumeBeforeGesture + (delta / height * maxVolume)).toInt().coerceIn(0, maxVolume)
        audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, newVolume, 0)
        playerView?.showGestureOverlay("Volume ${(newVolume * 100 / maxVolume)}%")
        mainScope.launch { _events.emit(PlayerEvent.Gesture(PlayerConstants.Events.GESTURE, "volume")) }
    }

    private fun adjustSeek(delta: Float) {
        val duration = if (player.duration > 0) player.duration else 0
        val current = player.currentPosition
        val screenWidth = playerView?.width?.takeIf { it > 0 } ?: windowManager?.defaultDisplay?.let { display ->
            val size = Point()
            display.getSize(size)
            size.x
        } ?: 1
        val multiplier = (delta / screenWidth) * duration
        val target = (pendingSeekPosition ?: current) + multiplier.toLong()
        val clamped = target.coerceIn(0, duration)
        pendingSeekPosition = clamped
        playerView?.showGestureOverlay(formatSeekOverlay(clamped, duration))
        mainScope.launch { _events.emit(PlayerEvent.Gesture(PlayerConstants.Events.GESTURE, "seek")) }
    }

    private fun formatSeekOverlay(position: Long, duration: Long): String {
        fun format(durationMs: Long): String {
            val totalSeconds = durationMs / 1000
            val seconds = totalSeconds % 60
            val minutes = (totalSeconds / 60) % 60
            val hours = totalSeconds / 3600
            return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, seconds) else "%02d:%02d".format(minutes, seconds)
        }
        return "${format(position)} / ${format(duration)}"
    }

    private val height: Float
        get() = (playerView?.height?.toFloat() ?: 1f)

    private fun getSystemBrightness(): Float {
        return try {
            Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS) / 255f
        } catch (e: Settings.SettingNotFoundException) {
            0.5f
        }
    }

    private data class SourceConfig(
        val uri: Uri,
        val mimeType: String?,
        val subtitleConfigs: List<MediaItem.SubtitleConfiguration>,
    )

    companion object {
        private const val TAG = "A2OrbitPlayerController"
    }
}
