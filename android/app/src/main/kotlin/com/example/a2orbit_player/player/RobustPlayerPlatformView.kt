package com.example.a2orbit_player.player

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Robust PlatformView implementation for Flutter integration
 */
class RobustPlayerPlatformView(
    private val activity: Activity?,
    context: Context,
    private val viewId: Int,
    private val lifecycleOwner: LifecycleOwner?,
    private val manager: RobustPlayerManager,
) : PlatformView {

    private val robustPlayerView: RobustPlayerView = RobustPlayerView(context)
    val controller: RobustExoPlayerController = RobustExoPlayerController(context, activity, lifecycleOwner)
    private val mainScope = CoroutineScope(Dispatchers.Main)

    init {
        try {
            // Attach controller to view
            controller.attachPlayerView(robustPlayerView.playerView)
            
            // Set up enhanced gesture handling
            robustPlayerView.setGestureListener(object : RobustPlayerView.GestureListener {
                override fun onSingleTap() {
                    controller.emitEvent(
                        RobustExoPlayerController.PlayerEvent.Gesture("single_tap")
                    )
                }

                override fun onDoubleTap(isRightHalf: Boolean) {
                    val action = if (isRightHalf) "double_tap_forward" else "double_tap_rewind"
                    controller.emitEvent(
                        RobustExoPlayerController.PlayerEvent.Gesture(action)
                    )
                }

                override fun onLongPress() {
                    controller.emitEvent(
                        RobustExoPlayerController.PlayerEvent.Gesture("long_press")
                    )
                }

                override fun onVerticalScroll(isLeftHalf: Boolean, delta: Float) {
                    val action = if (isLeftHalf) "brightness" else "volume"
                    controller.emitEvent(
                        RobustExoPlayerController.PlayerEvent.Gesture(action, delta.toString())
                    )
                }

                override fun onHorizontalScroll(delta: Float) {
                    controller.emitEvent(
                        RobustExoPlayerController.PlayerEvent.Gesture("seek", delta.toString())
                    )
                }

                override fun onPinchZoom(scale: Float) {
                    controller.emitEvent(
                        RobustExoPlayerController.PlayerEvent.Gesture("pinch_zoom", scale.toString())
                    )
                }

                override fun onGestureEnd() {
                    controller.emitEvent(
                        RobustExoPlayerController.PlayerEvent.Gesture("gesture_end")
                    )
                }
            })

            // Register with manager
            manager.registerView(viewId, controller)
            
            Log.d("RobustPlayerPlatformView", "Platform view initialized successfully for viewId: $viewId")
            
        } catch (e: Exception) {
            Log.e("RobustPlayerPlatformView", "Error initializing platform view", e)
        }
    }

    override fun getView(): View = robustPlayerView

    override fun dispose() {
        Log.d("RobustPlayerPlatformView", "Disposing platform view for viewId: $viewId")
        manager.unregisterView(viewId)
        controller.release()
    }
}
