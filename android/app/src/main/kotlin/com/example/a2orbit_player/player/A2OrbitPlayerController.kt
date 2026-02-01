package com.example.a2orbit_player.player

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import android.graphics.Point
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
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
import androidx.media3.exoplayer.ExoPlayer
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

    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
    private val contentResolver = context.contentResolver

    private val renderersFactory = A2OrbitRenderersFactory(context)
    private val trackSelector = DefaultTrackSelector(context)

    val player: ExoPlayer = ExoPlayer.Builder(context, renderersFactory)
        .setTrackSelector(trackSelector)
        .build()

    private var playerView: A2OrbitPlayerView? = null
    private var currentMediaItem: MediaItem? = null
    private var subtitlesDelayMs: Long = 0
    private var audioDelayMs: Long = 0
    private var reportingJob: Job? = null
    private var autoPiPEnabled: Boolean = true

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
        val subtitleConfigs = subtitlePaths.map { subtitlePath ->
            MediaItem.SubtitleConfiguration.Builder(Uri.fromFile(File(subtitlePath)))
                .setMimeType("application/x-subrip")
                .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                .build()
        }

        val mediaItem = MediaItem.Builder()
            .setUri(Uri.fromFile(File(path)))
            .setMediaId(path)
            .setSubtitleConfigurations(subtitleConfigs)
            .build()

        currentMediaItem = mediaItem
        player.setMediaItem(mediaItem)
        player.prepare()
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

    fun togglePiP(enable: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            autoPiPEnabled = enable
            if (enable) enterPiP()
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
            mainScope.launch { _events.emit(PlayerEvent.Error(error?.errorCodeName ?: "unknown", error?.message ?: "")) }
        }
    }

    private fun handlePlaybackState(isPlaying: Boolean) {
        if (!isPlaying && autoPiPEnabled) {
            enterPiP()
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
}
