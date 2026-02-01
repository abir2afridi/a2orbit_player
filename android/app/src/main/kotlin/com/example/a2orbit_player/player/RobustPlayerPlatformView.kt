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
            
            // Set up gesture handling
            robustPlayerView.setGestureListener(object : RobustPlayerView.GestureListener {
                override fun onSingleTap() {
                    // Handle single tap if needed
                }

                override fun onDoubleTap(isRightHalf: Boolean) {
                    // Handle double tap if needed
                }

                override fun onVerticalScroll(isLeftHalf: Boolean, delta: Float) {
                    // Handle vertical scroll if needed
                }

                override fun onHorizontalScroll(delta: Float) {
                    // Handle horizontal scroll if needed
                }

                override fun onGestureEnd() {
                    // Handle gesture end if needed
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
