package com.example.a2orbit_player.player

import android.content.Context
import android.graphics.PointF
import android.util.AttributeSet
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.ScaleGestureDetector.SimpleOnScaleGestureListener
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.media3.ui.PlayerView
import kotlin.math.abs

/**
 * Enhanced PlayerView with comprehensive gesture controls
 */
class RobustPlayerView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    val playerView: PlayerView = PlayerView(context).apply {
        useController = false
        isClickable = false
        isLongClickable = false
        isFocusable = false
        isFocusableInTouchMode = false
        descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        setOnTouchListener { _, _ -> false }
    }
    
    private var gestureListener: GestureListener? = null
    private val gestureDetector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
        override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
            gestureListener?.onSingleTap()
            return true
        }
        
        override fun onDoubleTap(e: MotionEvent): Boolean {
            val isRightHalf = e.x > width / 2
            gestureListener?.onDoubleTap(isRightHalf)
            return true
        }
        
        override fun onLongPress(e: MotionEvent) {
            gestureListener?.onLongPress()
        }
    })
    private val scaleDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
        override fun onScale(detector: ScaleGestureDetector): Boolean {
            val scaleFactor = detector.scaleFactor
            currentScale *= scaleFactor
            
            // Clamp scale to bounds
            currentScale = currentScale.coerceIn(minScale, maxScale)
            
            // Apply scale to player view
            playerView.scaleX = currentScale
            playerView.scaleY = currentScale
            
            gestureListener?.onPinchZoom(currentScale)
            return true
        }
        
        override fun onScaleBegin(detector: ScaleGestureDetector): Boolean {
            return true
        }
        
        override fun onScaleEnd(detector: ScaleGestureDetector) {
            gestureListener?.onGestureEnd()
        }
    })
    
    // Gesture state
    private var isGesturing = false
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var lastTouchX = 0f
    private var lastTouchY = 0f
    private var isHorizontalGesture = false
    private var isVerticalGesture = false
    
    // Zoom state
    private var currentScale = 1f
    private var maxScale = 3f
    private var minScale = 1f
    
    // Overlay views for visual feedback
    private val brightnessOverlay: ImageView
    private val volumeOverlay: ImageView
    private val seekOverlay: ImageView
    
    init {
        addView(playerView, LayoutParams(
            LayoutParams.MATCH_PARENT,
            LayoutParams.MATCH_PARENT
        ))
        
        // Create overlay views for gesture feedback
        brightnessOverlay = createOverlayView(android.R.drawable.ic_menu_more)
        volumeOverlay = createOverlayView(android.R.drawable.ic_media_play)
        seekOverlay = createOverlayView(android.R.drawable.ic_media_next)
        
        addView(brightnessOverlay)
        addView(volumeOverlay)
        addView(seekOverlay)
        
        hideOverlayViews()
    }
    
    private fun createOverlayView(iconRes: Int): ImageView {
        return ImageView(context).apply {
            setImageResource(iconRes)
            setBackgroundColor(android.graphics.Color.parseColor("#80000000"))
            setPadding(32, 32, 32, 32)
            visibility = View.GONE
        }
    }
    
    private fun hideOverlayViews() {
        brightnessOverlay.visibility = View.GONE
        volumeOverlay.visibility = View.GONE
        seekOverlay.visibility = View.GONE
    }
    
    fun setGestureListener(listener: GestureListener) {
        this.gestureListener = listener
    }
    
    override fun onTouchEvent(event: MotionEvent): Boolean {
        // Handle scale gestures first
        scaleDetector.onTouchEvent(event)
        
        // Handle other gestures
        gestureDetector.onTouchEvent(event)
        
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                initialTouchX = event.x
                initialTouchY = event.y
                lastTouchX = event.x
                lastTouchY = event.y
                isGesturing = false
                isHorizontalGesture = false
                isVerticalGesture = false
            }
            
            MotionEvent.ACTION_MOVE -> {
                if (!isGesturing && !scaleDetector.isInProgress) {
                    val deltaX = abs(event.x - initialTouchX)
                    val deltaY = abs(event.y - initialTouchY)
                    
                    // Determine gesture direction after minimum movement
                    if (deltaX > 30 || deltaY > 30) {
                        isGesturing = true
                        isHorizontalGesture = deltaX > deltaY
                        isVerticalGesture = deltaY > deltaX
                    }
                }
                
                if (isGesturing && !scaleDetector.isInProgress) {
                    handleGestureMove(event)
                    return true
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                gestureListener?.onGestureEnd()
                return true
            }
        }
        
        return super.onTouchEvent(event)
    }
    
    private fun handleGestureMove(event: MotionEvent) {
        val deltaX = event.x - lastTouchX
        val deltaY = event.y - lastTouchY
        
        if (isHorizontalGesture) {
            // Horizontal swipe - seek
            val seekDelta = deltaX * 2 // Adjust sensitivity
            gestureListener?.onHorizontalScroll(seekDelta)
            
            // Show seek overlay
            seekOverlay.visibility = View.VISIBLE
            seekOverlay.x = event.x - seekOverlay.width / 2
            seekOverlay.y = event.y - seekOverlay.height / 2
            
        } else if (isVerticalGesture) {
            // Vertical swipe - brightness or volume
            val isLeftHalf = event.x < width / 2
            val scrollDelta = -deltaY // Invert for natural scrolling
            
            gestureListener?.onVerticalScroll(isLeftHalf, scrollDelta)
            
            // Show appropriate overlay
            val overlay = if (isLeftHalf) brightnessOverlay else volumeOverlay
            overlay.visibility = View.VISIBLE
            overlay.x = event.x - overlay.width / 2
            overlay.y = event.y - overlay.height / 2
        }
        
        lastTouchX = event.x
        lastTouchY = event.y
    }

    interface GestureListener {
        fun onSingleTap()
        fun onDoubleTap(isRightHalf: Boolean)
        fun onLongPress()
        fun onVerticalScroll(isLeftHalf: Boolean, delta: Float)
        fun onHorizontalScroll(delta: Float)
        fun onPinchZoom(scale: Float)
        fun onGestureEnd()
    }
}
