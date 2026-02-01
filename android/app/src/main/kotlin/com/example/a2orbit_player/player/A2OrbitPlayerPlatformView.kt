package com.example.a2orbit_player.player

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.platform.PlatformView

class A2OrbitPlayerPlatformView(
    private val activity: Activity?,
    context: Context,
    private val viewId: Int,
    private val lifecycleOwner: LifecycleOwner?,
    private val manager: A2OrbitPlayerManager,
) : PlatformView {

    private val playerView: A2OrbitPlayerView = A2OrbitPlayerView(context)
    val controller: A2OrbitPlayerController = A2OrbitPlayerController(context, activity, lifecycleOwner)

    init {
        controller.attachView(playerView)
        playerView.bindPlayer(controller.player)
        controller.player.playWhenReady = false
        Log.d("A2OrbitPlayerPlatformView", "Player bound to PlayerView. Surface: ${playerView.playerView.videoSurfaceView?.isAttachedToWindow}")
    }

    override fun getView(): View = playerView

    fun getPlayerView(): A2OrbitPlayerView = playerView

    override fun dispose() {
        manager.unregisterView(viewId, releaseController = false)
        controller.release()
    }
}
