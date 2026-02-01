package com.example.a2orbit_player.player

import android.content.Context
import android.util.Log
import android.util.AttributeSet
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.view.GestureDetectorCompat
import androidx.media3.ui.PlayerView
import com.example.a2orbit_player.R

class A2OrbitPlayerView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : FrameLayout(context, attrs) {

    val playerView: PlayerView
    val gestureOverlay: TextView
    var gestureListener: GestureListener? = null

    private val gestureDetector: GestureDetectorCompat
    private var gesturesEnabled: Boolean = true

    init {
        inflate(context, R.layout.view_a2orbit_player, this)
        playerView = findViewById(R.id.player_view)
        playerView.controllerAutoShow = false
        playerView.controllerHideOnTouch = false
        playerView.setUseController(false)
        gestureOverlay = findViewById(R.id.gesture_overlay)

        gestureDetector = GestureDetectorCompat(context, object : GestureDetector.SimpleOnGestureListener() {
            private val threshold = 20

            override fun onDown(e: MotionEvent): Boolean = true

            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                gestureListener?.onSingleTap()
                return true
            }

            override fun onDoubleTap(e: MotionEvent): Boolean {
                val isRight = e.x > width / 2
                gestureListener?.onDoubleTap(isRight)
                return true
            }

            override fun onScroll(e1: MotionEvent?, e2: MotionEvent, distanceX: Float, distanceY: Float): Boolean {
                if (!gesturesEnabled || e1 == null) return false
                val deltaX = e2.x - e1.x
                val deltaY = e2.y - e1.y
                if (kotlin.math.abs(deltaY) > kotlin.math.abs(deltaX) && kotlin.math.abs(deltaY) > threshold) {
                    val isLeft = e1.x < width / 2
                    gestureListener?.onVerticalScroll(isLeft, deltaY)
                    return true
                } else if (kotlin.math.abs(deltaX) > threshold) {
                    gestureListener?.onHorizontalScroll(deltaX)
                    return true
                }
                return false
            }
        })

        setOnTouchListener { _, event ->
            if (gesturesEnabled) {
                gestureDetector.onTouchEvent(event)
                if (event.actionMasked == MotionEvent.ACTION_UP || event.actionMasked == MotionEvent.ACTION_CANCEL) {
                    gestureListener?.onGestureEnd()
                }
            }
            gesturesEnabled
        }
    }

    fun bindPlayer(player: androidx.media3.common.Player?) {
        playerView.player = player
        Log.d("A2OrbitPlayerView", "bindPlayer: player=$player, surface=${playerView.videoSurfaceView?.isAttachedToWindow}")
    }

    fun setResizeMode(resizeMode: Int) {
        playerView.resizeMode = resizeMode
    }

    fun setGesturesEnabled(enabled: Boolean) {
        gesturesEnabled = enabled
        if (!enabled) {
            hideGestureOverlay()
        }
    }

    fun showGestureOverlay(text: String) {
        if (text.isBlank()) {
            hideGestureOverlay()
            return
        }
        gestureOverlay.text = text
        gestureOverlay.visibility = View.VISIBLE
        gestureOverlay.removeCallbacks(hideOverlayRunnable)
        gestureOverlay.postDelayed(hideOverlayRunnable, 1000)
    }

    private val hideOverlayRunnable = Runnable {
        gestureOverlay.visibility = View.GONE
    }

    fun hideGestureOverlay() {
        gestureOverlay.removeCallbacks(hideOverlayRunnable)
        gestureOverlay.visibility = View.GONE
    }

    interface GestureListener {
        fun onSingleTap()
        fun onDoubleTap(onRight: Boolean)
        fun onVerticalScroll(isLeftHalf: Boolean, delta: Float)
        fun onHorizontalScroll(delta: Float)
        fun onGestureEnd()
    }
}
