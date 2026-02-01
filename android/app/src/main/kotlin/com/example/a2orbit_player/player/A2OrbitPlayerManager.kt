package com.example.a2orbit_player.player

import android.app.Activity
import android.content.Context
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class A2OrbitPlayerManager(
    private val activity: Activity?,
    private val lifecycleOwner: LifecycleOwner?,
) {
    private data class Entry(
        val view: A2OrbitPlayerPlatformView,
        var eventJob: Job?,
    )

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val views = mutableMapOf<Int, Entry>()
    private var eventSink: EventChannel.EventSink? = null

    fun registerView(id: Int, platformView: A2OrbitPlayerPlatformView) {
        views[id]?.eventJob?.cancel()
        val job = scope.launch {
            platformView.controller.events.collectLatest { event ->
                eventSink?.success(event.toMap(id))
            }
        }
        views[id] = Entry(platformView, job)
    }

    fun unregisterView(id: Int, releaseController: Boolean = true) {
        views.remove(id)?.let { entry ->
            entry.eventJob?.cancel()
            if (releaseController) {
                entry.view.controller.release()
            }
        }
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun createPlatformView(context: Context, viewId: Int): A2OrbitPlayerPlatformView {
        val view = A2OrbitPlayerPlatformView(activity, context, viewId, lifecycleOwner, this)
        registerView(viewId, view)
        return view
    }

    fun getController(viewId: Int): A2OrbitPlayerController? = views[viewId]?.view?.controller

    fun setDataSource(viewId: Int, path: String, subtitles: List<String>) {
        getController(viewId)?.setDataSource(path, subtitles)
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

    fun setDecoder(viewId: Int, decoder: String) {
        getController(viewId)?.setDecoder(decoder)
    }

    fun getAudioTracks(viewId: Int): List<Map<String, Any?>> {
        val controller = getController(viewId) ?: return emptyList()
        return controller.getAudioTracks().map { track ->
            mapOf(
                "groupIndex" to track.groupIndex,
                "trackIndex" to track.trackIndex,
                "id" to track.id,
                "language" to track.language,
                "label" to track.label,
            )
        }
    }

    fun switchAudioTrack(viewId: Int, groupIndex: Int, trackIndex: Int) {
        getController(viewId)?.switchAudioTrack(groupIndex, trackIndex)
    }

    fun getSubtitleTracks(viewId: Int): List<Map<String, Any?>> {
        val controller = getController(viewId) ?: return emptyList()
        return controller.getSubtitleTracks().map { track ->
            mapOf(
                "groupIndex" to track.groupIndex,
                "trackIndex" to track.trackIndex,
                "language" to track.language,
                "label" to track.label,
            )
        }
    }

    fun selectSubtitleTrack(viewId: Int, groupIndex: Int?, trackIndex: Int?) {
        val controller = getController(viewId) ?: return
        if (groupIndex != null && trackIndex != null) {
            controller.selectSubtitle(groupIndex, trackIndex)
        } else {
            controller.selectSubtitle(-1, null)
        }
    }

    fun setSubtitleDelay(viewId: Int, delayMs: Long) {
        getController(viewId)?.setSubtitleDelay(delayMs)
    }

    fun setAudioDelay(viewId: Int, delayMs: Long) {
        getController(viewId)?.setAudioDelay(delayMs)
    }

    fun setAspectRatio(viewId: Int, resizeMode: Int) {
        views[viewId]?.view?.getPlayerView()?.setResizeMode(resizeMode)
    }

    fun enterPiP(viewId: Int) {
        getController(viewId)?.enterPiP()
    }

    fun togglePiP(viewId: Int, enable: Boolean) {
        getController(viewId)?.togglePiP(enable)
    }

    fun lockRotation(viewId: Int, lock: Boolean) {
        getController(viewId)?.lockRotation(lock)
    }

    fun setGesturesEnabled(viewId: Int, enabled: Boolean) {
        views[viewId]?.view?.getPlayerView()?.setGesturesEnabled(enabled)
    }

    fun getVideoInformation(viewId: Int): Map<String, Any?>? = getController(viewId)?.getVideoInformation()

    fun releaseAll() {
        val entriesCopy = views.values.toList()
        views.clear()
        entriesCopy.forEach { entry ->
            entry.eventJob?.cancel()
            entry.view.controller.release()
        }
    }

    private fun A2OrbitPlayerController.PlayerEvent.toMap(viewId: Int): Map<String, Any?> = when (this) {
        is A2OrbitPlayerController.PlayerEvent.PlaybackState -> mapOf(
            "viewId" to viewId,
            "type" to PlayerConstants.Events.PLAYBACK_STATE,
            "state" to state,
            "playing" to playWhenReady,
        )
        is A2OrbitPlayerController.PlayerEvent.Error -> mapOf(
            "viewId" to viewId,
            "type" to PlayerConstants.Events.ERROR,
            "code" to code,
            "message" to message,
        )
        is A2OrbitPlayerController.PlayerEvent.Position -> mapOf(
            "viewId" to viewId,
            "type" to PlayerConstants.Events.POSITION,
            "position" to positionMs,
            "duration" to durationMs,
        )
        is A2OrbitPlayerController.PlayerEvent.TracksChanged -> mapOf(
            "viewId" to viewId,
            "type" to PlayerConstants.Events.TRACK_CHANGED,
        )
        is A2OrbitPlayerController.PlayerEvent.Gesture -> mapOf(
            "viewId" to viewId,
            "type" to PlayerConstants.Events.GESTURE,
            "gestureType" to eventType,
            "value" to action,
        )
    }
}
