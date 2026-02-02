package com.example.a2orbit_player.player

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import android.os.Build
import android.util.Log
import android.view.WindowManager
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Robust Player Manager for handling multiple player instances and Flutter communication
 */
class RobustPlayerManager(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner?,
) {

    companion object {
        private const val TAG = "RobustPlayerManager"
    }

    private val activePlayers = mutableMapOf<Int, RobustExoPlayerController>()
    private val mainScope = CoroutineScope(Dispatchers.Main)
    private var eventSink: EventChannel.EventSink? = null

    /**
     * Register a new player view
     */
    fun registerView(viewId: Int, controller: RobustExoPlayerController) {
        activePlayers[viewId] = controller
        
        // Start listening to player events
        mainScope.launch {
            controller.events.collect { event ->
                handlePlayerEvent(viewId, event)
            }
        }
        
        Log.d(TAG, "Registered player view: $viewId")
    }

    /**
     * Unregister a player view
     */
    fun unregisterView(viewId: Int) {
        activePlayers.remove(viewId)?.release()
        Log.d(TAG, "Unregistered player view: $viewId")
    }

    /**
     * Get controller for specific view
     */
    private fun getController(viewId: Int): RobustExoPlayerController? {
        return activePlayers[viewId]
    }

    /**
     * Set event sink for Flutter communication
     */
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    /**
     * Handle player events and forward to Flutter
     */
    private fun handlePlayerEvent(viewId: Int, event: RobustExoPlayerController.PlayerEvent) {
        val eventData = when (event) {
            is RobustExoPlayerController.PlayerEvent.PlaybackState -> mapOf(
                "type" to "playbackState",
                "viewId" to viewId,
                "state" to event.state,
                "isPlaying" to event.isPlaying,
                "isBuffering" to event.isBuffering,
                "isEnded" to event.isEnded
            )
            is RobustExoPlayerController.PlayerEvent.Error -> mapOf(
                "type" to "error",
                "viewId" to viewId,
                "code" to event.code,
                "message" to event.message
            )
            is RobustExoPlayerController.PlayerEvent.Position -> mapOf(
                "type" to "position",
                "viewId" to viewId,
                "position" to event.positionMs,
                "duration" to event.durationMs
            )
            is RobustExoPlayerController.PlayerEvent.TracksChanged -> {
                val audioTracks = mutableListOf<Map<String, Any>>()
                val subtitleTracks = mutableListOf<Map<String, Any>>()
                
                event.tracks.groups.forEachIndexed { groupIndex, group ->
                    val trackGroup = group.mediaTrackGroup
                    when (group.type) {
                        1 -> { // C.TRACK_TYPE_AUDIO
                            for (i in 0 until trackGroup.length) {
                                val format = trackGroup.getFormat(i)
                                audioTracks.add(mapOf(
                                    "groupIndex" to groupIndex,
                                    "trackIndex" to i,
                                    "id" to (format.id ?: "track_$i"),
                                    "language" to (format.language ?: "Unknown"),
                                    "label" to (format.label ?: format.language ?: "Track ${i + 1}")
                                ))
                            }
                        }
                        3 -> { // C.TRACK_TYPE_TEXT
                            for (i in 0 until trackGroup.length) {
                                val format = trackGroup.getFormat(i)
                                subtitleTracks.add(mapOf(
                                    "groupIndex" to groupIndex,
                                    "trackIndex" to i,
                                    "language" to (format.language ?: "Unknown"),
                                    "label" to (format.label ?: "Subtitle ${i + 1}")
                                ))
                            }
                        }
                    }
                }
                
                mapOf(
                    "type" to "tracksChanged",
                    "viewId" to viewId,
                    "audioTracks" to audioTracks,
                    "subtitleTracks" to subtitleTracks
                )
            }
            is RobustExoPlayerController.PlayerEvent.Gesture -> mapOf(
                "type" to "gesture",
                "viewId" to viewId,
                "action" to event.action,
                "value" to event.value
            )
            is RobustExoPlayerController.PlayerEvent.BrightnessChanged -> mapOf(
                "type" to "brightnessChanged",
                "viewId" to viewId,
                "brightness" to event.brightness
            )
            is RobustExoPlayerController.PlayerEvent.VolumeChanged -> mapOf(
                "type" to "volumeChanged",
                "viewId" to viewId,
                "volume" to event.volume,
                "maxVolume" to event.maxVolume
            )
            is RobustExoPlayerController.PlayerEvent.Seek -> mapOf(
                "type" to "seek",
                "viewId" to viewId,
                "position" to event.position,
                "duration" to event.duration
            )
            is RobustExoPlayerController.PlayerEvent.Zoom -> mapOf(
                "type" to "zoom",
                "viewId" to viewId,
                "scale" to event.scale
            )
            is RobustExoPlayerController.PlayerEvent.SubtitleStateChanged -> mapOf(
                "type" to "subtitleStateChanged",
                "viewId" to viewId,
                "enabled" to event.enabled
            )
            is RobustExoPlayerController.PlayerEvent.SubtitleTrackChanged -> mapOf(
                "type" to "subtitleTrackChanged",
                "viewId" to viewId,
                "index" to event.index
            )
            is RobustExoPlayerController.PlayerEvent.AudioTrackChanged -> mapOf(
                "type" to "audioTrackChanged",
                "viewId" to viewId,
                "groupIndex" to event.groupIndex,
                "trackIndex" to event.trackIndex
            )
            is RobustExoPlayerController.PlayerEvent.AudioTracksChanged -> mapOf(
                "type" to "audioTracksChanged",
                "viewId" to viewId,
                "tracks" to event.tracks
            )
            is RobustExoPlayerController.PlayerEvent.PiPModeChanged -> mapOf(
                "type" to "pipModeChanged",
                "viewId" to viewId,
                "isInPiP" to event.isInPiP
            )
            is RobustExoPlayerController.PlayerEvent.BackgroundPlaybackChanged -> mapOf(
                "type" to "backgroundPlaybackChanged",
                "viewId" to viewId,
                "enabled" to event.enabled
            )
            is RobustExoPlayerController.PlayerEvent.AudioOnlyModeChanged -> mapOf(
                "type" to "audioOnlyModeChanged",
                "viewId" to viewId,
                "enabled" to event.enabled
            )
            is RobustExoPlayerController.PlayerEvent.ScreenshotCaptured -> mapOf(
                "type" to "screenshotCaptured",
                "viewId" to viewId,
                "filePath" to event.filePath
            )
            is RobustExoPlayerController.PlayerEvent.ScreenshotDeleted -> mapOf(
                "type" to "screenshotDeleted",
                "viewId" to viewId,
                "filePath" to event.filePath
            )
            is RobustExoPlayerController.PlayerEvent.RepeatModeChanged -> mapOf(
                "type" to "repeatModeChanged",
                "viewId" to viewId,
                "mode" to event.mode
            )
            is RobustExoPlayerController.PlayerEvent.RepeatPointSet -> mapOf(
                "type" to "repeatPointSet",
                "viewId" to viewId,
                "point" to event.point,
                "position" to event.position
            )
            is RobustExoPlayerController.PlayerEvent.KidsLockChanged -> mapOf(
                "type" to "kidsLockChanged",
                "viewId" to viewId,
                "enabled" to event.enabled
            )
            is RobustExoPlayerController.PlayerEvent.OrientationChanged -> mapOf(
                "type" to "orientationChanged",
                "viewId" to viewId,
                "orientation" to event.orientation
            )
            is RobustExoPlayerController.PlayerEvent.AutoRotateChanged -> mapOf(
                "type" to "autoRotateChanged",
                "viewId" to viewId,
                "enabled" to event.enabled
            )
            is RobustExoPlayerController.PlayerEvent.OrientationLockChanged -> mapOf(
                "type" to "orientationLockChanged",
                "viewId" to viewId,
                "locked" to event.locked
            )
            is RobustExoPlayerController.PlayerEvent.DeviceOrientationChanged -> mapOf(
                "type" to "deviceOrientationChanged",
                "viewId" to viewId,
                "orientation" to event.orientation
            )
        }
        
        try {
            eventSink?.success(eventData)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending event to Flutter", e)
        }
    }

    // Player control methods
    fun setDataSource(viewId: Int, path: String, subtitles: List<String> = emptyList()) {
        getController(viewId)?.setVideoSource(path, subtitles)
    }

    fun play(viewId: Int) {
        getController(viewId)?.play()
    }

    fun pause(viewId: Int) {
        getController(viewId)?.pause()
    }

    fun seekTo(viewId: Int, positionMs: Long) {
        getController(viewId)?.seekTo(positionMs)
    }

    fun setPlaybackSpeed(viewId: Int, speed: Float) {
        getController(viewId)?.setPlaybackSpeed(speed)
    }

    fun setAspectRatio(viewId: Int, resizeMode: Int) {
        getController(viewId)?.setAspectRatio(resizeMode)
    }

    fun getVideoInformation(viewId: Int): Map<String, Any?>? {
        return getController(viewId)?.getVideoInformation()
    }

    fun enterPiP(viewId: Int) {
        // PiP implementation would go here
        Log.d(TAG, "PiP requested for viewId: $viewId")
    }

    fun lockRotation(viewId: Int, lock: Boolean) {
        val activity = context as? Activity
        activity?.requestedOrientation = if (lock) {
            ActivityInfo.SCREEN_ORIENTATION_LOCKED
        } else {
            ActivityInfo.SCREEN_ORIENTATION_SENSOR
        }
    }

    fun setGesturesEnabled(viewId: Int, enabled: Boolean) {
        // Gesture enable/disable would be handled in the view
        Log.d(TAG, "Gestures ${if (enabled) "enabled" else "disabled"} for viewId: $viewId")
    }
    
    fun handleBrightnessGesture(viewId: Int, delta: Float) {
        getController(viewId)?.handleBrightnessGesture(delta)
    }
    
    fun handleVolumeGesture(viewId: Int, delta: Float) {
        getController(viewId)?.handleVolumeGesture(delta)
    }
    
    fun handleSeekGesture(viewId: Int, delta: Float) {
        getController(viewId)?.handleSeekGesture(delta)
    }
    
    fun handleZoomGesture(viewId: Int, scale: Float) {
        getController(viewId)?.handleZoomGesture(scale)
    }
    
    fun resetGestureStates(viewId: Int) {
        getController(viewId)?.resetGestureStates()
    }
    
    fun loadSubtitles(viewId: Int, subtitlePaths: List<String>) {
        getController(viewId)?.loadSubtitles(subtitlePaths)
    }
    
    fun setSubtitlesEnabled(viewId: Int, enabled: Boolean) {
        getController(viewId)?.setSubtitlesEnabled(enabled)
    }
    
    fun selectSubtitleTrack(viewId: Int, index: Int) {
        getController(viewId)?.selectSubtitleTrack(index)
    }
    
    fun getSubtitleTracks(viewId: Int): List<Map<String, Any>> {
        return getController(viewId)?.getSubtitleTracks() ?: emptyList()
    }
    
    fun getAudioTracks(viewId: Int): List<Map<String, Any>> {
        return getController(viewId)?.getAudioTracks() ?: emptyList()
    }
    
    fun selectAudioTrack(viewId: Int, groupIndex: Int, trackIndex: Int) {
        getController(viewId)?.selectAudioTrack(groupIndex, trackIndex)
    }
    
    fun getCurrentAudioTrack(viewId: Int): Map<String, Any>? {
        return getController(viewId)?.getCurrentAudioTrack()
    }
    
    fun enterPictureInPicture(viewId: Int): Boolean {
        return getController(viewId)?.enterPictureInPicture() ?: false
    }
    
    fun exitPictureInPicture(viewId: Int) {
        getController(viewId)?.exitPictureInPicture()
    }
    
    fun isInPictureInPictureMode(viewId: Int): Boolean {
        return getController(viewId)?.isInPictureInPictureMode() ?: false
    }
    
    fun setBackgroundPlaybackEnabled(viewId: Int, enabled: Boolean) {
        getController(viewId)?.setBackgroundPlaybackEnabled(enabled)
    }
    
    fun isBackgroundPlaybackEnabled(viewId: Int): Boolean {
        return getController(viewId)?.isBackgroundPlaybackEnabled() ?: false
    }
    
    fun enableAudioOnlyMode(viewId: Int) {
        getController(viewId)?.enableAudioOnlyMode()
    }
    
    fun disableAudioOnlyMode(viewId: Int) {
        getController(viewId)?.disableAudioOnlyMode()
    }
    
    fun onAppBackgrounded(viewId: Int) {
        getController(viewId)?.onAppBackgrounded()
    }
    
    fun onAppForegrounded(viewId: Int) {
        getController(viewId)?.onAppForegrounded()
    }
    
    // Screenshot methods
    fun captureScreenshot(viewId: Int): String? {
        return getController(viewId)?.captureScreenshot()
    }
    
    fun getLastScreenshotPath(viewId: Int): String? {
        return getController(viewId)?.getLastScreenshotPath()
    }
    
    fun getScreenshotFiles(viewId: Int): List<String> {
        return getController(viewId)?.getScreenshotFiles() ?: emptyList()
    }
    
    fun deleteScreenshot(viewId: Int, filePath: String): Boolean {
        return getController(viewId)?.deleteScreenshot(filePath) ?: false
    }
    
    // A-B repeat methods
    fun setRepeatStartPoint(viewId: Int) {
        getController(viewId)?.setRepeatStartPoint()
    }
    
    fun setRepeatEndPoint(viewId: Int) {
        getController(viewId)?.setRepeatEndPoint()
    }
    
    fun clearRepeatPoints(viewId: Int) {
        getController(viewId)?.clearRepeatPoints()
    }
    
    fun setRepeatMode(viewId: Int, mode: String) {
        getController(viewId)?.setRepeatMode(mode)
    }
    
    fun getRepeatMode(viewId: Int): String {
        return getController(viewId)?.getRepeatMode() ?: "NONE"
    }
    
    fun getRepeatPoints(viewId: Int): Map<String, Long> {
        return getController(viewId)?.getRepeatPoints() ?: emptyMap()
    }
    
    fun isRepeatABActive(viewId: Int): Boolean {
        return getController(viewId)?.isRepeatABActive() ?: false
    }
    
    // Kids lock methods
    fun setKidsLockEnabled(viewId: Int, enabled: Boolean, pin: String = "0000") {
        getController(viewId)?.setKidsLockEnabled(enabled, pin)
    }
    
    fun isKidsLockEnabled(viewId: Int): Boolean {
        return getController(viewId)?.isKidsLockEnabled() ?: false
    }
    
    fun verifyKidsLockPin(viewId: Int, pin: String): Boolean {
        return getController(viewId)?.verifyKidsLockPin(pin) ?: false
    }
    
    fun disableKidsLockWithPin(viewId: Int, pin: String): Boolean {
        return getController(viewId)?.disableKidsLockWithPin(pin) ?: false
    }
    
    // Orientation control methods
    fun setOrientation(viewId: Int, orientation: String) {
        getController(viewId)?.setOrientation(orientation)
    }
    
    fun getCurrentOrientation(viewId: Int): String {
        return getController(viewId)?.getCurrentOrientation() ?: "AUTO"
    }
    
    fun setAutoRotateEnabled(viewId: Int, enabled: Boolean) {
        getController(viewId)?.setAutoRotateEnabled(enabled)
    }
    
    fun isAutoRotateEnabled(viewId: Int): Boolean {
        return getController(viewId)?.isAutoRotateEnabled() ?: true
    }
    
    fun setOrientationLocked(viewId: Int, locked: Boolean) {
        getController(viewId)?.setOrientationLocked(locked)
    }
    
    fun isOrientationLocked(viewId: Int): Boolean {
        return getController(viewId)?.isOrientationLocked() ?: false
    }
    
    fun toggleOrientation(viewId: Int) {
        getController(viewId)?.toggleOrientation()
    }
    
    fun onConfigurationChanged(viewId: Int, newConfig: android.content.res.Configuration) {
        getController(viewId)?.onConfigurationChanged(newConfig)
    }

    /**
     * Release all active players
     */
    fun releaseAll() {
        Log.d(TAG, "Releasing all players")
        activePlayers.values.forEach { it.release() }
        activePlayers.clear()
        eventSink = null
    }
}
