package com.example.a2orbit_player

import androidx.lifecycle.LifecycleOwner
import com.example.a2orbit_player.player.RobustPlayerFactory
import com.example.a2orbit_player.player.RobustPlayerManager
import com.example.a2orbit_player.player.RobustPlayerConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Robust MainActivity with comprehensive ExoPlayer integration
 */
class RobustMainActivity : FlutterActivity() {

    private var robustManager: RobustPlayerManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val lifecycle = this as? LifecycleOwner
        robustManager = RobustPlayerManager(this, lifecycle)

        // Register platform view factory
        val registry = flutterEngine.platformViewsController.registry
        registry.registerViewFactory(
            RobustPlayerConstants.TEXTURE_ENTRY,
            RobustPlayerFactory(this, lifecycle, robustManager!!),
        )

        // Set up method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RobustPlayerConstants.METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }

        // Set up event channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, RobustPlayerConstants.Events.EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    robustManager?.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    robustManager?.setEventSink(null)
                }
            })
    }

    override fun onDestroy() {
        robustManager?.releaseAll()
        robustManager = null
        super.onDestroy()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val manager = robustManager ?: run {
            result.error("uninitialized", "Robust player manager not ready", null)
            return
        }

        val viewId = (call.argument<Number>("viewId"))?.toInt()
        
        try {
            when (call.method) {
                RobustPlayerConstants.Methods.SET_SOURCE -> {
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
                
                RobustPlayerConstants.Methods.PLAY -> {
                    if (viewId == null) {
                        result.error("invalid_args", "viewId is required", null)
                        return
                    }
                    manager.play(viewId)
                    result.success(null)
                }
                
                RobustPlayerConstants.Methods.PAUSE -> {
                    if (viewId == null) {
                        result.error("invalid_args", "viewId is required", null)
                        return
                    }
                    manager.pause(viewId)
                    result.success(null)
                }
                
                RobustPlayerConstants.Methods.SEEK -> {
                    val position = call.argument<Number>("position")?.toLong()
                    if (viewId == null || position == null) {
                        result.error("invalid_args", "viewId and position required", null)
                        return
                    }
                    manager.seekTo(viewId, position)
                    result.success(null)
                }
                
                RobustPlayerConstants.Methods.SET_SPEED -> {
                    val speed = call.argument<Number>("speed")?.toFloat()
                    if (viewId == null || speed == null) {
                        result.error("invalid_args", "viewId and speed required", null)
                        return
                    }
                    manager.setPlaybackSpeed(viewId, speed)
                    result.success(null)
                }
                
                RobustPlayerConstants.Methods.SET_ASPECT_RATIO -> {
                    val resizeMode = call.argument<Number>("resizeMode")?.toInt()
                    if (viewId == null || resizeMode == null) {
                        result.error("invalid_args", "viewId and resizeMode required", null)
                        return
                    }
                    manager.setAspectRatio(viewId, resizeMode)
                    result.success(null)
                }

                RobustPlayerConstants.Methods.SET_ORIENTATION -> {
                    val orientation = call.argument<String>("orientation")
                    if (viewId == null || orientation.isNullOrBlank()) {
                        result.error("invalid_args", "viewId and orientation required", null)
                        return
                    }
                    manager.setOrientation(viewId, orientation)
                    result.success(null)
                }

                RobustPlayerConstants.Methods.GET_CURRENT_ORIENTATION -> {
                    if (viewId == null) {
                        result.error("invalid_args", "viewId required", null)
                        return
                    }
                    result.success(manager.getCurrentOrientation(viewId))
                }

                RobustPlayerConstants.Methods.SET_AUTO_ROTATE_ENABLED -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (viewId == null || enabled == null) {
                        result.error("invalid_args", "viewId and enabled required", null)
                        return
                    }
                    manager.setAutoRotateEnabled(viewId, enabled)
                    result.success(null)
                }

                RobustPlayerConstants.Methods.IS_AUTO_ROTATE_ENABLED -> {
                    if (viewId == null) {
                        result.error("invalid_args", "viewId required", null)
                        return
                    }
                    result.success(manager.isAutoRotateEnabled(viewId))
                }

                RobustPlayerConstants.Methods.SET_ORIENTATION_LOCKED -> {
                    val locked = call.argument<Boolean>("locked")
                    if (viewId == null || locked == null) {
                        result.error("invalid_args", "viewId and locked required", null)
                        return
                    }
                    manager.setOrientationLocked(viewId, locked)
                    result.success(null)
                }

                RobustPlayerConstants.Methods.IS_ORIENTATION_LOCKED -> {
                    if (viewId == null) {
                        result.error("invalid_args", "viewId required", null)
                        return
                    }
                    result.success(manager.isOrientationLocked(viewId))
                }

                RobustPlayerConstants.Methods.TOGGLE_ORIENTATION -> {
                    if (viewId == null) {
                        result.error("invalid_args", "viewId required", null)
                        return
                    }
                    manager.toggleOrientation(viewId)
                    result.success(null)
                }

                RobustPlayerConstants.Methods.GET_VIDEO_INFO -> {
                    if (viewId == null) {
                        result.error("invalid_args", "viewId required", null)
                        return
                    }
                    val info = manager.getVideoInformation(viewId)
                    result.success(info)
                }
                
                RobustPlayerConstants.Methods.ENTER_PIP -> {
                    if (viewId == null) {
                        result.error("invalid_args", "viewId required", null)
                        return
                    }
                    manager.enterPiP(viewId)
                    result.success(null)
                }
                
                RobustPlayerConstants.Methods.LOCK_ROTATION -> {
                    val lock = call.argument<Boolean>("lock")
                    if (viewId == null || lock == null) {
                        result.error("invalid_args", "viewId and lock required", null)
                        return
                    }
                    manager.lockRotation(viewId, lock)
                    result.success(null)
                }
                
                RobustPlayerConstants.Methods.ENABLE_GESTURES -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    if (viewId == null) {
                        result.error("invalid_args", "viewId required", null)
                        return
                    }
                    manager.setGesturesEnabled(viewId, enabled)
                    result.success(null)
                }
                
                RobustPlayerConstants.Methods.DISPOSE -> {
                    if (viewId != null) {
                        manager.unregisterView(viewId)
                    }
                    result.success(null)
                }
                
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("method_error", "Error executing ${call.method}: ${e.message}", e)
        }
    }
}
