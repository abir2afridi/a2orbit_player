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
