package com.example.a2orbit_player

import androidx.lifecycle.LifecycleOwner
import com.example.a2orbit_player.player.A2OrbitPlayerFactory
import com.example.a2orbit_player.player.A2OrbitPlayerManager
import com.example.a2orbit_player.player.PlayerConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var manager: A2OrbitPlayerManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val lifecycle = this as? LifecycleOwner
        manager = A2OrbitPlayerManager(this, lifecycle)

        val registry = flutterEngine.platformViewsController.registry
        registry.registerViewFactory(
            PlayerConstants.TEXTURE_ENTRY,
            A2OrbitPlayerFactory(this, lifecycle, manager!!),
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PlayerConstants.METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PlayerConstants.Events.EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    manager?.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    manager?.setEventSink(null)
                }
            })
    }

    override fun onDestroy() {
        manager?.releaseAll()
        manager = null
        super.onDestroy()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val manager = manager ?: run {
            result.error("uninitialized", "Player manager not ready", null)
            return
        }
        val viewId = (call.argument<Number>("viewId"))?.toInt()
        when (call.method) {
            PlayerConstants.Methods.SET_SOURCE -> {
                if (viewId == null) {
                    result.error("invalid_args", "viewId is required", null)
                    return
                }
                val path = call.argument<String>("path")
                val subtitles = call.argument<List<String>>("subtitles") ?: emptyList()
                if (path.isNullOrBlank()) {
                    result.error("invalid_args", "path is required", null)
                } else {
                    manager.setDataSource(viewId, path, subtitles)
                    result.success(null)
                }
            }
            PlayerConstants.Methods.PLAY -> {
                if (viewId == null) {
                    result.error("invalid_args", "viewId is required", null)
                    return
                }
                manager.play(viewId)
                result.success(null)
            }
            PlayerConstants.Methods.PAUSE -> {
                if (viewId == null) {
                    result.error("invalid_args", "viewId is required", null)
                    return
                }
                manager.pause(viewId)
                result.success(null)
            }
            PlayerConstants.Methods.SEEK -> {
                val position = call.argument<Number>("position")?.toLong()
                if (viewId == null || position == null) {
                    result.error("invalid_args", "viewId and position required", null)
                    return
                }
                manager.seekTo(viewId, position)
                result.success(null)
            }
            PlayerConstants.Methods.SET_SPEED -> {
                val speed = call.argument<Number>("speed")?.toFloat()
                if (viewId == null || speed == null) {
                    result.error("invalid_args", "viewId and speed required", null)
                    return
                }
                manager.setPlaybackSpeed(viewId, speed)
                result.success(null)
            }
            PlayerConstants.Methods.SET_DECODER -> {
                val decoder = call.argument<String>("decoder")
                if (viewId == null || decoder.isNullOrBlank()) {
                    result.error("invalid_args", "viewId and decoder required", null)
                    return
                }
                manager.setDecoder(viewId, decoder)
                result.success(null)
            }
            PlayerConstants.Methods.GET_AUDIO_TRACKS -> {
                if (viewId == null) {
                    result.error("invalid_args", "viewId required", null)
                    return
                }
                result.success(manager.getAudioTracks(viewId))
            }
            PlayerConstants.Methods.SWITCH_AUDIO_TRACK -> {
                val groupIndex = call.argument<Number>("groupIndex")?.toInt()
                val trackIndex = call.argument<Number>("trackIndex")?.toInt()
                if (viewId == null || groupIndex == null || trackIndex == null) {
                    result.error("invalid_args", "viewId, groupIndex, trackIndex required", null)
                    return
                }
                manager.switchAudioTrack(viewId, groupIndex, trackIndex)
                result.success(null)
            }
            PlayerConstants.Methods.GET_SUBTITLE_TRACKS -> {
                if (viewId == null) {
                    result.error("invalid_args", "viewId required", null)
                    return
                }
                result.success(manager.getSubtitleTracks(viewId))
            }
            PlayerConstants.Methods.SELECT_SUBTITLE_TRACK -> {
                if (viewId == null) {
                    result.error("invalid_args", "viewId required", null)
                    return
                }
                val groupIndex = call.argument<Number>("groupIndex")?.toInt()
                val trackIndex = call.argument<Number>("trackIndex")?.toInt()
                manager.selectSubtitleTrack(viewId, groupIndex, trackIndex)
                result.success(null)
            }
            PlayerConstants.Methods.SET_SUBTITLE_DELAY -> {
                val delay = call.argument<Number>("delayMs")?.toLong()
                if (viewId == null || delay == null) {
                    result.error("invalid_args", "viewId and delayMs required", null)
                    return
                }
                manager.setSubtitleDelay(viewId, delay)
                result.success(null)
            }
            PlayerConstants.Methods.SET_AUDIO_DELAY -> {
                val delay = call.argument<Number>("delayMs")?.toLong()
                if (viewId == null || delay == null) {
                    result.error("invalid_args", "viewId and delayMs required", null)
                    return
                }
                manager.setAudioDelay(viewId, delay)
                result.success(null)
            }
            PlayerConstants.Methods.SET_ASPECT_RATIO -> {
                val resizeMode = call.argument<Number>("resizeMode")?.toInt()
                if (viewId == null || resizeMode == null) {
                    result.error("invalid_args", "viewId and resizeMode required", null)
                    return
                }
                manager.setAspectRatio(viewId, resizeMode)
                result.success(null)
            }
            PlayerConstants.Methods.ENTER_PIP -> {
                if (viewId == null) {
                    result.error("invalid_args", "viewId required", null)
                    return
                }
                manager.enterPiP(viewId)
                result.success(null)
            }
            PlayerConstants.Methods.TOGGLE_PIP -> {
                val enable = call.argument<Boolean>("enable")
                if (viewId == null || enable == null) {
                    result.error("invalid_args", "viewId and enable required", null)
                    return
                }
                manager.togglePiP(viewId, enable)
                result.success(null)
            }
            PlayerConstants.Methods.LOCK_ROTATION -> {
                val lock = call.argument<Boolean>("lock")
                if (viewId == null || lock == null) {
                    result.error("invalid_args", "viewId and lock required", null)
                    return
                }
                manager.lockRotation(viewId, lock)
                result.success(null)
            }
            PlayerConstants.Methods.DISPOSE -> {
                if (viewId != null) {
                    manager.unregisterView(viewId)
                }
                result.success(null)
            }
            PlayerConstants.Methods.ENABLE_GESTURES -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                if (viewId == null) {
                    result.error("invalid_args", "viewId required", null)
                    return
                }
                manager.setGesturesEnabled(viewId, enabled)
                result.success(null)
            }
            PlayerConstants.Methods.GET_VIDEO_INFO -> {
                if (viewId == null) {
                    result.error("invalid_args", "viewId required", null)
                    return
                }
                result.success(manager.getVideoInformation(viewId))
            }
            else -> result.notImplemented()
        }
    }
}
