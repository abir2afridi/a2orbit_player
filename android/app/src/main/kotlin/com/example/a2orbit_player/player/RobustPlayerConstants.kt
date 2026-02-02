package com.example.a2orbit_player.player

/**
 * Constants for the Robust Player implementation
 */
object RobustPlayerConstants {
    
    // View and Channel names
    const val TEXTURE_ENTRY = "com.a2orbit.player/robust_texture"
    const val METHOD_CHANNEL = "com.a2orbit.player/robust_channel"
    
    // Event channel
    object Events {
        const val EVENT_CHANNEL = "com.a2orbit.player/robust_events"
        const val PLAYBACK_STATE = "playbackState"
        const val POSITION = "position"
        const val ERROR = "error"
        const val TRACKS_CHANGED = "tracksChanged"
        const val GESTURE = "gesture"
    }
    
    // Method names
    object Methods {
        const val SET_SOURCE = "setDataSource"
        const val PLAY = "play"
        const val PAUSE = "pause"
        const val SEEK = "seekTo"
        const val SET_SPEED = "setPlaybackSpeed"
        const val SET_ASPECT_RATIO = "setAspectRatio"
        const val GET_VIDEO_INFO = "getVideoInformation"
        const val ENTER_PIP = "enterPiP"
        const val LOCK_ROTATION = "lockRotation"
        const val ENABLE_GESTURES = "enableGestures"
        const val DISPOSE = "disposePlayer"
        const val SET_ORIENTATION = "setOrientation"
        const val GET_CURRENT_ORIENTATION = "getCurrentOrientation"
        const val SET_AUTO_ROTATE_ENABLED = "setAutoRotateEnabled"
        const val IS_AUTO_ROTATE_ENABLED = "isAutoRotateEnabled"
        const val SET_ORIENTATION_LOCKED = "setOrientationLocked"
        const val IS_ORIENTATION_LOCKED = "isOrientationLocked"
        const val TOGGLE_ORIENTATION = "toggleOrientation"
    }
    
    // Error codes
    object ErrorCodes {
        const val INVALID_SOURCE = "INVALID_SOURCE"
        const val PERMISSION_DENIED = "PERMISSION_DENIED"
        const val URI_RESOLUTION_FAILED = "URI_RESOLUTION_FAILED"
        const val MIME_TYPE_UNKNOWN = "MIME_TYPE_UNKNOWN"
        const val INITIALIZATION_FAILED = "INITIALIZATION_FAILED"
        const val FALLBACK_FAILED = "FALLBACK_FAILED"
        const val MEDIASTORE_FAILED = "MEDIASTORE_FAILED"
        const val INITIALIZATION_ERROR = "INITIALIZATION_ERROR"
        const val PLAY_ERROR = "PLAY_ERROR"
        const val PAUSE_ERROR = "PAUSE_ERROR"
        const val SEEK_ERROR = "SEEK_ERROR"
        const val SPEED_ERROR = "SPEED_ERROR"
        const val ASPECT_ERROR = "ASPECT_ERROR"
    }
    
    // Aspect ratio modes
    object AspectRatioModes {
        const val FIT = 0
        const val FILL = 1
        const val ZOOM = 2
        const val FIXED_WIDTH = 3
        const val FIXED_HEIGHT = 4
    }
}
