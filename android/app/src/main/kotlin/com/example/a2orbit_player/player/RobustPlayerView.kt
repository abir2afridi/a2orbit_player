package com.example.a2orbit_player.player

import android.content.Context
import android.graphics.Color
import android.util.AttributeSet
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.view.GestureDetectorCompat
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView

/**
 * Robust PlayerView with proper gesture handling and surface management
 */
class RobustPlayerView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    val playerView: PlayerView
    private val gestureOverlay: TextView
    private val gestureDetector: GestureDetectorCompat
    private var gestureListener: GestureListener? = null

    init {
        // Create ExoPlayer PlayerView
        playerView = PlayerView(context).apply {
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT
            )
            useController = false
            resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
            setBackgroundColor(Color.BLACK)
        }

        // Create gesture overlay
        gestureOverlay = TextView(context).apply {
            layoutParams = LayoutParams(
                LayoutParams.WRAP_CONTENT,
                LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = android.view.Gravity.CENTER
            }
            setTextColor(Color.WHITE)
            textSize = 16f
            setShadowLayer(2f, 1f, 1f, Color.BLACK)
            visibility = View.GONE
        }

        addView(playerView)
        addView(gestureOverlay)

        // Initialize gesture detector
        gestureDetector = GestureDetectorCompat(context, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                gestureListener?.onSingleTap()
                return true
            }

            override fun onDoubleTap(e: MotionEvent): Boolean {
                val isRightHalf = e.x > width / 2
                gestureListener?.onDoubleTap(isRightHalf)
                return true
            }

            override fun onDown(e: MotionEvent): Boolean = true
        })
    }

    fun setGestureListener(listener: GestureListener) {
        gestureListener = listener
    }

    fun showGestureOverlay(text: String) {
        if (text.isBlank()) {
            gestureOverlay.visibility = View.GONE
        } else {
            gestureOverlay.text = text
            gestureOverlay.visibility = View.VISIBLE
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        gestureDetector.onTouchEvent(event)
        
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                // Handle initial touch
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                // Handle drag gestures
                val deltaX = if (event.historySize > 0) event.x - event.getHistoricalX(0) else 0f
                val deltaY = if (event.historySize > 0) event.y - event.getHistoricalY(0) else 0f
                
                if (kotlin.math.abs(deltaX) > kotlin.math.abs(deltaY)) {
                    // Horizontal drag - seek
                    gestureListener?.onHorizontalScroll(deltaX)
                } else {
                    // Vertical drag - brightness/volume
                    val isLeftHalf = event.x < width / 2
                    gestureListener?.onVerticalScroll(isLeftHalf, deltaY)
                }
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                gestureListener?.onGestureEnd()
                return true
            }
        }
        
        return super.onTouchEvent(event)
    }

    interface GestureListener {
        fun onSingleTap()
        fun onDoubleTap(isRightHalf: Boolean)
        fun onVerticalScroll(isLeftHalf: Boolean, delta: Float)
        fun onHorizontalScroll(delta: Float)
        fun onGestureEnd()
    }
}
